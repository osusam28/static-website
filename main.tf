provider "google" {
  project = var.project
  region = var.region
}

provider "google-beta" {
  project = var.project
  region = var.region
}

terraform {
  backend "gcs" {
    bucket  = "web-sandbox-sch-state"
    prefix  = "terraform/state"
  }
}

resource "google_storage_bucket" "static-site" {
  name          = var.host
  location      = "US"
  force_destroy = true

  storage_class = "STANDARD"

  bucket_policy_only = false

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["http://${var.host}"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.static-site.name
  role = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_object" "index" {
  name   = "index.html"
  source = "${path.module}/web/index.html"
  bucket = "${google_storage_bucket.static-site.name}"
}

resource "google_storage_bucket_object" "not_found" {
  name   = "404.html"
  source = "${path.module}/web/404.html"
  bucket = "${google_storage_bucket.static-site.name}"
}

resource "google_storage_bucket_object" "redirect" {
  name   = "redirect.html"
  source = "${path.module}/web/redirect.html"
  bucket = "${google_storage_bucket.static-site.name}"
}

resource "google_storage_object_access_control" "redirect_rule" {
  object = google_storage_bucket_object.redirect.output_name
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "user:osusam28@gmail.com"
}

resource "google_storage_object_access_control" "public_rule" {
  object = google_storage_bucket_object.not_found.output_name
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_storage_object_access_control" "index_rule" {
  object = google_storage_bucket_object.index.output_name
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "allUsers"
}

# NETWORKING

resource "google_compute_backend_bucket" "static_backend" {
  name        = "static-backend-bucket"
  bucket_name = google_storage_bucket.static-site.name
  enable_cdn  = true
}

resource "google_compute_global_address" "static_ip" {
  name = "static-web-ip"
  address_type = "EXTERNAL"
}

resource "google_compute_url_map" "urlmap" {
  name        = "static-lb"
  default_service = google_compute_backend_bucket.static_backend.id
}

resource "google_compute_target_https_proxy" "https_proxy" {
  provider = google-beta

  name    = "static-content-proxy"
  url_map = google_compute_url_map.urlmap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  provider = google-beta

  name = "static-content-cert"

  managed {
    domains = ["datalake.site", "www.datalake.site"]
  }
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "static-content-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"

  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.static_ip.address
}