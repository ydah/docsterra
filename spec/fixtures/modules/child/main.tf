resource "google_storage_bucket" "data" {
  name          = "child-module-bucket"
  location      = "ASIA-NORTHEAST1"
  storage_class = "STANDARD"
}

output "bucket_name" {
  value = google_storage_bucket.data.name
}
