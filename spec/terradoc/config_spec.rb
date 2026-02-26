# frozen_string_literal: true

RSpec.describe Terradoc::Config do
  describe ".from_cli_options" do
    it "preserves false booleans for verbose" do
      config = described_class.from_cli_options(paths: ["./terraform"], options: { verbose: false })

      expect(config.verbose).to eq(false)
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
