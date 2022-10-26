# frozen_string_literal: true

require_relative "event_api/version"

require "bunny"
require "jwt-multisig"
require "memoist"
require "securerandom"

module EventApi
  class << self
    def configure(application_name:, jwt_algorithm:, jwt_private_key:, rabbitmq_credentials:)
      @middlewares = [
        Middlewares::IncludeEventMetadata.new,
        Middlewares::GenerateJWT.new(application_name, jwt_algorithm, jwt_private_key),
        Middlewares::PrintToScreen.new,
        Middlewares::PublishToRabbitMQ.new(application_name, rabbitmq_credentials)
      ]

      self
    end

    def notify(event_name, event_payload)
      arguments = [event_name, event_payload]

      middlewares.each do |middleware|
        returned_value = middleware.call(*arguments)

        case returned_value
        when Array then arguments = returned_value
        else return returned_value
        end
      end
    end

    def middlewares
      @middlewares ||= []
    end
  end

  # To continue processing by further middlewares return array with event name and payload.
  # To stop processing event return any value which isn't an array.
  module Middlewares
    class IncludeEventMetadata
      def call(event_name, event_payload)
        event_payload[:name] = event_name

        [event_name, event_payload]
      end
    end

    class GenerateJWT
      def initialize(application_name, jwt_algorithm, jwt_private_key)
        @application_name = application_name
        @jwt_algorithm = jwt_algorithm
        @jwt_private_key = OpenSSL::PKey.read(Base64.urlsafe_decode64(jwt_private_key))
      end

      def call(event_name, event_payload)
        jwt_payload = {
          iss: @application_name,
          jti: SecureRandom.uuid,
          iat: Time.now.to_i,
          exp: Time.now.to_i + 60,
          event: event_payload
        }

        jwt = JWT::Multisig.generate_jwt \
          jwt_payload, { @application_name.to_sym => @jwt_private_key }, { @application_name.to_sym => @jwt_algorithm }

        [event_name, jwt]
      end
    end

    class PrintToScreen
      def call(event_name, event_payload)
        p ["",
           "Produced new event at #{Time.now}: ",
           "name    = #{event_name}",
           "payload = #{event_payload.to_json}",
           ""].join("\n")

        [event_name, event_payload]
      end
    end

    class PublishToRabbitMQ
      extend Memoist

      def initialize(application_name, rabbitmq_credentials)
        @application_name = application_name
        @rabbitmq_credentials = rabbitmq_credentials
      end

      def call(event_name, event_payload)
        p "\nPublishing #{routing_key(event_name)} (routing key) to #{exchange_name(event_name)} (exchange name)"

        exchange = bunny_exchange(exchange_name(event_name))
        exchange.publish(event_payload.to_json, routing_key: routing_key(event_name))

        [event_name, event_payload]
      end

      private

      def bunny_session
        Bunny::Session.new(@rabbitmq_credentials).tap do |session|
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
      # example name : event_api.event.market
      def bunny_exchange(name)
        bunny_channel.direct(name)
      end

      memoize :bunny_exchange

      # example event name are defined in the beginning of this class.
      # eg event name : push_notify.withdraw.succeed
      #
      # It will return exchange names like
      #  - event_api.events.push_notify
      #
      def exchange_name(event_name)
        "#{@application_name}.events.#{event_name.split(".").first}"
      end

      # example event name are defined in the beginning of this class.
      # eg event name : push_notify.withdraw.succeed
      #
      # it will return routing key as
      #  - withdraw.succeed
      #
      def routing_key(event_name)
        event_name.split(".").drop(1).join(".")
      end
    end
  end
end
