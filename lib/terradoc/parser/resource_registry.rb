# frozen_string_literal: true

module Terradoc
  module Parser
    class ResourceRegistry
      DEFAULTS = {
        "google_compute_instance" => {
          display_name: "Compute Engine Instance",
          category: :compute,
          key_attributes: %w[machine_type zone boot_disk.initialize_params.image]
        },
        "google_compute_network" => {
          display_name: "VPC Network",
          category: :networking,
          key_attributes: %w[name auto_create_subnetworks routing_mode]
        },
        "google_compute_subnetwork" => {
          display_name: "Subnetwork",
          category: :networking,
          key_attributes: %w[name ip_cidr_range region network]
        },
        "google_compute_firewall" => {
          display_name: "Firewall Rule",
          category: :networking,
          key_attributes: %w[name direction source_ranges target_tags]
        },
        "google_container_cluster" => {
          display_name: "GKE Cluster",
          category: :compute,
          key_attributes: %w[name location initial_node_count node_config.machine_type]
        },
        "google_container_node_pool" => {
          display_name: "GKE Node Pool",
          category: :compute,
          key_attributes: %w[name node_count node_config.machine_type node_config.disk_size_gb]
        },
        "google_cloud_run_service" => {
          display_name: "Cloud Run Service",
          category: :compute,
          key_attributes: %w[name location template.spec.containers.image]
        },
        "google_cloudfunctions_function" => {
          display_name: "Cloud Function",
          category: :compute,
          key_attributes: %w[name runtime entry_point trigger_http]
        },
        "google_sql_database_instance" => {
          display_name: "Cloud SQL Instance",
          category: :database,
          key_attributes: %w[name database_version settings.tier region]
        },
        "google_storage_bucket" => {
          display_name: "Cloud Storage Bucket",
          category: :storage,
          key_attributes: %w[name location storage_class]
        },
        "google_pubsub_topic" => {
          display_name: "Pub/Sub Topic",
          category: :messaging,
          key_attributes: %w[name message_retention_duration]
        },
        "google_pubsub_subscription" => {
          display_name: "Pub/Sub Subscription",
          category: :messaging,
          key_attributes: %w[name ack_deadline_seconds topic]
        },
        "google_bigquery_dataset" => {
          display_name: "BigQuery Dataset",
          category: :analytics,
          key_attributes: %w[dataset_id location default_table_expiration_ms]
        },
        "google_bigquery_table" => {
          display_name: "BigQuery Table",
          category: :analytics,
          key_attributes: %w[dataset_id table_id schema]
        },
        "google_project_iam_member" => {
          display_name: "Project IAM Member",
          category: :iam,
          key_attributes: %w[project role member]
        },
        "google_project_iam_binding" => {
          display_name: "Project IAM Binding",
          category: :iam,
          key_attributes: %w[project role members]
        },
        "google_service_account" => {
          display_name: "Service Account",
          category: :iam,
          key_attributes: %w[account_id display_name email]
        },
        "google_project_service" => {
          display_name: "Project Service API",
          category: :platform,
          key_attributes: %w[project service]
        },
        "google_compute_address" => {
          display_name: "Static IP Address",
          category: :networking,
          key_attributes: %w[name region address]
        },
        "google_compute_global_address" => {
          display_name: "Global Static IP",
          category: :networking,
          key_attributes: %w[name address]
        },
        "google_compute_forwarding_rule" => {
          display_name: "Forwarding Rule",
          category: :networking,
          key_attributes: %w[name region network target ip_address]
        },
        "google_compute_global_forwarding_rule" => {
          display_name: "Global Forwarding Rule",
          category: :networking,
          key_attributes: %w[name target ip_address]
        },
        "google_compute_router" => {
          display_name: "Cloud Router",
          category: :networking,
          key_attributes: %w[name region network]
        },
        "google_compute_router_nat" => {
          display_name: "Cloud NAT",
          category: :networking,
          key_attributes: %w[name router region source_subnetwork_ip_ranges_to_nat]
        },
        "google_dns_managed_zone" => {
          display_name: "Cloud DNS Zone",
          category: :networking,
          key_attributes: %w[name dns_name visibility]
        },
        "google_dns_record_set" => {
          display_name: "Cloud DNS Record",
          category: :networking,
          key_attributes: %w[name managed_zone type ttl]
        },
        "google_redis_instance" => {
          display_name: "Memorystore Redis",
          category: :database,
          key_attributes: %w[name region tier memory_size_gb]
        },
        "google_compute_disk" => {
          display_name: "Persistent Disk",
          category: :storage,
          key_attributes: %w[name size type zone]
        }
      }.freeze

      def initialize(custom_attributes: {})
        @definitions = deep_copy(DEFAULTS)
        apply_custom_attributes(custom_attributes)
      end

      def definition_for(resource_type)
        @definitions.fetch(resource_type.to_s, default_definition(resource_type))
      end

      def key_attributes_for(resource_type)
        Array(definition_for(resource_type)[:key_attributes])
      end

      def display_name_for(resource_type)
        definition_for(resource_type)[:display_name]
      end

      def category_for(resource_type)
        definition_for(resource_type)[:category]
      end

      private

      def apply_custom_attributes(custom_attributes)
        custom_attributes.to_h.each do |resource_type, attributes|
          next unless attributes

          current = @definitions[resource_type.to_s] || default_definition(resource_type)
          @definitions[resource_type.to_s] = current.merge(
            key_attributes: Array(attributes).map(&:to_s)
          )
        end
      end

      def default_definition(resource_type)
        {
          display_name: resource_type.to_s,
          category: :other,
          key_attributes: []
        }
      end

      def deep_copy(hash)
        hash.each_with_object({}) do |(key, value), copied|
          copied[key] = value.dup
        end
      end
    end
  end
end
