# Create new storage bucket in the US
# location with Standard Storage

resource "google_storage_bucket" "static" {
 name          = "dti-setup-bucket"
 project       = "project-e3084c6b-6549-46b3-87a" #need to setup auto get project id for this
 location      = "asia-southeast1"
 storage_class = "STANDARD"

 uniform_bucket_level_access = true
}

# Upload a text file as an object
# to the storage bucket

resource "google_storage_bucket_object" "default" {
 name         = "sample.txt"
 source       = "./sample.txt"
 content_type = "text/plain"
 bucket       = google_storage_bucket.static.id
}