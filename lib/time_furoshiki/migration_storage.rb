# frozen_string_literal: true

require "active_record"

module TimeFuroshiki
  class MigrationStorage
    def store(version:, filename:, content:)
      # Return false if migration already exists (don't overwrite)
      return false if TimeFuroshikiMigration.exists?(version: version)

      migration = TimeFuroshikiMigration.new(
        version: version,
        filename: filename,
        content: content,
        executed_at: Time.current
      )
      migration.save!

      log_verbose("Stored migration #{version}: #{filename}")
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.error("Failed to store migration #{version}: #{e.message}")
      false
    end

    def retrieve(version)
      migration = TimeFuroshikiMigration.find_by(version: version)
      return nil unless migration

      log_verbose("Retrieved migration #{version}")
      {
        "version" => migration.version,
        "filename" => migration.filename,
        "content" => migration.content
      }
    end

    def exists?(version)
      TimeFuroshikiMigration.exists?(version: version)
    end

    def delete(version)
      migration = TimeFuroshikiMigration.find_by(version: version)
      return false unless migration

      migration.destroy
      log_verbose("Deleted migration #{version}")
      true
    end

    def all
      TimeFuroshikiMigration.order(version: :desc)
    end

    def cleanup_orphaned
      count = 0
      # Get all versions from schema_migrations
      schema_versions = if ActiveRecord::Base.connection.table_exists?("schema_migrations")
                          ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations")
                        else
                          []
                        end

      all.each do |migration|
        # Skip if migration is still in schema_migrations (not orphaned)
        next if schema_versions.include?(migration.version)

        migration.destroy
        count += 1
        log_verbose("Cleaned orphaned migration #{migration.version}")
      end
      count
    end

    private

    def log_verbose(message)
      Rails.logger.info("[TimeFuroshiki] #{message}") if TimeFuroshiki.configuration.verbose
    end
  end
end

class TimeFuroshikiMigration < ActiveRecord::Base
  self.table_name = "time_furoshiki_migrations"

  validates :version, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :content, presence: true

  scope :executed, -> { order(version: :desc) }
end
