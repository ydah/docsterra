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
          "#### サービスアカウント一覧",
          "",
          render_service_account_table,
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

      def render_service_account_table
        return "サービスアカウントなし" if @report.service_accounts.empty?

        lines = [
          "| アカウントID | メール | 表示名 | ロール | 使用箇所 |",
          "|---|---|---|---|---|"
        ]
        @report.service_accounts.each do |account|
          roles = account[:roles].empty? ? "—" : account[:roles].join("<br/>")
          used_by = Array(account[:used_by]).empty? ? "—" : Array(account[:used_by]).map { |item| "`#{item}`" }.join("<br/>")
          lines << "| `#{account[:account_id]}` | `#{account[:email]}` | #{account[:display_name] || '—'} | #{roles} | #{used_by} |"
        end
        lines.join("\n")
      end
    end
  end
end
