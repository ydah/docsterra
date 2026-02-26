# frozen_string_literal: true

RSpec.describe Docsterra::Renderer::MarkdownRenderer do
  let(:config) { Docsterra::Config.new(sections: %w[all]) }

  it "renders appendix sections including unresolved references" do
    project = Docsterra::Model::Project.new(name: "P", path: ".", parsed_files: {})
    resource = Docsterra::Model::Resource.new(
      type: "google_compute_subnetwork",
      name: "subnet",
      attributes: {},
      project: project,
      references: ["google_compute_network.missing.id"]
    )
    project.resources = [resource]
    project.network = Docsterra::Model::Network.new
    project.security_report = Docsterra::Analyzer::SecurityAnalyzer::SecurityReport.new(
      iam_bindings: [],
      firewall_rules: [],
      service_accounts: [],
      warnings: []
    )
    project.cost_items = []

    markdown = described_class.new(projects: [project], relationships: [], config: config).render

    expect(markdown).to include("Terraform file count")
    expect(markdown).to include("### Unresolved References")
    expect(markdown).to include("google_compute_network.missing.id")
  end

  it "renders consumer list for shared projects" do
    shared = Docsterra::Model::Project.new(name: "Shared", path: ".", parsed_files: {}, shared: true)
    app = Docsterra::Model::Project.new(name: "App", path: ".", parsed_files: {})

    shared_resource = Docsterra::Model::Resource.new(
      type: "google_compute_network",
      name: "shared",
      attributes: {},
      project: shared,
      category: :networking
    )
    app_resource = Docsterra::Model::Resource.new(
      type: "google_compute_subnetwork",
      name: "app",
      attributes: {},
      project: app,
      category: :networking
    )

    shared.resources = [shared_resource]
    app.resources = [app_resource]
    [shared, app].each do |project|
      project.network = Docsterra::Model::Network.new
      project.security_report = Docsterra::Analyzer::SecurityAnalyzer::SecurityReport.new(
        iam_bindings: [],
        firewall_rules: [],
        service_accounts: [],
        warnings: []
      )
      project.cost_items = []
    end

    relationships = [
      Docsterra::Model::Relationship.new(
        source: app_resource,
        target: shared_resource,
        type: :shared_resource,
        detail: "Reference google_compute_network.shared.id"
      )
    ]

    markdown = described_class.new(projects: [app, shared], relationships: relationships, config: config).render

    expect(markdown).to include("## Shared")
    expect(markdown).to include("### Consumer Products")
    expect(markdown).to include("- App")
  end
end
