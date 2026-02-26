# frozen_string_literal: true

RSpec.describe Docsterra::Renderer::MermaidDiagram do
  let(:parser) { Docsterra::Parser::HclParser.new }
  let(:registry) { Docsterra::Parser::ResourceRegistry.new }
  let(:resource_analyzer) { Docsterra::Analyzer::ResourceAnalyzer.new(registry: registry) }

  it "renders a network mermaid diagram" do
    file = File.expand_path("../../fixtures/network.tf", __dir__)
    project = Docsterra::Model::Project.new(name: "network", path: File.dirname(file), parsed_files: { file => parser.parse_file(file) })
    resource_analyzer.analyze(project)
    project.network = Docsterra::Analyzer::NetworkAnalyzer.new.analyze(project.resources)

    mermaid = described_class.new.render_network(project.network, project_name: project.name)

    expect(mermaid).to start_with("```mermaid\ngraph TB")
    expect(mermaid).to include("subgraph")
  end

  it "renders cross-project dependency mermaid diagram" do
    project_a = Docsterra::Model::Project.new(name: "A", path: ".", parsed_files: {})
    project_b = Docsterra::Model::Project.new(name: "B", path: ".", parsed_files: {})
    res_a = Docsterra::Model::Resource.new(type: "google_cloud_run_service", name: "api", attributes: {}, project: project_a)
    res_b = Docsterra::Model::Resource.new(type: "google_compute_network", name: "vpc", attributes: {}, project: project_b, category: :networking)
    project_a.resources = [res_a]
    project_b.resources = [res_b]
    relationship = Docsterra::Model::Relationship.new(source: res_a, target: res_b, type: :network, detail: "uses shared vpc")

    mermaid = described_class.new.render_project_relationships(projects: [project_a, project_b], relationships: [relationship])

    expect(mermaid).to start_with("```mermaid\ngraph LR")
    expect(mermaid).to include("uses shared vpc")
  end
end
