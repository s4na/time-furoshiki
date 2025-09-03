# frozen_string_literal: true

require_relative "lib/time_furoshiki/version"

Gem::Specification.new do |spec|
  spec.name = "time-furoshiki"
  spec.version = TimeFuroshiki::VERSION
  spec.authors = ["s4na"]
  spec.email = ["appletea.umauma@gmail.com"]

  spec.summary = "Store Rails migration contents in database for reliable rollbacks"
  spec.description = "time-furoshiki saves Rails migration file contents to a database table " \
                     "when migrations run, and uses these stored migrations during rollback operations."
  spec.homepage = "https://github.com/s4na/time-furoshiki"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/s4na/time-furoshiki"
  spec.metadata["changelog_uri"] = "https://github.com/s4na/time-furoshiki/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["{lib,sig}/**/*", "*.md", "*.txt", "*.gemspec"].reject do |f|
    File.directory?(f)
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.0", "< 8.0"
  spec.add_dependency "activesupport", ">= 6.0", "< 8.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.21"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
