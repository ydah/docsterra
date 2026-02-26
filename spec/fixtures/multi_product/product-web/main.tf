resource "google_cloud_run_service" "api" {
  name     = "web-api"
  location = "asia-northeast1"

  template {
    spec {
      service_account_name = google_service_account.web.email
      containers {
        image = "asia-northeast1-docker.pkg.dev/example/web-api:latest"
      }
    }
  }
}

resource "google_service_account" "web" {
  account_id   = "sa-web"
  display_name = "Web Service Account"
}

resource "google_project_iam_member" "web_sql_client" {
  project = "example-prod"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.web.email}"
}
