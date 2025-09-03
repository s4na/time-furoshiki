# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "tmpdir"
require "fileutils"

RSpec.describe TimeFuroshiki::MigrationStorage do
  let(:storage) { described_class.new }
  let(:test_migration_version) { "20240101120000" }
  let(:test_migration_filename) { "#{test_migration_version}_create_test_table.rb" }
  let(:test_migration_content) do
    <<~RUBY
      class CreateTestTable < ActiveRecord::Migration[7.0]
        def change
          create_table :test_tables do |t|
            t.string :name
            t.timestamps
          end
        end
      end
    RUBY
  end

  before(:all) do
    # Create a simple Rails mock
    rails_class = Class.new do
      attr_accessor :root, :logger

      def initialize
        @logger = Logger.new(nil) # Silent logger
        @root = Pathname.new(Dir.mktmpdir)
      end
    end

    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, rails_class.new)
  end

  before(:each) do
    # Setup in-memory database
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

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
  end

  after(:each) do
    ActiveRecord::Base.connection.close if ActiveRecord::Base.connected?
  end

  describe "#store" do
    it "stores migration content in the database" do
      result = storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      expect(result).to be true

      # Verify data was stored
      stored = ActiveRecord::Base.connection.execute(
        "SELECT * FROM time_furoshiki_migrations WHERE version = '#{test_migration_version}'"
      ).first

      expect(stored).not_to be_nil
      expect(stored["version"]).to eq(test_migration_version)
      expect(stored["filename"]).to eq(test_migration_filename)
      expect(stored["content"]).to eq(test_migration_content)
    end

    it "does not store duplicate migrations" do
      # Store once
      storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      # Try to store again
      result = storage.store(
        version: test_migration_version,
        filename: "different_name.rb",
        content: "different content"
      )

      expect(result).to be false

      # Verify only one record exists
      count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) as count FROM time_furoshiki_migrations WHERE version = '#{test_migration_version}'"
      ).first["count"]

      expect(count).to eq(1)
    end

    it "handles storage errors gracefully" do
      # Drop the table to cause an error
      ActiveRecord::Base.connection.drop_table :time_furoshiki_migrations

      result = storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      expect(result).to be false
    end
  end

  describe "#exists?" do
    it "returns true when migration exists" do
      storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      expect(storage.exists?(test_migration_version)).to be true
    end

    it "returns false when migration does not exist" do
      expect(storage.exists?("99999999999999")).to be false
    end
  end

  describe "#retrieve" do
    it "retrieves stored migration content" do
      storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      retrieved = storage.retrieve(test_migration_version)

      expect(retrieved).not_to be_nil
      expect(retrieved["version"]).to eq(test_migration_version)
      expect(retrieved["filename"]).to eq(test_migration_filename)
      expect(retrieved["content"]).to eq(test_migration_content)
    end

    it "returns nil when migration does not exist" do
      retrieved = storage.retrieve("99999999999999")
      expect(retrieved).to be_nil
    end
  end

  describe "#delete" do
    it "deletes stored migration" do
      storage.store(
        version: test_migration_version,
        filename: test_migration_filename,
        content: test_migration_content
      )

      result = storage.delete(test_migration_version)
      expect(result).to be true

      # Verify it was deleted
      expect(storage.exists?(test_migration_version)).to be false
    end

    it "returns false when trying to delete non-existent migration" do
      result = storage.delete("99999999999999")
      expect(result).to be false
    end
  end

  describe "#all" do
    it "returns all stored migrations" do
      # Store multiple migrations
      3.times do |i|
        storage.store(
          version: "2024010112000#{i}",
          filename: "2024010112000#{i}_migration_#{i}.rb",
          content: "content #{i}"
        )
      end

      all_migrations = storage.all
      expect(all_migrations.size).to eq(3)
      expect(all_migrations.map { |m| m["version"] }.sort).to eq(
        %w[20240101120000 20240101120001 20240101120002]
      )
    end

    it "returns empty array when no migrations are stored" do
      expect(storage.all).to eq([])
    end
  end

  describe "#cleanup_orphaned" do
    before do
      # Create schema_migrations table
      ActiveRecord::Base.connection.create_table :schema_migrations, id: false, force: true do |t|
        t.string :version, null: false
      end
    end

    it "removes migrations not in schema_migrations" do
      # Store migrations
      storage.store(
        version: "20240101120000",
        filename: "migration_1.rb",
        content: "content 1"
      )
      storage.store(
        version: "20240101120001",
        filename: "migration_2.rb",
        content: "content 2"
      )

      # Add only one to schema_migrations
      ActiveRecord::Base.connection.execute(
        "INSERT INTO schema_migrations (version) VALUES ('20240101120000')"
      )

      # Cleanup orphaned
      count = storage.cleanup_orphaned

      expect(count).to eq(1)
      expect(storage.exists?("20240101120000")).to be true
      expect(storage.exists?("20240101120001")).to be false
    end
  end
end
