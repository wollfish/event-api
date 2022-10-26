# EventAPI

It's a ruby gem to generate events (for example: generate events for executing particular tasks like sending emails).

## Installation

Add to the application's Gemfile:

```
gem 'event_api', git: 'https://github.com/wollfish/event-api'
```

## Setup

Add EventAPI module in Project initializer.

```ruby
module EventAPI
  class << self
    def notify(event_name, event_payload)
      @event_api ||= EventApi.configure(
        application_name: Rails.application.class.name.split('::').first.underscore,
        jwt_algorithm: ENV.fetch('EVENT_API_JWT_ALGORITHM', 'RS256'),
        jwt_private_key: P2P::App.config.p2p_jwt_private_key,
        rabbitmq_credentials: {
          host: ENV.fetch('EVENT_API_RABBITMQ_HOST', 'localhost'),
          port: ENV.fetch('EVENT_API_RABBITMQ_PORT', '5672'),
          username: ENV.fetch('EVENT_API_RABBITMQ_USERNAME', 'guest'),
          password: ENV.fetch('EVENT_API_RABBITMQ_PASSWORD', 'guest')
        }
      )

      @event_api.notify(event_name, event_payload)
    end
  end
end
```

## Usage

```ruby
EventAPI.notify('admin_notify.document.verify', record: { data: 'Testing Data' })
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wollfish/event-api.
