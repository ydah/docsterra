# frozen_string_literal: true

require "tmpdir"

RSpec.describe Docsterra::Document do
  it "saves markdown to a file and exposes summary" do
    config = Docsterra::Config.new(output_path: "./tmp.md")
    project = Docsterra::Model::Project.new(name: "p", path: ".", parsed_files: {})
    project.resources = [
      Docsterra::Model::Resource.new(type: "google_compute_network", name: "vpc", attributes: {}, project: project)
    ]
    document = described_class.new(
      projects: [project],
      relationships: [],
      config: config,
      warnings: ["warn"],
      markdown: "# test\n"
    )

    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.md")
      document.save(path)
      expect(File.read(path)).to eq("# test\n")
    end

    expect(document.summary[:project_count]).to eq(1)
    expect(document.summary[:resource_count]).to eq(1)
    expect(document.summary[:warning_count]).to eq(1)
  end
end
