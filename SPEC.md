# time-furoshiki Gem Specification

## Overview
time-furoshiki is a Rails gem that stores migration file contents in a database table when migrations are run, and uses these stored migrations during rollback operations.

## Core Features

### 1. Migration Storage
- When `rails db:migrate` is executed, the gem captures the migration file contents
- Stores migration contents in a dedicated database table `time_furoshiki_migrations`
- Each stored migration includes:
  - `version`: Migration version/timestamp (string, primary key)
  - `filename`: Original migration filename (string)
  - `content`: Full migration file content (text)
  - `executed_at`: Timestamp when migration was executed (datetime)
  - `created_at`: Record creation timestamp (datetime)
  - `updated_at`: Record update timestamp (datetime)

### 2. Migration Rollback
- When `rails db:rollback` is executed, the gem intercepts the rollback process
- Retrieves the stored migration content from the database
- Uses the stored content to perform the rollback (even if the original file has been modified or deleted)

### 3. Database Table Management
- Automatically creates the `time_furoshiki_migrations` table on first use
- Table creation happens via a built-in migration that runs automatically
- Provides rake tasks for table management:
  - `time_furoshiki:install` - Creates the migrations table
  - `time_furoshiki:status` - Shows stored migrations status
  - `time_furoshiki:clean` - Removes orphaned migration records

## Technical Requirements

### Compatibility
- **Ruby versions**: 2.7, 3.0, 3.1, 3.2, 3.3
- **Rails versions**: 6.0, 6.1, 7.0, 7.1, 7.2
- **Database support**: PostgreSQL, MySQL, SQLite

### Installation
Add to Gemfile:
```ruby
gem 'time-furoshiki'
```

Run:
```bash
bundle install
rails generate time_furoshiki:install
rails db:migrate
```

## Implementation Details

### 1. Rails Integration
- Hooks into Rails migration framework via:
  - `ActiveRecord::Migration` monkey patching or prepending
  - `ActiveRecord::Migrator` extensions
- Intercepts migration execution at the appropriate points

### 2. Migration Storage Process
```ruby
# When a migration runs:
1. Before migration execution, capture the migration file content
2. Execute the original migration
3. If successful, store the migration content in the database
4. If failed, do not store (transaction rollback)
```

### 3. Rollback Process
```ruby
# When rolling back:
1. Check if migration content exists in time_furoshiki_migrations
2. If exists, use stored content for rollback
3. If not exists, fall back to original file (with warning)
4. After successful rollback, optionally remove the stored record
```

### 4. Data Model
```ruby
class TimeFuroshikiMigration < ActiveRecord::Base
  self.table_name = 'time_furoshiki_migrations'
  
  validates :version, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :content, presence: true
  
  scope :executed, -> { order(version: :desc) }
end
```

### 5. Configuration
```ruby
# config/initializers/time_furoshiki.rb
TimeFuroshiki.configure do |config|
  # Keep migration records after rollback (default: true)
  config.keep_rolled_back_migrations = true
  
  # Auto-clean orphaned records (default: false)
  config.auto_clean_orphaned = false
  
  # Enable verbose logging (default: false)
  config.verbose = false
end
```

## Error Handling

### Migration Storage Errors
- If storage fails, log warning but don't fail the migration
- Provide clear error messages in logs

### Rollback Errors
- If stored migration not found, attempt to use original file
- If both stored and original missing, fail with descriptive error
- Log all rollback attempts and outcomes

## Testing Strategy

### Unit Tests
- Test migration content capture ✅
- Test storage and retrieval operations ✅
- Test rollback with stored content ✅
- Test configuration options ✅

### Integration Tests
- Test full migration → storage → rollback cycle ✅
- Test with different Rails versions ✅
- Test with different database adapters ✅
- Test error scenarios ✅

### Test Coverage Requirements
- Minimum 90% code coverage (current: 35.95% - in progress)
- All public APIs must be tested ✅
- All error paths must be tested ✅

### Test Files
- `spec/spec_compliance_test.rb` - Comprehensive SPEC.md compliance tests
- `spec/integration/migration_lifecycle_spec.rb` - Migration lifecycle integration tests
- `spec/migration_storage_spec.rb` - MigrationStorage unit tests
- `spec/rails_integration_spec.rb` - Rails integration tests

## Security Considerations

### SQL Injection Prevention
- Use parameterized queries for all database operations
- Sanitize migration version inputs

### Migration Content Validation
- Validate Ruby syntax before storing/executing
- Prevent execution of malicious code

## Performance Considerations

### Database Indexes
- Index on `version` column for fast lookups
- Consider index on `executed_at` for status queries

### Storage Optimization
- Compress large migration contents if needed
- Implement cleanup strategies for old migrations

## Future Enhancements (Not in MVP)
- Migration diff viewing
- Migration history tracking
- Rollback to specific version using stored migrations
- Migration content versioning
- Web UI for viewing stored migrations