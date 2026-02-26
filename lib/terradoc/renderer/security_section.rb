# frozen_string_literal: true

module Terradoc
  module Renderer
    class SecuritySection
      def initialize(report:)
        @report = report
      end

      def render
        return "No security-related resources" unless @report

        [
          "#### IAM Bindings",
          "",
          render_iam_table,
          "",
          "#### Firewall Rules",
          "",
          render_firewall_table,
          "",
          "#### Service Accounts",
          "",
          render_service_account_table,
          "",
          "#### Security Notes",
          "",
          render_warnings
        ].join("\n")
      end

      private

      def render_iam_table
        return "No IAM bindings" if @report.iam_bindings.empty?

        lines = [
          "| Member | Role | Resource | Product |",
          "|---|---|---|---|"
        ]
        @report.iam_bindings.each do |binding|
          lines << "| `#{binding[:member]}` | `#{binding[:role]}` | `#{binding[:resource]}` | #{binding[:product]} |"
        end
        lines.join("\n")
      end

      def render_firewall_table
        return "No firewall rules" if @report.firewall_rules.empty?

        lines = [
          "| Rule Name | Direction | Action | Protocol/Port | Source | Target |",
          "|---|---|---|---|---|---|"
        ]
        @report.firewall_rules.each do |rule|
          lines << "| `#{rule[:rule_name]}` | #{rule[:direction]} | #{rule[:action]} | #{rule[:protocol_ports].join('<br/>')} | #{rule[:source]} | #{rule[:target]} |"
        end
        lines.join("\n")
      end

      def render_warnings
        return "No issues detected." if @report.warnings.empty?

        @report.warnings.map { |warning| "> ⚠️ #{warning}" }.join("\n")
      end

      def render_service_account_table
        return "No service accounts" if @report.service_accounts.empty?

        lines = [
          "| Account ID | Email | Display Name | Role | Used By |",
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
