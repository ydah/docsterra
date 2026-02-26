# frozen_string_literal: true

module Terradoc
  module Renderer
    class CostSection
      def initialize(items:)
        @items = Array(items)
      end

      def render
        return "コスト概算対象のリソースなし" if @items.empty?

        lines = [
          "| リソース | タイプ | スペック | リージョン | 備考 |",
          "|---|---|---|---|---|"
        ]
        @items.each do |item|
          lines << "| `#{item.resource_name}` | `#{item.resource_type}` | #{item.spec || '—'} | #{item.region || '—'} | #{item.note || '—'} |"
        end
        lines.join("\n")
      end
    end
  end
end
