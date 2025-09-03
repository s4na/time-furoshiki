# frozen_string_literal: true

require "spec_helper"

RSpec.describe TimeFuroshiki do
  it "has a version number" do
    expect(TimeFuroshiki::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(TimeFuroshiki::Configuration)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(TimeFuroshiki::Configuration)
    end
  end

  describe ".reset_configuration!" do
    it "resets the configuration to defaults" do
      described_class.configure do |config|
        config.verbose = true
      end

      described_class.reset_configuration!

      expect(described_class.configuration.verbose).to be false
    end
  end
end
