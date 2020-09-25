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

/******************************************
  Projects for log sinks
*****************************************/

module "org_audit_logs" {
  source                      = "terraform-google-modules/project-factory/google"
  version                     = "~> 8.0"
  random_project_id           = "true"
  impersonate_service_account = var.terraform_service_account
  default_service_account     = "depriviledge"
  name                        = "prj-c-logging"
  org_id                      = var.org_id
  billing_account             = var.billing_account
  folder_id                   = google_folder.common.id
  skip_gcloud_download        = var.skip_gcloud_download
  activate_apis               = ["logging.googleapis.com", "bigquery.googleapis.com", "billingbudgets.googleapis.com"]

  labels = {
    environment       = "production"
    application_name  = "org-logging"
    billing_code      = "1234"
    primary_contact   = "example1"
    secondary_contact = "example2"
    business_code     = "abcd"
    env_code          = "p"
  }
  budget_alert_pubsub_topic   = var.org_audit_logs_project_alert_pubsub_topic
  budget_alert_spent_percents = var.org_audit_logs_project_alert_spent_percents
  budget_amount               = var.org_audit_logs_project_budget_amount
}

module "org_billing_logs" {
  source                      = "terraform-google-modules/project-factory/google"
  version                     = "~> 8.0"
  random_project_id           = "true"
  impersonate_service_account = var.terraform_service_account
  default_service_account     = "depriviledge"
  name                        = "prj-c-billing-logs"
  org_id                      = var.org_id
  billing_account             = var.billing_account
  folder_id                   = google_folder.common.id
  skip_gcloud_download        = var.skip_gcloud_download
  activate_apis               = ["logging.googleapis.com", "bigquery.googleapis.com", "billingbudgets.googleapis.com"]

  labels = {
    environment       = "production"
    application_name  = "org-billing-logs"
    billing_code      = "1234"
    primary_contact   = "example1"
    secondary_contact = "example2"
    business_code     = "abcd"
    env_code          = "p"
  }
  budget_alert_pubsub_topic   = var.org_billing_logs_project_alert_pubsub_topic
  budget_alert_spent_percents = var.org_billing_logs_project_alert_spent_percents
  budget_amount               = var.org_billing_logs_project_budget_amount
}