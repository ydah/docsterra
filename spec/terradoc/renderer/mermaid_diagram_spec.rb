# frozen_string_literal: true

RSpec.describe Terradoc::Renderer::MermaidDiagram do
  let(:parser) { Terradoc::Parser::HclParser.new }
  let(:registry) { Terradoc::Parser::ResourceRegistry.new }
  let(:resource_analyzer) { Terradoc::Analyzer::ResourceAnalyzer.new(registry: registry) }

  it "renders a network mermaid diagram" do
    file = File.expand_path("../../fixtures/network.tf", __dir__)
    project = Terradoc::Model::Project.new(name: "network", path: File.dirname(file), parsed_files: { file => parser.parse_file(file) })
    resource_analyzer.analyze(project)
    project.network = Terradoc::Analyzer::NetworkAnalyzer.new.analyze(project.resources)

    mermaid = described_class.new.render_network(project.network, project_name: project.name)

    expect(mermaid).to start_with("```mermaid\ngraph TB")
    expect(mermaid).to include("subgraph")
  end

  it "renders cross-project dependency mermaid diagram" do
    project_a = Terradoc::Model::Project.new(name: "A", path: ".", parsed_files: {})
    project_b = Terradoc::Model::Project.new(name: "B", path: ".", parsed_files: {})
    res_a = Terradoc::Model::Resource.new(type: "google_cloud_run_service", name: "api", attributes: {}, project: project_a)
    res_b = Terradoc::Model::Resource.new(type: "google_compute_network", name: "vpc", attributes: {}, project: project_b, category: :networking)
    project_a.resources = [res_a]
    project_b.resources = [res_b]
    relationship = Terradoc::Model::Relationship.new(source: res_a, target: res_b, type: :network, detail: "uses shared vpc")

    mermaid = described_class.new.render_project_relationships(projects: [project_a, project_b], relationships: [relationship])

    expect(mermaid).to start_with("```mermaid\ngraph LR")
    expect(mermaid).to include("uses shared vpc")
  end
end
