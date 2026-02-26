# frozen_string_literal: true

module Terradoc
  module Renderer
    class SecuritySection
      def initialize(report:)
        @report = report
      end

      def render
        return "セキュリティ関連リソースなし" unless @report

        [
          "#### IAMバインディング一覧",
          "",
          render_iam_table,
          "",
          "#### ファイアウォールルール一覧",
          "",
          render_firewall_table,
          "",
          "#### セキュリティ注意事項",
          "",
          render_warnings
        ].join("\n")
      end

      private

      def render_iam_table
        return "IAMバインディングなし" if @report.iam_bindings.empty?

        lines = [
          "| メンバー | ロール | リソース | プロダクト |",
          "|---|---|---|---|"
        ]
        @report.iam_bindings.each do |binding|
          lines << "| `#{binding[:member]}` | `#{binding[:role]}` | `#{binding[:resource]}` | #{binding[:product]} |"
        end
        lines.join("\n")
      end

      def render_firewall_table
        return "ファイアウォールルールなし" if @report.firewall_rules.empty?

        lines = [
          "| ルール名 | 方向 | アクション | プロトコル/ポート | ソース | ターゲット |",
          "|---|---|---|---|---|---|"
        ]
        @report.firewall_rules.each do |rule|
          lines << "| `#{rule[:rule_name]}` | #{rule[:direction]} | #{rule[:action]} | #{rule[:protocol_ports].join('<br/>')} | #{rule[:source]} | #{rule[:target]} |"
        end
        lines.join("\n")
      end

      def render_warnings
        return "問題は検出されませんでした。" if @report.warnings.empty?

        @report.warnings.map { |warning| "> ⚠️ #{warning}" }.join("\n")
      end
    end
  end
end
