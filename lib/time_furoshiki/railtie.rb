# frozen_string_literal: true

require "rails/railtie"

module TimeFuroshiki
  class Railtie < Rails::Railtie
    initializer "time_furoshiki.initialize" do
      ActiveSupport.on_load(:active_record) do
        require_relative "migrator_extension"

        # Prepend our extensions to the migration classes
        ActiveRecord::Migrator.prepend(TimeFuroshiki::MigratorExtension) if defined?(ActiveRecord::Migrator)

        ActiveRecord::Migration.prepend(TimeFuroshiki::MigrationExtension) if defined?(ActiveRecord::Migration)

        # Ensure the table exists
        TimeFuroshiki::Railtie.ensure_table_exists
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/time_furoshiki.rake", __dir__)
    end

    generators do
      require_relative "../generators/time_furoshiki/install_generator"
    end

    def self.ensure_table_exists
      return if ActiveRecord::Base.connection.table_exists?("time_furoshiki_migrations")

      Rails.logger.info("[TimeFuroshiki] Creating time_furoshiki_migrations table...")

      ActiveRecord::Schema.define do
        create_table :time_furoshiki_migrations do |t|
          t.string :version, null: false
          t.string :filename, null: false
          t.text :content, null: false
          t.datetime :executed_at
          t.timestamps
        end

        add_index :time_furoshiki_migrations, :version, unique: true
        add_index :time_furoshiki_migrations, :executed_at
      end

      Rails.logger.info("[TimeFuroshiki] Table created successfully")
    rescue StandardError => e
      Rails.logger.error("[TimeFuroshiki] Failed to create table: #{e.message}")
    end
  end
end
