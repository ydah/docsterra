data "google_compute_network" "shared" {
  name = "shared-vpc"
}

resource "google_compute_firewall" "allow_http" {
  name          = "web-allow-http"
  network       = data.google_compute_network.shared.id
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}
