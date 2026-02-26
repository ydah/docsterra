# frozen_string_literal: true

RSpec.describe Terradoc::Renderer::SecuritySection do
  it "renders IAM, firewall, service accounts, and warnings sections" do
    report = Terradoc::Analyzer::SecurityAnalyzer::SecurityReport.new(
      iam_bindings: [
        { member: "serviceAccount:sa@example", role: "roles/viewer", resource: "project-x", product: "A" }
      ],
      firewall_rules: [
        {
          rule_name: "allow-http",
          direction: "INGRESS",
          action: "ALLOW",
          protocol_ports: ["tcp/80,443"],
          source: "0.0.0.0/0",
          target: "web"
        }
      ],
      service_accounts: [
        {
          account_id: "sa-web",
          email: "sa-web@example.iam.gserviceaccount.com",
          display_name: "Web SA",
          roles: ["roles/viewer"],
          used_by: ["google_cloud_run_service.api"]
        }
      ],
      warnings: ["Open ingress firewall rule detected"]
    )

    markdown = described_class.new(report: report).render

    expect(markdown).to include("#### IAM Bindings")
    expect(markdown).to include("#### Firewall Rules")
    expect(markdown).to include("#### Service Accounts")
    expect(markdown).to include("Used By")
    expect(markdown).to include("google_cloud_run_service.api")
    expect(markdown).to include("> ⚠️ Open ingress firewall rule detected")
  end
end
