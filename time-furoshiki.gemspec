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
  spec.homepage = "https://github.com/yourusername/time-furoshiki"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/time-furoshiki"
  spec.metadata["changelog_uri"] = "https://github.com/yourusername/time-furoshiki/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "rails", ">= 6.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.21"
  spec.add_development_dependency "sqlite3", "~> 2.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
