# frozen_string_literal: true

RSpec.describe Docsterra::Analyzer::ResourceAnalyzer do
  let(:parser) { Docsterra::Parser::HclParser.new }
  let(:registry) { Docsterra::Parser::ResourceRegistry.new }

  def parse_project_from_files(name, *files)
    parsed_files = files.each_with_object({}) { |file, result| result[file] = parser.parse_file(file) }
    Docsterra::Model::Project.new(name: name, path: File.dirname(files.first), parsed_files: parsed_files)
  end

  it "builds resources with nested attributes and references" do
    project = parse_project_from_files(
      "network",
      File.expand_path("../../fixtures/network.tf", __dir__)
    )

    described_class.new(registry: registry).analyze(project)

    subnet = project.resources.find { |resource| resource.type == "google_compute_subnetwork" }
    firewall = project.resources.find { |resource| resource.type == "google_compute_firewall" }

    expect(subnet.attribute_text("network")).to eq("google_compute_network.main.id")
    expect(subnet.references).to include("google_compute_network.main.id")

    expect(firewall.attribute_text("allow.protocol")).to eq("tcp")
    expect(firewall.attribute_ruby("allow.ports")).to eq(%w[80 443])
    expect(firewall.category).to eq(:networking)
  end

  it "builds data sources separately from resources" do
    files = [
      File.expand_path("../../fixtures/multi_product/product-web/main.tf", __dir__),
      File.expand_path("../../fixtures/multi_product/product-web/network.tf", __dir__)
    ]
    project = parse_project_from_files("product-web", *files)

    described_class.new(registry: registry).analyze(project)

    expect(project.resources.map(&:type)).to include("google_cloud_run_service", "google_compute_firewall")
    expect(project.data_sources.map(&:type)).to include("google_compute_network")
  end
end
