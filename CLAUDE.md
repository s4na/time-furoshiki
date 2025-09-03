# CLAUDE.md - Claude Code Instructions

This document contains important instructions for Claude Code when working with the time-furoshiki gem.

## Important: README Synchronization

**When updating README.md, you MUST also update README.jp.md to keep both versions synchronized.**

README.jp.md is the Japanese version of the documentation and should maintain the same structure and content as README.md, but translated into Japanese.

### Steps for README Updates:

1. Make changes to README.md
2. Apply the same structural changes to README.jp.md
3. Ensure Japanese translation is accurate and natural
4. Commit both files together

## Project Overview

time-furoshiki is a Rails gem that:
- Stores migration file contents in a database table when migrations are executed
- Uses stored migrations for rollback operations
- Ensures rollbacks work even if original migration files are modified or deleted

## Development Guidelines

### Testing
Before committing any changes, always run:
```bash
bundle exec rspec
bundle exec rubocop
```

### CI/CD
- GitHub Actions runs tests on Ruby 3.2, 3.3, and 2.7 (best-effort)
- All tests must pass before merging
- RuboCop violations must be fixed

### Version Support
- Ruby: 2.7, 3.0, 3.1, 3.2, 3.3
- Rails: 6.0, 6.1, 7.0, 7.1, 7.2
- Note: Ruby 3.1 is excluded from CI due to Rails 8.0 incompatibility

### Code Style
- Follow existing code conventions
- Use RuboCop for style checking
- Keep line length under 120 characters
- Add frozen_string_literal comment to all Ruby files

## Common Tasks

### Running Tests
```bash
# All tests
bundle exec rspec

# With coverage
COVERAGE=true bundle exec rspec

# Specific file
bundle exec rspec spec/time_furoshiki/migration_storage_spec.rb
```

### Linting
```bash
# Check for violations
bundle exec rubocop

# Auto-fix violations
bundle exec rubocop -a
```

### Building Gem
```bash
gem build time-furoshiki.gemspec
```

## File Structure

```
time-furoshiki/
├── lib/
│   ├── time_furoshiki.rb              # Main module
│   ├── time_furoshiki/
│   │   ├── version.rb                 # Version constant
│   │   ├── configuration.rb           # Configuration class
│   │   ├── migration_storage.rb       # Core storage logic
│   │   ├── rails_hooks.rb            # Rails integration
│   │   └── railtie.rb                # Rails engine
│   └── time/
│       └── furoshiki.rb              # Backward compatibility
├── spec/                              # Test files
├── README.md                          # English documentation
├── README.jp.md                       # Japanese documentation (keep synchronized!)
├── SPEC.md                           # Technical specification
└── time-furoshiki.gemspec            # Gem specification
```

## Key Components

### MigrationStorage
Handles storing and retrieving migration contents from the database.

### RailsHooks
Integrates with Rails migration framework to capture and use stored migrations.

### Configuration
Manages gem configuration options like `keep_rolled_back_migrations` and `verbose`.

## Important Notes

1. **Always update both README files**: README.md and README.jp.md must stay synchronized
2. **Test before committing**: Run full test suite and linter
3. **Check CI status**: Ensure GitHub Actions passes
4. **Follow TDD**: Write tests first, then implementation
5. **Document changes**: Update relevant documentation when adding features