# frozen_string_literal: true

require_relative "lib/event_api/version"

Gem::Specification.new do |spec|
  spec.name = "event_api"
  spec.version = EventApi::VERSION
  spec.authors = ["Pooja Singh", "Pranjal Kushwaha"]
  spec.email = %w[poojajps13@gmail.com pranjalkushwaha1@gmail.com]

  spec.summary = "Generate events."
  spec.description = "Generate events for executing particular tasks like sending emails."
  spec.homepage = "https://github.com/wollfish/event-api"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

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

  # Development dependencies for gem
  spec.add_runtime_dependency "bunny"
  spec.add_runtime_dependency "jwt-multisig"
  spec.add_runtime_dependency "memoist"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
