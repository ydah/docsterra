# frozen_string_literal: true

RSpec.describe "Local module recursion integration" do
  it "includes resources from nested local modules in generated output" do
    root = File.expand_path("../../fixtures/modules/root", __dir__)

    document = Terradoc.generate(root, sections: "resources")
    markdown = document.to_markdown

    expect(markdown).to include("google_storage_bucket")
    expect(markdown).to include("google_pubsub_topic")
    expect(markdown).to include("nested")
  end
end
