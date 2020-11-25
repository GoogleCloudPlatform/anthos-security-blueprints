/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = "grapesfrog-project"
  credentials = file("gp.json")
  region  = "us-central1"
  zone    = "us-central1-c"
  version = "~> 3.41"
}

  services = [
# Create a feed that sends notifications about GKE updates.
resource "google_cloud_asset_organization_feed" "organization_feed" {
  billing_project  = var.project_id
  org_id           = var.org_id
  feed_id          = var.name
  content_type     = "RESOURCE"

  asset_types = [
    "k8s.io/Namespace,container",
    "container.googleapis.com/Cluster",
  ]

  feed_output_config {
    pubsub_destination {
      topic = google_pubsub_topic.feed_output.id
    }
  }



  # Wait for the permission to be ready on the destination topic.
  depends_on = [
    google_pubsub_topic_iam_member.cloud_asset_writer,
  ]
}

# The topic where the resource change notifications will be sent.
resource "google_pubsub_topic" "feed_output" {
  project  = var.project_id
  name     = "gke-updates"
}

# Find the project number of the project whose identity will be used for sending
# the asset change notifications.
data "google_project" "project" {
  project_id = var.project_id
}

# Allow the publishing role to the Cloud Asset service account of the project that
# was used for sending the notifications.
resource "google_pubsub_topic_iam_member" "cloud_asset_writer" {
  project = var.project_id
  topic   = google_pubsub_topic.feed_output.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"
}



