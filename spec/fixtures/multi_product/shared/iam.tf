resource "google_service_account" "shared" {
  account_id   = "sa-shared"
  display_name = "Shared Service Account"
}

resource "google_project_iam_member" "shared_owner" {
  project = "example-prod"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.shared.email}"
}
