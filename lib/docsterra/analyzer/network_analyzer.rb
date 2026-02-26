# frozen_string_literal: true

module Docsterra
  module Analyzer
    class NetworkAnalyzer
      NETWORK_TYPES = %w[
        google_compute_network
        google_compute_subnetwork
        google_compute_firewall
        google_compute_global_address
        google_compute_address
        google_compute_forwarding_rule
        google_compute_global_forwarding_rule
        google_compute_router
        google_compute_router_nat
        google_dns_managed_zone
        google_dns_record_set
      ].freeze

      LOAD_BALANCER_TYPES = %w[
        google_compute_forwarding_rule
        google_compute_global_forwarding_rule
      ].freeze

      def analyze(resources)
        vpcs = resources.select { |resource| resource.type == "google_compute_network" }
        subnets = resources.select { |resource| resource.type == "google_compute_subnetwork" }
        firewalls = resources.select { |resource| resource.type == "google_compute_firewall" }
        load_balancers = resources.select { |resource| LOAD_BALANCER_TYPES.include?(resource.type) }
        endpoints = resources.reject { |resource| NETWORK_TYPES.include?(resource.type) }
        links = build_links(resources, vpcs)

        Model::Network.new(
          vpcs: vpcs,
          subnets: subnets,
          firewall_rules: firewalls,
          load_balancers: load_balancers,
          endpoints: endpoints,
          links: links
        )
      end

      private

      def build_links(resources, vpcs)
        vpc_lookup = vpcs.each_with_object({}) do |vpc, index|
          index[vpc.identifier] = vpc
        end

        resources.flat_map do |resource|
          refs = Array(resource.references)
          refs.filter_map do |ref|
            target = target_from_reference(ref, vpc_lookup)
            next unless target

            {
              source: resource,
              target: target,
              type: :network,
              detail: "references #{ref}"
            }
          end
        end.uniq
      end

      def target_from_reference(ref, vpc_lookup)
        return nil unless ref

        # ex: google_compute_network.shared.id -> google_compute_network.shared
        parts = ref.split(".")
        return nil if parts.length < 2

        identifier = parts[0, 2].join(".")
        vpc_lookup[identifier]
      end
    end
  end
end
