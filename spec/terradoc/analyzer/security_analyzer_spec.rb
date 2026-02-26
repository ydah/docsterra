# frozen_string_literal: true

RSpec.describe Terradoc::Analyzer::SecurityAnalyzer do
  let(:parser) { Terradoc::Parser::HclParser.new }
  let(:registry) { Terradoc::Parser::ResourceRegistry.new }
  let(:resource_analyzer) { Terradoc::Analyzer::ResourceAnalyzer.new(registry: registry) }

  def load_resources(*relative_files)
    files = relative_files.map { |path| File.expand_path("../../fixtures/#{path}", __dir__) }
    parsed_files = files.each_with_object({}) { |file, result| result[file] = parser.parse_file(file) }
    project = Terradoc::Model::Project.new(name: "test", path: File.dirname(files.first), parsed_files: parsed_files)
    resource_analyzer.analyze(project)
    project.resources
  end

  it "extracts IAM and firewall data and emits warnings" do
    resources = load_resources("multi_product/shared/iam.tf", "multi_product/product-web/network.tf")

    report = described_class.new.analyze(resources)

    expect(report.iam_bindings.map { |item| item[:role] }).to include("roles/owner")
    expect(report.firewall_rules.map { |item| item[:rule_name] }).to include("web-allow-http")
    expect(report.warnings.join("\n")).to include("Open ingress firewall rule")
    expect(report.warnings.join("\n")).to include("Broad IAM role detected")
  end

  it "finds service account usage locations" do
    resources = load_resources("multi_product/product-web/main.tf")

    report = described_class.new.analyze(resources)

    service_account = report.service_accounts.find { |item| item[:account_id] == "sa-web" }
    expect(service_account).not_to be_nil
    expect(service_account[:used_by]).to include("google_cloud_run_service.api")
  end
end
