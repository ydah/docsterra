# frozen_string_literal: true

RSpec.describe Docsterra::Parser::ModuleResolver do
  subject(:resolver) { described_class.new }

  let(:parser) { Docsterra::Parser::HclParser.new }
  let(:fixture_root) { File.expand_path("../../fixtures/modules/root", __dir__) }

  it "resolves and parses local modules" do
    ast = parser.parse_file(File.join(fixture_root, "main.tf"))
    module_block = ast.blocks.find { |block| block.type == "module" }

    result = resolver.resolve(project_path: fixture_root, module_block: module_block)

    expect(result[:type]).to eq(:local)
    expect(result[:source]).to eq("../child")
    expect(result[:parsed_files]).not_to be_empty

    parsed_ast = result[:parsed_files].values.first
    expect(parsed_ast.blocks.map(&:type)).to include("resource", "output")
  end

  it "resolves local modules relative to the module file location" do
    child_root = File.expand_path("../../fixtures/modules/child", __dir__)
    ast = parser.parse_file(File.join(child_root, "nested_module.tf"))
    module_block = ast.blocks.find { |block| block.type == "module" }

    result = resolver.resolve(project_path: fixture_root, module_block: module_block, base_path: child_root)

    expect(result[:type]).to eq(:local)
    expect(result[:absolute_path]).to end_with("/spec/fixtures/modules/grandchild")
    parsed_blocks = result[:parsed_files].values.flat_map(&:blocks)
    expect(parsed_blocks.map { |block| [block.type, block.labels&.first] }).to include(%w[resource google_pubsub_topic])
  end

  it "returns unresolved metadata for remote modules" do
    ast = parser.parse(<<~HCL)
      module "remote" {
        source = "terraform-google-modules/network/google"
      }
    HCL
    module_block = ast.blocks.first

    result = resolver.resolve(project_path: fixture_root, module_block: module_block)

    expect(result[:type]).to eq(:unresolved)
    expect(result[:source]).to eq("terraform-google-modules/network/google")
    expect(result[:reason]).to include("remote module source")
  end
end
