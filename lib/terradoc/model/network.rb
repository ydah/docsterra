# frozen_string_literal: true

module Terradoc
  module Model
    class Network
      attr_reader :vpcs, :subnets, :firewall_rules, :load_balancers, :endpoints, :links

      def initialize(vpcs: [], subnets: [], firewall_rules: [], load_balancers: [], endpoints: [], links: [])
        @vpcs = vpcs
        @subnets = subnets
        @firewall_rules = firewall_rules
        @load_balancers = load_balancers
        @endpoints = endpoints
        @links = links
      end

      def empty?
        [vpcs, subnets, firewall_rules, load_balancers, endpoints].all?(&:empty?)
      end
    end
  end
end
