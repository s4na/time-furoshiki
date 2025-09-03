# frozen_string_literal: true

require_relative "time_furoshiki/version"
require_relative "time_furoshiki/configuration"
require_relative "time_furoshiki/migration_storage"
require_relative "time_furoshiki/migrator_extension"
require_relative "time_furoshiki/railtie" if defined?(Rails)

module TimeFuroshiki
  class Error < StandardError; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
