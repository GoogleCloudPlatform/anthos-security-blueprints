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


locals {
  role_id   = "projects/${var.project_id}/roles/${local.role_name}"
  role_name = "feeds_cf"
}

module "project" {
  source         = "../../modules/project"
  name           = var.project_id
  project_create = var.project_create
  services = [
    "cloudasset.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
  service_config = {
    disable_on_destroy         = false,
    disable_dependent_services = false
  }
  custom_roles = {
    (local.role_name) = [
      "container.clusters.list",
      "container.clusterRoles.list",
      "resourcemanager.projects.list"
    ]
  }
  iam_roles = [local.role_id]
  iam_members = {
    (local.role_id) = [module.service-account.iam_email]
  }
}

module "pubsub" {
  source        = "../../modules/pubsub"
  project_id    = module.project.project_id
  name          = var.name
  subscriptions = { "${var.name}-default" = null }
  iam_roles = [
    "roles/pubsub.publisher"
  ]
  iam_members = {
    "roles/pubsub.publisher" = [
      "serviceAccount:${module.project.service_accounts.robots.cloudasset}"
    ]
  }
}

module "service-account" {
  source     = "../../modules/iam-service-accounts"
  project_id = module.project.project_id
  names      = ["${var.name}-cfg"]
 # iam_project_roles = { (module.project.project_id) = [local.role_id] }
}

