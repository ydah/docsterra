resource "google_compute_network" "shared" {
  name                    = "shared-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "shared_app" {
  name          = "shared-app"
  ip_cidr_range = "10.10.0.0/24"
  region        = "asia-northeast1"
  network       = google_compute_network.shared.id
}
