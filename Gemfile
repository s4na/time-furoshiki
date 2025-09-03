# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in time-furoshiki.gemspec
gemspec

gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"

# Ruby version-specific gem dependencies
if RUBY_VERSION >= "3.0"
  gem "sqlite3", "~> 1.7"
else
  # Ruby 2.7 specific versions
  gem "sqlite3", "~> 1.4", "< 1.7"
end
