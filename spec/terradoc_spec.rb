# frozen_string_literal: true

RSpec.describe Terradoc do
  it "has a version number" do
    expect(Terradoc::VERSION).not_to be nil
  end

  it "returns markdown from generate" do
    markdown = described_class.generate("./terraform")

    expect(markdown).to include("# Infrastructure Design Document")
    expect(markdown).to include("Paths: ./terraform")
  end
end
