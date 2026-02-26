resource "google_container_cluster" "batch" {
  name               = "batch-cluster"
  location           = "asia-northeast1"
  initial_node_count = 1
  network            = "shared-vpc"

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
  }
}

resource "google_pubsub_topic" "jobs" {
  name = "batch-jobs"
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id = "analytics"
  location   = "asia-northeast1"
}
