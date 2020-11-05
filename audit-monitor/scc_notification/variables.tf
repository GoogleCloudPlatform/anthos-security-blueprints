

variable "org_id" {
  description = "Organization id to create feed in"
  type        = string
}

variable "project_id" {
  type        = string
  description = "The project ID to manage the Pub/Sub resources"
}

variable "topic_name" {
  type        = string
  description = "The name for the Pub/Sub topic"
   default     = "scc-notification"
}

variable "topic_labels" {
  type        = map(string)
  description = "A map of labels to assign to the Pub/Sub topic"
  default     = {}
}
variable "name" {
  description = "Arbitrary string used to name created resources."
  type        = string
  default     = "scc-notification"
}
variable "scc_notification_filter" {
  description = "Filter used to SCC Notification, you can see more details how to create filters in https://cloud.google.com/security-command-center/docs/how-to-api-filter-notifications#create-filter"
  type        = string
  default     = "state=\\\"ACTIVE\\\""
}