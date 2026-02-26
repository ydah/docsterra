# frozen_string_literal: true

RSpec.describe Terradoc::Analyzer::NetworkAnalyzer do
  let(:parser) { Terradoc::Parser::HclParser.new }
  let(:registry) { Terradoc::Parser::ResourceRegistry.new }
  let(:resource_analyzer) { Terradoc::Analyzer::ResourceAnalyzer.new(registry: registry) }

  it "extracts VPC, subnet, firewall and links" do
    file = File.expand_path("../../fixtures/network.tf", __dir__)
    project = Terradoc::Model::Project.new(
      name: "network",
      path: File.dirname(file),
      parsed_files: { file => parser.parse_file(file) }
    )
    resource_analyzer.analyze(project)

    network = described_class.new.analyze(project.resources)

    expect(network.vpcs.size).to eq(1)
    expect(network.subnets.size).to eq(1)
    expect(network.firewall_rules.size).to eq(1)
    expect(network.links.map { |link| link[:target].type }).to include("google_compute_network")
  end
end
