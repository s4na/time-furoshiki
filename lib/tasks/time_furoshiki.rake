# frozen_string_literal: true

namespace :time_furoshiki do
  desc "Install time_furoshiki migrations table"
  task install: :environment do
    if ActiveRecord::Base.connection.table_exists?("time_furoshiki_migrations")
      puts "Table 'time_furoshiki_migrations' already exists"
    else
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

      puts "Created table 'time_furoshiki_migrations'"
    end
  end

  desc "Show status of stored migrations"
  task status: :environment do
    require "time_furoshiki/migration_storage"

    storage = TimeFuroshiki::MigrationStorage.new
    migrations = storage.all

    if migrations.empty?
      puts "No stored migrations found"
    else
      puts "\nStored Migrations:"
      puts "-" * 80
      printf "%-20s %-40s %-20s\n", "Version", "Filename", "Executed At"
      puts "-" * 80

      migrations.each do |migration|
        printf "%-20s %-40s %-20s\n",
               migration.version,
               migration.filename.truncate(40),
               migration.executed_at&.strftime("%Y-%m-%d %H:%M:%S") || "N/A"
      end

      puts "-" * 80
      puts "Total: #{migrations.count} stored migration(s)"
    end
  end

  desc "Clean orphaned migration records"
  task clean: :environment do
    require "time_furoshiki/migration_storage"

    storage = TimeFuroshiki::MigrationStorage.new
    count = storage.clean_orphaned

    if count.positive?
      puts "Cleaned #{count} orphaned migration record(s)"
    else
      puts "No orphaned migrations found"
    end
  end

  desc "Export stored migrations to files"
  task export: :environment do
    require "time_furoshiki/migration_storage"
    require "fileutils"

    export_dir = Rails.root.join("tmp/exported_migrations")
    FileUtils.mkdir_p(export_dir)

    storage = TimeFuroshiki::MigrationStorage.new
    migrations = storage.all

    if migrations.empty?
      puts "No stored migrations to export"
    else
      migrations.each do |migration|
        file_path = export_dir.join(migration.filename)
        File.write(file_path, migration.content)
        puts "Exported: #{migration.filename}"
      end

      puts "\nExported #{migrations.count} migration(s) to #{export_dir}"
    end
  end
end
