# frozen_string_literal: true

RSpec.describe Docsterra::Model::Project do
  let(:parser) { Docsterra::Parser::HclParser.new }

  it "extracts terraform blocks by kind from parsed files" do
    fixture = File.expand_path("../../fixtures/variables.tf", __dir__)
    parsed_files = { fixture => parser.parse_file(fixture) }

    project = described_class.new(name: "variables", path: File.dirname(fixture), parsed_files: parsed_files)

    expect(project.variables.size).to eq(1)
    expect(project.locals.size).to eq(1)
    expect(project.outputs.size).to eq(1)
    expect(project.resource_blocks).to be_empty
  end
end
