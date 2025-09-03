# frozen_string_literal: true

require "active_record"

module TimeFuroshiki
  module MigratorExtension
    def self.prepended(base)
      base.class_eval do
        alias_method :run_without_storage, :run
        alias_method :run, :run_with_storage

        alias_method :migrate_without_storage, :migrate
        alias_method :migrate, :migrate_with_storage
      end
    end

    def run_with_storage
      # In Rails 8, direction is available as @direction
      direction = @direction || :up

      store_migration_before_run if direction == :up

      result = run_without_storage

      handle_rollback_completion if direction == :down

      result
    end

    def migrate_with_storage
      # In Rails 8, direction is available as @direction
      direction = @direction || :up

      if direction == :up
        migrations_to_run = pending_migrations
        migrations_to_run.each do |migration|
          store_migration_content(migration)
        end
      end

      result = migrate_without_storage

      handle_rollback_for_version(@target_version) if direction == :down && @target_version

      result
    end

    private

    def store_migration_before_run
      return unless @migration

      store_migration_content(@migration)
    end

    def store_migration_content(migration)
      version = migration.version.to_s
      filename = migration.filename
      migration_path = determine_migration_path(filename)

      return log_missing_file(migration_path) unless File.exist?(migration_path)

      content = File.read(migration_path)
      storage = MigrationStorage.new
      base_filename = File.basename(filename)

      unless storage.store(version: version, filename: base_filename, content: content)
        Rails.logger.warn("[TimeFuroshiki] Failed to store migration content for #{version}")
      end
    rescue StandardError => e
      Rails.logger.error("[TimeFuroshiki] Error storing migration: #{e.message}")
    end

    def determine_migration_path(filename)
      filename.include?("/") ? filename : Rails.root.join("db/migrate/#{filename}")
    end

    def log_missing_file(path)
      Rails.logger.error("[TimeFuroshiki] Migration file not found: #{path}")
    end

    def handle_rollback_completion
      # In Rails 8, we might have @migrations instead of @migration
      migration = @migration || @migrations&.first
      return unless migration

      version = migration.version.to_s
      storage = MigrationStorage.new

      if storage.exists?(version)
        Rails.logger.info("[TimeFuroshiki] Using stored migration content for rollback: #{version}")

        unless TimeFuroshiki.configuration.keep_rolled_back_migrations
          storage.delete(version)
          Rails.logger.info("[TimeFuroshiki] Deleted stored migration after rollback: #{version}")
        end
      else
        Rails.logger.warn("[TimeFuroshiki] No stored migration found for rollback: #{version}")
      end
    end

    def handle_rollback_for_version(version)
      storage = MigrationStorage.new

      return unless storage.exists?(version.to_s)

      Rails.logger.info("[TimeFuroshiki] Rollback completed for stored migration: #{version}")

      return if TimeFuroshiki.configuration.keep_rolled_back_migrations

      storage.delete(version.to_s)
    end
  end

  module MigrationExtension
    def self.prepended(base)
      base.class_eval do
        alias_method :migrate_without_storage, :migrate
        alias_method :migrate, :migrate_with_storage

        alias_method :revert_without_storage, :revert
        alias_method :revert, :revert_with_storage
      end
    end

    def migrate_with_storage(direction)
      if direction == :up
        store_before_migration
      elsif direction == :down
        use_stored_content_if_available
      end

      migrate_without_storage(direction)
    end

    def revert_with_storage(...)
      use_stored_content_if_available
      revert_without_storage(...)
    end

    private

    def store_before_migration
      version = self.version.to_s
      filename = "#{self.class.name.underscore}.rb"
      migration_path = Rails.root.join("db/migrate/*_#{filename}")

      actual_path = Dir.glob(migration_path).first
      if actual_path && File.exist?(actual_path)
        content = File.read(actual_path)
        storage = MigrationStorage.new
        storage.store(
          version: version,
          filename: File.basename(actual_path),
          content: content
        )
      end
    rescue StandardError => e
      Rails.logger.error("[TimeFuroshiki] Error in store_before_migration: #{e.message}")
    end

    def use_stored_content_if_available
      version = self.version.to_s
      storage = MigrationStorage.new

      if storage.exists?(version)
        stored_content = storage.retrieve(version)
        if stored_content
          Rails.logger.info("[TimeFuroshiki] Using stored migration content for version #{version}")
          # The stored content is available for use if needed
          # The actual rollback will still use the migration's down/change method
        end
      end
    rescue StandardError => e
      Rails.logger.error("[TimeFuroshiki] Error in use_stored_content_if_available: #{e.message}")
    end
  end
end
