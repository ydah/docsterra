# frozen_string_literal: true

require "tmpdir"

RSpec.describe Terradoc::Config do
  describe ".from_cli_options" do
    it "preserves false booleans for verbose" do
      config = described_class.from_cli_options(paths: ["./terraform"], options: { verbose: false })

      expect(config.verbose).to eq(false)
    end

    it "keeps config output and sections when CLI only provides defaults" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".terradoc.yml")
        File.write(
          config_path,
          <<~YAML
            output:
              path: "./docs/custom.md"
              sections:
                - resources
                - security
              format: markdown
          YAML
        )

        config = described_class.from_cli_options(
          paths: [],
          options: {
            config: config_path,
            output: described_class::DEFAULT_OUTPUT_PATH,
            sections: "all",
            verbose: false,
            ignore: []
          }
        )

        expect(config.output_path).to eq("./docs/custom.md")
        expect(config.sections).to eq(%w[resources security])
        expect(config.format).to eq("markdown")
      end
    end

    it "allows CLI format override" do
      config = described_class.from_cli_options(paths: ["./terraform"], options: { format: "markdown" })

      expect(config.format).to eq("markdown")
    end
  end

  describe "#product_definitions" do
    it "keeps shared false when config explicitly sets false" do
      config = described_class.new(
        products: [
          { "name" => "A", "path" => "./a", "shared" => false },
          { "name" => "B", "path" => "./b", "shared" => true }
        ]
      )

      defs = config.product_definitions

      expect(defs[0]["shared"]).to eq(false)
      expect(defs[1]["shared"]).to eq(true)
    end
  end
end
