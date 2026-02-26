# frozen_string_literal: true

RSpec.describe Terradoc do
  it "has a version number" do
    expect(Terradoc::VERSION).not_to be nil
  end

  it "generates markdown from terraform fixtures" do
    base = File.expand_path("fixtures/multi_product", __dir__)
    document = described_class.generate(
      File.join(base, "product-web"),
      File.join(base, "product-batch"),
      File.join(base, "shared"),
      sections: "resources,network,security,cost"
    )
    markdown = document.to_markdown

    expect(document).to be_a(Terradoc::Document)
    expect(markdown).to include("# インフラ設計書")
    expect(markdown).to include("## プロダクト間依存関係")
    expect(markdown).to include("### リソース一覧")
    expect(markdown).to include("```mermaid")
    expect(markdown).to include("### セキュリティ設定")
    expect(markdown).to include("### コスト概算情報")
  end

  it "returns dry-run summary counts" do
    base = File.expand_path("fixtures/multi_product", __dir__)
    summary = described_class.check(
      File.join(base, "product-web"),
      File.join(base, "product-batch"),
      File.join(base, "shared")
    )

    expect(summary[:project_count]).to eq(3)
    expect(summary[:resource_count]).to be >= 1
    expect(summary[:data_source_count]).to be >= 1
  end
end
