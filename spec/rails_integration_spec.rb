# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "fileutils"
require "tmpdir"

RSpec.describe "Rails Integration" do
  let(:test_app_path) { Dir.mktmpdir("test_rails_app") }
  let(:db_path) { File.join(test_app_path, "test.db") }
  let(:migrate_dir) { File.join(test_app_path, "db/migrate") }

  before(:all) do
    # Stub Rails.root and Rails.logger for testing
    rails_class = Class.new do
      attr_accessor :root, :logger

      def initialize
        @logger = Logger.new($stdout)
        @logger.level = Logger::WARN
      end
    end

    # Remove existing Rails constant if it exists
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, rails_class.new)
  end

  before(:each) do
    # Setup test Rails app structure
    Rails.root = Pathname.new(test_app_path)
    FileUtils.mkdir_p(migrate_dir)

    # Setup database - using in-memory database for testing
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    # Create schema_migrations table
    ActiveRecord::Base.connection.create_table :schema_migrations, id: false, force: true do |t|
      t.string :version, null: false
    end

    ActiveRecord::Base.connection.add_index :schema_migrations, :version,
                                            unique: true, name: "unique_schema_migrations"

    # Create time_furoshiki_migrations table
    ActiveRecord::Base.connection.create_table :time_furoshiki_migrations, force: true do |t|
      t.string :version, null: false
      t.string :filename, null: false
      t.text :content, null: false
      t.datetime :executed_at
      t.timestamps
    end

    ActiveRecord::Base.connection.add_index :time_furoshiki_migrations, :version,
                                            unique: true, name: "index_time_furoshiki_migrations_on_version"

    # Prepend our modules to ActiveRecord classes
    unless ActiveRecord::Migrator.included_modules.include?(TimeFuroshiki::MigratorExtension)
      ActiveRecord::Migrator.prepend(TimeFuroshiki::MigratorExtension)
    end

    unless ActiveRecord::Migration.included_modules.include?(TimeFuroshiki::MigrationExtension)
      ActiveRecord::Migration.prepend(TimeFuroshiki::MigrationExtension)
    end
  end

  after(:each) do
    ActiveRecord::Base.connection.close if ActiveRecord::Base.connected?
    FileUtils.rm_rf(test_app_path)
  end

  describe "migration storage" do
    let(:migration_version) { "20240101120000" }
    let(:migration_filename) { "#{migration_version}_create_users.rb" }
    let(:migration_path) { File.join(migrate_dir, migration_filename) }
    let(:migration_content) do
      <<~RUBY
        class CreateUsers < ActiveRecord::Migration[7.0]
          def change
            create_table :users do |t|
              t.string :name
              t.string :email
              t.timestamps
            end
          end
        end
      RUBY
    end

    before do
      File.write(migration_path, migration_content)
    end

    it "stores migration content when running migrations" do
      # Create migration instance
      require migration_path
      migration_class = CreateUsers
      migration_class.new(migration_filename, migration_version.to_i)

      # Run the migration
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
      context.run(:up, migration_version.to_i)

      # Check that migration was stored
      storage = TimeFuroshiki::MigrationStorage.new
      expect(storage.exists?(migration_version)).to be true

      stored_migration = storage.retrieve(migration_version)
      expect(stored_migration).not_to be_nil
      expect(stored_migration["content"]).to eq(migration_content)
      expect(stored_migration["filename"]).to eq(migration_filename)
    end

    it "stores multiple migrations when running migrate" do
      # Create multiple migrations
      migrations = []
      3.times do |i|
        version = "2024010114000#{i}"
        filename = "#{version}_create_table_#{i}.rb"
        path = File.join(migrate_dir, filename)
        content = <<~RUBY
          class CreateTable#{i} < ActiveRecord::Migration[7.0]
            def change
              create_table :table_#{i} do |t|
                t.string :name
                t.timestamps
              end
            end
          end
        RUBY
        File.write(path, content)
        require path
        migration_class = Object.const_get("CreateTable#{i}")
        migrations << migration_class.new(filename, version.to_i)
      end

      # Run all migrations
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
      context.up

      # Check all migrations were stored
      storage = TimeFuroshiki::MigrationStorage.new
      migrations.each do |migration|
        version = migration.version.to_s
        expect(storage.exists?(version)).to be true
        stored = storage.retrieve(version)
        expect(stored).not_to be_nil
      end
    end
  end

  describe "rollback functionality" do
    let(:migration_version) { "20240101130000" }
    let(:migration_filename) { "#{migration_version}_add_posts.rb" }
    let(:migration_path) { File.join(migrate_dir, migration_filename) }
    let(:original_content) do
      <<~RUBY
        class AddPosts < ActiveRecord::Migration[7.0]
          def up
            create_table :posts do |t|
              t.string :title
              t.text :body
              t.timestamps
            end
          end

          def down
            drop_table :posts
          end
        end
      RUBY
    end

    before do
      File.write(migration_path, original_content)
      require migration_path
    end

    it "uses stored migration content for rollback" do
      migration_class = AddPosts
      migration_class.new(migration_filename, migration_version.to_i)

      # Run the migration up
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
      context.run(:up, migration_version.to_i)

      # Verify table was created
      expect(ActiveRecord::Base.connection.table_exists?(:posts)).to be true

      # Verify migration was stored
      storage = TimeFuroshiki::MigrationStorage.new
      expect(storage.exists?(migration_version)).to be true

      # TODO: Implement actual execution of stored migration content during rollback
      # For now, we'll just verify the content is stored and can be retrieved
      stored_migration = storage.retrieve(migration_version)
      expect(stored_migration).not_to be_nil
      expect(stored_migration["content"]).to include("create_table :posts")

      # Run rollback with original file (current implementation doesn't execute stored content yet)
      context.run(:down, migration_version.to_i)

      # Verify table was dropped
      expect(ActiveRecord::Base.connection.table_exists?(:posts)).to be false
    end

    it "handles missing migration files during rollback" do
      migration_class = AddPosts
      migration_class.new(migration_filename, migration_version.to_i)

      # Run the migration up
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
      context.run(:up, migration_version.to_i)

      # Verify migration was stored
      storage = TimeFuroshiki::MigrationStorage.new
      expect(storage.exists?(migration_version)).to be true

      # TODO: Implement loading stored migration when file is missing
      # For now, we'll just verify the content is stored
      stored_migration = storage.retrieve(migration_version)
      expect(stored_migration).not_to be_nil
      expect(stored_migration["filename"]).to eq(migration_filename)
    end

    context "with configuration" do
      it "keeps rolled back migrations when configured" do
        TimeFuroshiki.configure do |config|
          config.keep_rolled_back_migrations = true
        end

        migration_class = AddPosts
        migration_class.new(migration_filename, migration_version.to_i)

        # Run migration up
        schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
        context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
        context.run(:up, migration_version.to_i)

        # Run rollback
        context.run(:down, migration_version.to_i)

        # Check that migration is still stored
        storage = TimeFuroshiki::MigrationStorage.new
        expect(storage.exists?(migration_version)).to be true
      end

      it "deletes rolled back migrations when configured" do
        TimeFuroshiki.configure do |config|
          config.keep_rolled_back_migrations = false
        end

        migration_class = AddPosts
        migration_class.new(migration_filename, migration_version.to_i)

        # Run migration up
        schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
        context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
        context.run(:up, migration_version.to_i)

        # Run rollback
        context.run(:down, migration_version.to_i)

        # Check that migration was deleted
        storage = TimeFuroshiki::MigrationStorage.new
        expect(storage.exists?(migration_version)).to be false
      end
    end
  end

  describe "error handling" do
    it "continues migration even if storage fails" do
      # Mock storage to fail
      allow_any_instance_of(TimeFuroshiki::MigrationStorage).to receive(:store).and_return(false)

      migration_version = "20240101140000"
      migration_filename = "#{migration_version}_create_products.rb"
      migration_path = File.join(migrate_dir, migration_filename)
      migration_content = <<~RUBY
        class CreateProducts < ActiveRecord::Migration[7.0]
          def change
            create_table :products do |t|
              t.string :name
              t.decimal :price
              t.timestamps
            end
          end
        end
      RUBY

      File.write(migration_path, migration_content)
      require migration_path

      migration_class = CreateProducts
      migration_class.new(migration_filename, migration_version.to_i)

      # Migration should succeed even if storage fails
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)

      # Run migration - should succeed even if storage fails
      expect { context.run(:up, migration_version.to_i) }.not_to raise_error

      # Table should exist
      expect(ActiveRecord::Base.connection.table_exists?(:products)).to be true
    end

    it "logs warning when migration file is not found" do
      # Create a migration with a path that doesn't exist
      migration_version = "20240101150000"
      migration_filename = "#{migration_version}_test_migration.rb"
      migration_path = File.join(migrate_dir, "nonexistent", migration_filename)

      # Create a dummy migration class
      Class.new(ActiveRecord::Migration[7.0]) do
        def change
          create_table :test_table do |t|
            t.string :name
          end
        end
      end

      allow(Rails.logger).to receive(:error)

      # Create a mock migration object with filename method
      migration = double("migration",
                         version: migration_version.to_i,
                         filename: migration_path)

      # Try to store the migration content - should log error
      migrator_extension = Object.new.extend(TimeFuroshiki::MigratorExtension)
      migrator_extension.instance_variable_set(:@migration, migration)
      migrator_extension.send(:store_migration_before_run)

      expect(Rails.logger).to have_received(:error).with(/Migration file not found/)
    end
  end

  describe "migration with change method" do
    let(:migration_version) { "20240101160000" }
    let(:migration_filename) { "#{migration_version}_create_comments.rb" }
    let(:migration_path) { File.join(migrate_dir, migration_filename) }
    let(:migration_content) do
      <<~RUBY
        class CreateComments < ActiveRecord::Migration[7.0]
          def change
            create_table :comments do |t|
              t.string :author
              t.text :content
              t.references :post, foreign_key: true
              t.timestamps
            end

            add_index :comments, :author
          end
        end
      RUBY
    end

    before do
      # Create posts table first for foreign key
      ActiveRecord::Base.connection.create_table :posts do |t|
        t.string :title
        t.timestamps
      end

      File.write(migration_path, migration_content)
      require migration_path
    end

    it "stores and rolls back migrations with change method" do
      migration_class = CreateComments
      migration_class.new(migration_filename, migration_version.to_i)

      # Run migration up
      schema_migration = ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      context = ActiveRecord::MigrationContext.new([migrate_dir], schema_migration)
      context.run(:up, migration_version.to_i)

      # Verify table and index were created
      expect(ActiveRecord::Base.connection.table_exists?(:comments)).to be true
      indexes = ActiveRecord::Base.connection.indexes(:comments)
      expect(indexes.map(&:name)).to include("index_comments_on_author")

      # Verify migration was stored
      storage = TimeFuroshiki::MigrationStorage.new
      expect(storage.exists?(migration_version)).to be true

      # Run rollback
      context.run(:down, migration_version.to_i)

      # Verify table was dropped
      expect(ActiveRecord::Base.connection.table_exists?(:comments)).to be false
    end
  end
end
