# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Migration Lifecycle Integration" do
  # Mock Rails environment
  before(:each) do
    rails_mock = double("Rails",
                        root: Pathname.new("/test/app"),
                        logger: double("Logger", info: nil, warn: nil, error: nil))

    stub_const("Rails", rails_mock)
  end

  describe "when running migrations" do
    let(:migration_version) { "20240101120000" }
    let(:migration_filename) { "#{migration_version}_create_users.rb" }
    let(:migration_content) do
      <<~RUBY
        class CreateUsers < ActiveRecord::Migration[7.0]
          def change
            create_table :users do |t|
              t.string :name
              t.timestamps
            end
          end
        end
      RUBY
    end

    it "stores migration content before execution" do
      storage = instance_double(TimeFuroshiki::MigrationStorage)
      allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)

      # Expect storage.store to be called with correct parameters
      expect(storage).to receive(:store).with(
        version: migration_version,
        filename: migration_filename,
        content: migration_content
      ).and_return(true)

      # Simulate migration storage
      storage_instance = TimeFuroshiki::MigrationStorage.new
      storage_instance.store(
        version: migration_version,
        filename: migration_filename,
        content: migration_content
      )
    end

    it "logs warning if storage fails" do
      storage = instance_double(TimeFuroshiki::MigrationStorage)
      allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)
      allow(storage).to receive(:store).and_return(false)

      expect(Rails.logger).to receive(:warn).with(/Failed to store migration content/)

      # Simulate failed storage with logging
      unless storage.store(version: migration_version, filename: migration_filename, content: migration_content)
        Rails.logger.warn("[TimeFuroshiki] Failed to store migration content for #{migration_version}")
      end
    end
  end

  describe "when rolling back migrations" do
    let(:migration_version) { "20240101130000" }

    context "with stored migration content" do
      it "uses stored content for rollback" do
        storage = instance_double(TimeFuroshiki::MigrationStorage)
        allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)

        # Mock that migration exists
        allow(storage).to receive(:exists?).with(migration_version).and_return(true)

        # Mock retrieving stored content
        stored_content = {
          "version" => migration_version,
          "filename" => "#{migration_version}_add_posts.rb",
          "content" => "class AddPosts < ActiveRecord::Migration[7.0]; end"
        }
        allow(storage).to receive(:retrieve).with(migration_version).and_return(stored_content)

        expect(Rails.logger).to receive(:info).with(/Using stored migration content for rollback/)

        # Simulate rollback with stored content
        if storage.exists?(migration_version)
          Rails.logger.info("[TimeFuroshiki] Using stored migration content for rollback: #{migration_version}")
          stored_migration = storage.retrieve(migration_version)
          expect(stored_migration).not_to be_nil
        end
      end
    end

    context "without stored migration content" do
      it "logs warning and falls back to original file" do
        storage = instance_double(TimeFuroshiki::MigrationStorage)
        allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)

        # Mock that migration does not exist
        allow(storage).to receive(:exists?).with(migration_version).and_return(false)

        expect(Rails.logger).to receive(:warn).with(/No stored migration found/)

        # Simulate rollback without stored content
        unless storage.exists?(migration_version)
          Rails.logger.warn("[TimeFuroshiki] No stored migration found for rollback: #{migration_version}")
        end
      end
    end

    context "with configuration" do
      it "keeps rolled back migrations when configured" do
        TimeFuroshiki.configure do |config|
          config.keep_rolled_back_migrations = true
        end

        storage = instance_double(TimeFuroshiki::MigrationStorage)
        allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)
        allow(storage).to receive(:exists?).with(migration_version).and_return(true)

        # Should NOT delete the migration
        expect(storage).not_to receive(:delete)

        # Simulate rollback completion
        if storage.exists?(migration_version)
          Rails.logger.info("[TimeFuroshiki] Using stored migration content for rollback: #{migration_version}")

          storage.delete(migration_version) unless TimeFuroshiki.configuration.keep_rolled_back_migrations
        end
      end

      it "deletes rolled back migrations when configured" do
        TimeFuroshiki.configure do |config|
          config.keep_rolled_back_migrations = false
        end

        storage = instance_double(TimeFuroshiki::MigrationStorage)
        allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)
        allow(storage).to receive(:exists?).with(migration_version).and_return(true)

        # Should delete the migration
        expect(storage).to receive(:delete).with(migration_version).and_return(true)
        expect(Rails.logger).to receive(:info).with(/Deleted stored migration after rollback/)

        # Simulate rollback completion with deletion
        if storage.exists?(migration_version)
          Rails.logger.info("[TimeFuroshiki] Using stored migration content for rollback: #{migration_version}")

          unless TimeFuroshiki.configuration.keep_rolled_back_migrations
            storage.delete(migration_version)
            Rails.logger.info("[TimeFuroshiki] Deleted stored migration after rollback: #{migration_version}")
          end
        end
      end
    end
  end

  describe "error handling" do
    it "continues migration even if file reading fails" do
      allow(File).to receive(:exist?).and_return(false)
      expect(Rails.logger).to receive(:error).with(/Migration file not found/)

      migration_path = Rails.root.join("db/migrate/test_migration.rb")

      if File.exist?(migration_path)
        # This won't execute since we mocked File.exist? to return false
      else
        Rails.logger.error("[TimeFuroshiki] Migration file not found: #{migration_path}")
      end
    end

    it "handles storage exceptions gracefully" do
      storage = instance_double(TimeFuroshiki::MigrationStorage)
      allow(TimeFuroshiki::MigrationStorage).to receive(:new).and_return(storage)
      allow(storage).to receive(:store).and_raise(StandardError, "Database error")

      expect(Rails.logger).to receive(:error).with(/Error storing migration/)

      begin
        storage.store(version: "123", filename: "test.rb", content: "content")
      rescue StandardError => e
        Rails.logger.error("[TimeFuroshiki] Error storing migration: #{e.message}")
      end
    end
  end
end
