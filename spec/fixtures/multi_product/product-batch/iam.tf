resource "google_project_iam_member" "batch_editor" {
  project = "example-prod"
  role    = "roles/editor"
  member  = "serviceAccount:sa-shared@example-prod.iam.gserviceaccount.com"
}
