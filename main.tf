provider "google" {
  project = "${var.project}"
  region = "${var.region}"
}

terraform {
  backend "gcs" {
    bucket  = "${var.project}-state"
    prefix  = "terraform/state"
  }
}

resource "google_storage_bucket" "static-site" {
  name          = "${host}"
  location      = "US"
  region        = "${region}"
  force_destroy = true

  storage_class = "STANDARD"

  bucket_policy_only = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["http://${host}"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_default_object_access_control" "public_rule" {
  bucket = "${google_storage_bucket.static-site.name}"
  role   = "READER"
  entity = "allUsers"
}

resource "google_storage_bucket_object" "index" {
  name   = "index.html"
  source = "/web/index.html"
  bucket = "${google_storage_bucket.static-site.name}"
}

resource "google_storage_bucket_object" "not_found" {
  name   = "404.html"
  source = "/web/404.html"
  bucket = "${google_storage_bucket.static-site.name}"
}