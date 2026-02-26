# frozen_string_literal: true

RSpec.describe Docsterra::Renderer::ResourceTable do
  let(:parser) { Docsterra::Parser::HclParser.new }
  let(:registry) { Docsterra::Parser::ResourceRegistry.new }

  it "renders grouped markdown tables" do
    file = File.expand_path("../../fixtures/network.tf", __dir__)
    project = Docsterra::Model::Project.new(name: "network", path: File.dirname(file), parsed_files: { file => parser.parse_file(file) })
    Docsterra::Analyzer::ResourceAnalyzer.new(registry: registry).analyze(project)

    markdown = described_class.new(resources: project.resources).render

    expect(markdown).to include("#### Networking")
    expect(markdown).to include("| Resource Type | Resource Name |")
    expect(markdown).to include("google_compute_network")
  end

  it "renders empty state" do
    markdown = described_class.new(resources: []).render
    expect(markdown).to eq("No resources")
  end
end
