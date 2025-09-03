# frozen_string_literal: true

module TimeFuroshiki
  class Configuration
    attr_accessor :keep_rolled_back_migrations, :auto_clean_orphaned, :verbose

    def initialize
      @keep_rolled_back_migrations = true
      @auto_clean_orphaned = false
      @verbose = false
    end
  end
end
