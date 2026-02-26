# frozen_string_literal: true

RSpec.describe Docsterra::Analyzer::DependencyAnalyzer do
  let(:parser) { Docsterra::Parser::HclParser.new }
  let(:registry) { Docsterra::Parser::ResourceRegistry.new }
  let(:resource_analyzer) { Docsterra::Analyzer::ResourceAnalyzer.new(registry: registry) }

  def build_project(root_path, name:, shared: false)
    tf_files = Dir.glob(File.join(root_path, "*.tf")).sort
    parsed_files = tf_files.each_with_object({}) { |file, result| result[file] = parser.parse_file(file) }
    project = Docsterra::Model::Project.new(name: name, path: root_path, parsed_files: parsed_files, shared: shared)
    resource_analyzer.analyze(project)
    project
  end

  it "detects cross-project dependencies from data sources and shared service accounts" do
    base = File.expand_path("../../fixtures/multi_product", __dir__)
    projects = [
      build_project(File.join(base, "product-web"), name: "Product Web"),
      build_project(File.join(base, "product-batch"), name: "Product Batch"),
      build_project(File.join(base, "shared"), name: "Shared", shared: true)
    ]

    relationships = described_class.new.analyze(projects)

    details = relationships.map(&:detail).join("\n")
    expect(details).to include("Data source")
    expect(details).to include("IAM member uses service account")
    expect(details).to include("shared-vpc")
    expect(relationships.map(&:type)).to include(:shared_resource, :iam)
  end
end
