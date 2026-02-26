# frozen_string_literal: true

RSpec.describe Docsterra::Parser::ResourceRegistry do
  describe "#definition_for" do
    it "returns built-in metadata for known resources" do
      registry = described_class.new

      definition = registry.definition_for("google_compute_instance")

      expect(definition[:display_name]).to eq("Compute Engine Instance")
      expect(definition[:category]).to eq(:compute)
      expect(definition[:key_attributes]).to include("machine_type", "zone")
    end

    it "applies custom key attribute overrides" do
      registry = described_class.new(custom_attributes: { "google_compute_instance" => ["name", "labels.env"] })

      expect(registry.key_attributes_for("google_compute_instance")).to eq(["name", "labels.env"])
    end

    it "returns a safe default for unknown resources" do
      registry = described_class.new

      definition = registry.definition_for("google_unknown_resource")

      expect(definition[:display_name]).to eq("google_unknown_resource")
      expect(definition[:category]).to eq(:other)
      expect(definition[:key_attributes]).to eq([])
    end
  end
end
