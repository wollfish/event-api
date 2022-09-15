# frozen_string_literal: true

require_relative "lib/event_api/version"

Gem::Specification.new do |spec|
  spec.name = "event_api"
  spec.version = EventApi::VERSION
  spec.authors = ["Pooja Singh"]
  spec.email = ["poojajps13@gmail.com"]

  spec.summary = "Generate events."
  spec.description = "Generate events for executing particular tasks like sending emails."
  spec.homepage = "https://github.com/wollfish/event_api"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rake", "~> 13.0"
  spec.add_dependency "rspec", "~> 3.0"
  spec.add_dependency "rubocop", "~> 1.21"
  spec.add_dependency "activesupport", "~> 7.0.4"
  spec.add_dependency "memoist", "~> 0.16.0"
  spec.add_dependency "jwt-multisig", "~> 1.0.0"
  spec.add_dependency "bunny", "~> 2.14.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
