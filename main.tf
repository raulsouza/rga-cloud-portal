# Required providers and backend configuration (replace with your specifics)
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "rga-tf-state-bucket"
    prefix = "terraform/state-portal"
  }
}

provider "google" {
  project = "sacred-veld-441410-f8"  # Replace with your GCP project ID
  region  = "us-central1"            # Choose your preferred region
  zone    = "us-central1-a"          # Choose your preferred zone
}

# Cloud Storage bucket for website hosting
resource "google_storage_bucket" "website_bucket" {
  name                        = "kr3k-portal"  # Replace with a unique bucket name
  location                    = "US"                               # Choose your preferred location
  force_destroy               = true                               # Allows Terraform to delete bucket contents when deleting the bucket
  website {
    main_page_suffix          = "index.html"
    not_found_page            = "error.html"
  }
}

###### upload files ########
# List all files in the portal-files directory
locals {
  portal_files = fileset("portal-files", "**")  # Adjust path to your directory containing files
}

# Upload all files in the portal-files directory to the bucket
resource "google_storage_bucket_object" "portal_files" {
  for_each    = local.portal_files
  name        = each.value                       # Uses the relative file path within the directory as the object name
  bucket      = google_storage_bucket.website_bucket.name
  source      = "portal-files/${each.value}"  # Path to each file in the portal-files directory
  # Specify the correct MIME type based on file extension
  content_type = lookup(
    {
      "html" = "text/html"
      "css"  = "text/css"
      "js"   = "application/javascript"
      "png"  = "image/png"
      "jpg"  = "image/jpeg"
      "jpeg" = "image/jpeg"
      "gif"  = "image/gif"
    },
    split(".", each.value)[length(split(".", each.value)) - 1],  # Extract file extension
    "application/octet-stream"  # Default if file extension is not matched
  )
}


# Grant public access to the bucket
resource "google_storage_bucket_iam_member" "public_access" {
  bucket = google_storage_bucket.website_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Backend bucket configuration for the load balancer
resource "google_compute_backend_bucket" "website_backend" {
  name   = "website-backend"
  bucket_name = google_storage_bucket.website_bucket.name
  enable_cdn = true
}

# URL Map to route all requests to the backend bucket
resource "google_compute_url_map" "website_url_map" {
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website_backend.self_link
}

# HTTP Proxy to route requests based on the URL map
resource "google_compute_target_http_proxy" "website_http_proxy" {
  name    = "website-http-proxy"
  url_map = google_compute_url_map.website_url_map.self_link
}

# Global forwarding rule to direct HTTP traffic to the proxy
resource "google_compute_global_forwarding_rule" "website_forwarding_rule" {
  name        = "website-forwarding-rule"
  target      = google_compute_target_http_proxy.website_http_proxy.self_link
  port_range  = "80"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"

  # Reserve a global IP for the load balancer
  ip_address = google_compute_global_address.website_ip.address
}

# Reserve a global IP for the load balancer
resource "google_compute_global_address" "website_ip" {
  name = "website-lb-ip"
}

# Outputs the load balancer IP
output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.website_forwarding_rule.ip_address
}
