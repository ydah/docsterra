# frozen_string_literal: true

RSpec.describe Terradoc::CLI do
  describe ".start" do
    it "prints version" do
      expect { described_class.start(["version"]) }
        .to output("#{Terradoc::VERSION}\n").to_stdout
    end

    it "prints a dry-run summary" do
      expect { described_class.start(["check", "./terraform"]) }
        .to output(/Terradoc check summary/).to_stdout
    end
  end
end
