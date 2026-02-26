# frozen_string_literal: true

module Terradoc
  module Analyzer
    class SecurityAnalyzer
      SecurityReport = Struct.new(
        :iam_bindings,
        :firewall_rules,
        :service_accounts,
        :warnings,
        keyword_init: true
      )

      BROAD_ROLES = %w[roles/owner roles/editor].freeze

      def analyze(resources)
        iam_bindings = extract_iam_bindings(resources)
        firewall_rules = extract_firewall_rules(resources)
        service_accounts = extract_service_accounts(resources, iam_bindings)
        warnings = []
        warnings.concat(detect_firewall_warnings(firewall_rules))
        warnings.concat(detect_iam_warnings(iam_bindings))
        warnings.concat(detect_service_account_warnings(resources))
        warnings.concat(detect_bucket_warnings(resources))

        SecurityReport.new(
          iam_bindings: iam_bindings,
          firewall_rules: firewall_rules,
          service_accounts: service_accounts,
          warnings: warnings.uniq
        )
      end

      private

      def extract_iam_bindings(resources)
        resources.filter { |resource| resource.type.match?(/_iam_(member|binding|policy)\z/) }.flat_map do |resource|
          role = resource.attribute_text("role")
          scope = resource.attribute_text("project") ||
                  resource.attribute_text("bucket") ||
                  resource.attribute_text("dataset_id") ||
                  resource.name
          members = if resource.type.end_with?("_binding")
                      Array(resource.attribute_ruby("members")).map(&:to_s)
                    else
                      [resource.attribute_text("member")].compact
                    end

          members.map do |member|
            {
              member: member,
              role: role,
              resource: scope,
              product: resource.project.name,
              source_resource: resource
            }
          end
        end
      end

      def extract_firewall_rules(resources)
        resources.filter { |resource| resource.type == "google_compute_firewall" }.map do |resource|
          allows = Array(resource.attribute_ruby("allow"))
          denies = Array(resource.attribute_ruby("deny"))
          action = allows.empty? ? "deny" : "allow"
          rules = allows.empty? ? denies : allows
          protocol_ports = rules.map do |rule|
            protocol = rule["protocol"] || "all"
            ports = Array(rule["ports"]).compact
            ports.empty? ? protocol : "#{protocol}/#{ports.join(',')}"
          end

          {
            rule_name: resource.attribute_text("name") || resource.name,
            direction: resource.attribute_text("direction") || "INGRESS",
            action: action.upcase,
            protocol_ports: protocol_ports.empty? ? ["all"] : protocol_ports,
            source: Array(resource.attribute_ruby("source_ranges")).join(", "),
            target: Array(resource.attribute_ruby("target_tags")).join(", "),
            resource: resource
          }
        end
      end

      def extract_service_accounts(resources, iam_bindings)
        resources.filter { |resource| resource.type == "google_service_account" }.map do |resource|
          account_id = resource.attribute_text("account_id") || resource.name
          email = resource.attribute_text("email") || "#{account_id}@unknown.iam.gserviceaccount.com"
          roles = iam_bindings.select { |binding| binding[:member].to_s.include?(account_id) || binding[:member].to_s.include?(email) }
                              .map { |binding| binding[:role] }
                              .compact
                              .uniq
          used_by = resources.reject { |candidate| candidate == resource }.filter_map do |candidate|
            next unless resource_uses_service_account?(candidate, service_account: resource, account_id: account_id, email: email)

            candidate.identifier
          end.uniq

          {
            account_id: account_id,
            email: email,
            display_name: resource.attribute_text("display_name"),
            roles: roles,
            used_by: used_by,
            resource: resource
          }
        end
      end

      def detect_firewall_warnings(firewall_rules)
        firewall_rules.filter_map do |rule|
          next unless rule[:direction].to_s.upcase == "INGRESS"
          next unless rule[:source].to_s.include?("0.0.0.0/0")

          "Open ingress firewall rule detected: #{rule[:rule_name]} (0.0.0.0/0)"
        end
      end

      def detect_iam_warnings(iam_bindings)
        iam_bindings.filter_map do |binding|
          next unless BROAD_ROLES.include?(binding[:role])

          "Broad IAM role detected: #{binding[:role]} for #{binding[:member]}"
        end
      end

      def detect_service_account_warnings(resources)
        resources.flat_map do |resource|
          flattened_texts(resource.attributes).filter_map do |text|
            next unless text.match?(/-compute@developer\.gserviceaccount\.com/)

            "Default Compute Engine service account usage detected in #{resource.identifier}"
          end
        end
      end

      def detect_bucket_warnings(resources)
        resources.filter { |resource| resource.type == "google_storage_bucket" }.filter_map do |bucket|
          next if bucket.attribute("uniform_bucket_level_access")

          "Bucket #{bucket.attribute_text('name') || bucket.name} is missing uniform_bucket_level_access configuration"
        end
      end

      def flattened_texts(value)
        case value
        when Hash
          value.values.flat_map { |child| flattened_texts(child) }
        when Array
          value.flat_map { |child| flattened_texts(child) }
        else
          [Parser::ExpressionInspector.to_text(value)]
        end.compact
      end

      def resource_uses_service_account?(resource, service_account:, account_id:, email:)
        patterns = [
          account_id.to_s,
          email.to_s,
          service_account.identifier,
          "#{service_account.identifier}.email"
        ].reject(&:empty?)

        flattened_texts(resource.attributes).any? do |text|
          next false if text.nil?

          patterns.any? { |pattern| text.include?(pattern) }
        end
      end
    end
  end
end
