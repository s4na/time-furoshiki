# time-furoshiki

[![CI](https://github.com/yourusername/time-furoshiki/actions/workflows/main.yml/badge.svg)](https://github.com/yourusername/time-furoshiki/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/time-furoshiki.svg)](https://badge.fury.io/rb/time-furoshiki)
[![Code Climate](https://codeclimate.com/github/yourusername/time-furoshiki/badges/gpa.svg)](https://codeclimate.com/github/yourusername/time-furoshiki)

A Rails gem that stores migration file contents in a database table when migrations are executed, and uses these stored migrations during rollback operations. This ensures that rollbacks always work correctly, even if the original migration files have been modified or deleted.

## Features

- **Automatic Migration Storage**: Captures and stores migration file contents when `rails db:migrate` is executed
- **Reliable Rollbacks**: Uses stored migration contents for rollbacks, ensuring consistency
- **Database Agnostic**: Works with PostgreSQL, MySQL, and SQLite
- **Rails Integration**: Seamlessly integrates with Rails migration framework
- **Configurable**: Flexible configuration options for different use cases
- **Multi-version Support**: Compatible with Ruby 2.7+ and Rails 6.0+

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'time-furoshiki'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install time-furoshiki
```

After installation, run the generator to create the necessary database table:

```bash
$ rails generate time_furoshiki:install
$ rails db:migrate
```

## Usage

Once installed, time-furoshiki works automatically in the background:

### Running Migrations

When you run migrations as usual:

```bash
$ rails db:migrate
```

time-furoshiki will:
1. Capture the migration file content before execution
2. Execute the migration
3. Store the migration content in the `time_furoshiki_migrations` table if successful

### Rolling Back Migrations

When you rollback migrations:

```bash
$ rails db:rollback
```

time-furoshiki will:
1. Check for stored migration content in the database
2. Use the stored content for rollback (ensuring consistency)
3. Fall back to the original file if no stored version exists

### Rake Tasks

time-furoshiki provides several rake tasks for management:

```bash
# Show status of stored migrations
$ rake time_furoshiki:status

# Clean up orphaned migration records
$ rake time_furoshiki:clean

# Reinstall the migrations table
$ rake time_furoshiki:install
```

## Configuration

Create an initializer `config/initializers/time_furoshiki.rb`:

```ruby
TimeFuroshiki.configure do |config|
  # Keep migration records after rollback (default: true)
  # Set to false to automatically remove stored migrations after successful rollback
  config.keep_rolled_back_migrations = true
  
  # Automatically clean orphaned records (default: false)
  # Set to true to periodically remove migration records with no corresponding migration file
  config.auto_clean_orphaned = false
  
  # Enable verbose logging (default: false)
  # Set to true for detailed logging of storage and rollback operations
  config.verbose = false
end
```

## Database Schema

time-furoshiki creates a `time_furoshiki_migrations` table with the following structure:

| Column | Type | Description |
|--------|------|-------------|
| `version` | string | Migration version/timestamp (primary key) |
| `filename` | string | Original migration filename |
| `content` | text | Full migration file content |
| `executed_at` | datetime | When the migration was executed |
| `created_at` | datetime | Record creation timestamp |
| `updated_at` | datetime | Record update timestamp |

## How It Works

### Migration Storage Process

```ruby
# When a migration runs:
1. Before execution → Capture migration file content
2. Execute migration → Run the actual migration
3. After success → Store content in database
4. On failure → Transaction rollback (no storage)
```

### Rollback Process

```ruby
# When rolling back:
1. Check database → Look for stored migration content
2. If found → Use stored content for rollback
3. If not found → Use original file with warning
4. After success → Optionally remove stored record
```

## Compatibility

| Ruby Version | Rails 6.0 | Rails 6.1 | Rails 7.0 | Rails 7.1 | Rails 7.2 |
|--------------|-----------|-----------|-----------|-----------|-----------|
| 2.7          | ✅ | ✅ | ✅ | ✅ | ❌ |
| 3.0          | ✅ | ✅ | ✅ | ✅ | ❌ |
| 3.1          | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3.2          | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3.3          | ✅ | ✅ | ✅ | ✅ | ✅ |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To test against different Rails versions:

```bash
# Install appraisal gemsets
$ bundle exec appraisal install

# Run tests for specific Rails version
$ bundle exec appraisal rails-7.0 rspec

# Run tests for all versions
$ bundle exec appraisal rspec
```

To install this gem onto your local machine, run:

```bash
$ bundle exec rake install
```

## Testing

Run the test suite:

```bash
# Run all tests
$ bundle exec rspec

# Run with coverage report
$ COVERAGE=true bundle exec rspec

# Run specific test file
$ bundle exec rspec spec/time_furoshiki/migration_storage_spec.rb

# Run tests with different database adapters
$ DATABASE_ADAPTER=postgresql bundle exec rspec
$ DATABASE_ADAPTER=mysql bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/time-furoshiki. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/yourusername/time-furoshiki/blob/main/CODE_OF_CONDUCT.md).

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the time-furoshiki project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/yourusername/time-furoshiki/blob/main/CODE_OF_CONDUCT.md).

## Acknowledgments

The name "furoshiki" (風呂敷) refers to traditional Japanese wrapping cloth, symbolizing how this gem "wraps" and preserves your migrations for safe keeping.