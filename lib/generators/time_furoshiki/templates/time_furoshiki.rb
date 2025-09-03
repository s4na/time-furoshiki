# frozen_string_literal: true

# Configuration for TimeFuroshiki gem
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
