resource "google_dns_managed_zone" "internal" {
  name     = "internal"
  dns_name = "internal.example.com."
}
