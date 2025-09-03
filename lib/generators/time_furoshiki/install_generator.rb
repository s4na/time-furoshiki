# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module TimeFuroshiki
  module Generators
    # Generator for installing time_furoshiki migrations
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates time_furoshiki migration file"

      def create_migration_file
        migration_template(
          "create_time_furoshiki_migrations.rb.erb",
          "db/migrate/create_time_furoshiki_migrations.rb",
          migration_version: migration_version
        )
      end

      def create_initializer
        template "time_furoshiki.rb", "config/initializers/time_furoshiki.rb"
      end

      def display_post_install_message
        say "\n"
        say "TimeFuroshiki has been successfully installed!", :green
        say "\n"
        say "Next steps:"
        say "  1. Run 'rails db:migrate' to create the time_furoshiki_migrations table"
        say "  2. Optionally configure TimeFuroshiki in config/initializers/time_furoshiki.rb"
        say "\n"
      end

      class << self
        def next_migration_number(dirname)
          ActiveRecord::Generators::Migration.next_migration_number(dirname)
        end
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
