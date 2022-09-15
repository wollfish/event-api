# frozen_string_literal: true

require_relative "event_api/version"

require "active_support/concern"
require "active_support/lazy_load_hooks"

require "rubygems"
require "memoist"
require "base64"
require "jwt-multisig"
require "bunny"

module EventApi
  class Error < StandardError; end

  class << self
    def notify(event_name, event_payload)
      arguments = [event_name, event_payload]
      middlewares.each do |middleware|
        returned_value = middleware.call(*arguments)
        case returned_value
        when Array then arguments = returned_value
        else return returned_value
        end
      rescue StandardError => e
        p "#{e}"
        raise
      end
    end

    def middlewares=(list)
      @middlewares = list
    end

    def middlewares
      @middlewares ||= []
    end
  end

  module ActiveRecord
    class Mediator
      attr_reader :record

      def initialize(record)
        @record = record
      end

      def notify(partial_event_name, event_payload)
        tokens = ['model']
        tokens << record.class.event_api_settings.fetch(:prefix) { record.class.name.underscore.gsub(/\//, '_') }
        tokens << partial_event_name.to_s
        suffix = record.class.event_api_settings[:suffix]

        if suffix.present?
          suffix = suffix.map { |attr| record.public_send(attr.to_s) }.join('.').to_sym
          valid_suffix_value = record.class.event_api_settings.fetch(:valid_suffix_value, {})
          return unless valid_suffix_value[suffix].present?

          tokens << valid_suffix_value[suffix]
        end

        full_event_name = tokens.join('.')

        # full event name is based on the record class name and event type.
        # eg
        #   - model.beneficiary.created.pending event
        #   - model.beneficiary.updated.active event
        #   - model.beneficiary.updated.suspicious event
        #   - model.deposit.created event
        #   - model.deposit.updated event
        #   - model.withdraw.created event
        #   - model.withdraw.succeed event
        #   - model.withdraw.failed event
        #   - model.account.created event
        #   - model.account.updated event
        ::EventAPI.notify(full_event_name, event_payload)
      end

      # Method responsible to publishing message when record is created in DB.
      def notify_record_created
        notify(:created, record: record.as_json_for_event_api.compact)
      end

      # Method responsible to publishing message when record is updated in DB.
      def notify_record_updated
        return if record.previous_changes.blank?

        current_record  = record
        previous_record = record.dup
        record.previous_changes.each { |attribute, values| previous_record.send("#{attribute}=", values.first) }

        # Guarantee timestamps.
        previous_record.created_at ||= current_record.created_at
        previous_record.updated_at ||= current_record.created_at

        before = previous_record.as_json_for_event_api.compact
        after  = current_record.as_json_for_event_api.compact

        notify :updated, \
          record:  after,
               changes: before.delete_if { |attribute, value| after[attribute] == value }
      end
    end

    # This module is responsible for defining DB call back methods (after_commit)
    #
    module Extension
      extend ActiveSupport::Concern

      included do
        # We add «after_commit» callbacks immediately after inclusion.
        # notify_record_created
        %i[create update].each do |event|
          after_commit on: event, prepend: true do
            if self.class.event_api_settings[:on]&.include?(event)
              event_api.public_send("notify_record_#{event}d")
            end
          end
        end
      end

      module ClassMethods
        def acts_as_eventable(settings = {})
          settings[:on] = %i[create update] unless settings.key?(:on)
          @event_api_settings = event_api_settings.merge(settings)
        end

        def event_api_settings
          @event_api_settings || superclass.instance_variable_get(:@event_api_settings) || {}
        end
      end

      def event_api
        @event_api ||= Mediator.new(self)
      end

      def as_json_for_event_api
        as_json
      end
    end
  end

  # To continue processing by further middlewares return array with event name and payload.
  # To stop processing event return any value which isn't an array.
  module Middlewares

    class << self
      def application_name
        ENV.fetch('APPLICATION_NAME', 'event_api')
      end

      def application_version
        "#{application_name.camelize}::VERSION".constantize
      end
    end

    class IncludeEventMetadata
      def call(event_name, event_payload)
        event_payload[:name] = event_name
        [event_name, event_payload]
      end
    end

    class GenerateJWT
      def call(event_name, event_payload)
        jwt_payload = {
          iss:   Middlewares.application_name,
          jti:   SecureRandom.uuid,
          iat:   Time.now.to_i,
          exp:   Time.now.to_i + 60,
          event: event_payload
        }

        private_key = OpenSSL::PKey.read(Base64.urlsafe_decode64(ENV.fetch('JWT_PRIVATE_KEY')))
        algorithm   = ENV.fetch('EVENT_API_JWT_ALGORITHM', 'RS256')
        jwt         = JWT::Multisig.generate_jwt jwt_payload, \
                                                   { Middlewares.application_name.to_sym => private_key },
                                                 { Middlewares.application_name.to_sym => algorithm }

        [event_name, jwt]
      end
    end

    class PrintToScreen
      def call(event_name, event_payload)
        p ['',
           'Produced new event at ' + Time.current.to_s + ': ',
           'name    = ' + event_name,
           'payload = ' + event_payload.to_json,
           ''].join("\n")

        [event_name, event_payload]
      end
    end

    class PublishToRabbitMQ
      extend Memoist

      def call(event_name, event_payload)
        p "\nPublishing #{routing_key(event_name)} (routing key) to #{exchange_name(event_name)} (exchange name).\n"
        exchange = bunny_exchange(exchange_name(event_name))
        exchange.publish(event_payload.to_json, routing_key: routing_key(event_name))
        [event_name, event_payload]
      end

      private

      def bunny_session
        Bunny::Session.new(rabbitmq_credentials).tap do |session|
          session.start
          Kernel.at_exit { session.stop }
        end
      end
      memoize :bunny_session

      def bunny_channel
        bunny_session.channel
      end
      memoize :bunny_channel

      # return direct exchange
      # example name : peatio.event.market
      def bunny_exchange(name)
        bunny_channel.direct(name)
      end
      memoize :bunny_exchange

      def rabbitmq_credentials
        return ENV['EVENT_API_RABBITMQ_URL'] if ENV['EVENT_API_RABBITMQ_URL'].present?

        { host:     ENV.fetch('EVENT_API_RABBITMQ_HOST', 'localhost'),
          port:     ENV.fetch('EVENT_API_RABBITMQ_PORT', '5672'),
          username: ENV.fetch('EVENT_API_RABBITMQ_USERNAME', 'guest'),
          password: ENV.fetch('EVENT_API_RABBITMQ_PASSWORD', 'guest') }
      end

      # example event name are defined in the beginning of this class.
      # eg event name : market.#{market-id}.order_created
      #
      # It will return exchange names like :-
      #
      # - peatio.events.market
      # - peatio.events.model
      #
      def exchange_name(event_name)
        "#{Middlewares.application_name}.events.#{event_name.split('.').first}"
      end

      # example event name are defined in the beginning of this class.
      # eg event name : market.#{market-id}.order_created
      #
      # it will return routing key as
      #  - BTCUSD.order_created
      #  - deposit.created
      #
      def routing_key(event_name)
        event_name.split('.').drop(1).join('.')
      end
    end
  end

  middlewares << Middlewares::IncludeEventMetadata.new
  middlewares << Middlewares::GenerateJWT.new
  middlewares << Middlewares::PrintToScreen.new
  middlewares << Middlewares::PublishToRabbitMQ.new
end
