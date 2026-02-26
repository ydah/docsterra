# frozen_string_literal: true

require "tmpdir"

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

    it "prints format in dry-run summary" do
      expect { described_class.start(["check", "./terraform", "-f", "markdown"]) }
        .to output(/Format: markdown/).to_stdout
    end

    it "generates markdown file" do
      Dir.mktmpdir do |dir|
        base = File.expand_path("../../fixtures/multi_product", __dir__)
        output_path = File.join(dir, "infrastructure.md")

        expect do
          described_class.start(["generate", File.join(base, "shared"), "-o", output_path])
        end.to output(/Generated .*resources across .*projects/).to_stdout

        expect(File).to exist(output_path)
        expect(File.read(output_path)).to include("# Infrastructure Design Document")
      end
    end

    it "prints progress messages in verbose mode" do
      base = File.expand_path("../../fixtures/multi_product", __dir__)
      expect do
        described_class.start(["check", File.join(base, "shared"), "-v"])
      end.to output(/Parsing .*Terraform files/).to_stdout
    end
  end
end
