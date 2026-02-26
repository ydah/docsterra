# frozen_string_literal: true

RSpec.describe Terradoc::Analyzer::CostAnalyzer do
  let(:parser) { Terradoc::Parser::HclParser.new }
  let(:registry) { Terradoc::Parser::ResourceRegistry.new }

  it "extracts cost-related specs from supported resources" do
    file = File.expand_path("../../fixtures/simple.tf", __dir__)
    project = Terradoc::Model::Project.new(
      name: "simple",
      path: File.dirname(file),
      parsed_files: { file => parser.parse_file(file) }
    )
    Terradoc::Analyzer::ResourceAnalyzer.new(registry: registry).analyze(project)

    items = described_class.new.analyze(project.resources)

    expect(items.size).to eq(1)
    expect(items.first.spec).to eq("e2-medium")
    expect(items.first.region).to eq("asia-northeast1-a")
  end
end
