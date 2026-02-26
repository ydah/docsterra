# frozen_string_literal: true

RSpec.describe Terradoc::Renderer::MarkdownRenderer do
  let(:config) { Terradoc::Config.new(sections: %w[all]) }

  it "renders appendix sections including unresolved references" do
    project = Terradoc::Model::Project.new(name: "P", path: ".", parsed_files: {})
    resource = Terradoc::Model::Resource.new(
      type: "google_compute_subnetwork",
      name: "subnet",
      attributes: {},
      project: project,
      references: ["google_compute_network.missing.id"]
    )
    project.resources = [resource]
    project.network = Terradoc::Model::Network.new
    project.security_report = Terradoc::Analyzer::SecurityAnalyzer::SecurityReport.new(
      iam_bindings: [],
      firewall_rules: [],
      service_accounts: [],
      warnings: []
    )
    project.cost_items = []

    markdown = described_class.new(projects: [project], relationships: [], config: config).render

    expect(markdown).to include("Terraform ファイル数")
    expect(markdown).to include("### 未解決の参照一覧")
    expect(markdown).to include("google_compute_network.missing.id")
  end
end
