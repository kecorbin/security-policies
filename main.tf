terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "hashicorp-v2"
  }
}

variable "tfe_token" {}

variable "tfe_hostname" {
  description = "The domain where your TFE is hosted."
  default     = "app.terraform.io"
}

variable "tfe_organization" {
  description = "The TFE organization to apply your changes to."
  default     = "example_corp"
}

variable "self_name" {
  default = "sentinel_policies"
}

variable "use_case_name" {
  default = "ExampleTeam"
}

provider "tfe" {
  hostname = "${var.tfe_hostname}"
  token    = "${var.tfe_token}"
  version  = "~> 0.6"
}

data "tfe_workspace_ids" "all" {
  names        = ["*"]
  organization = "${var.tfe_organization}"
}

locals {
  workspaces = "${data.tfe_workspace_ids.all.external_ids}" # map of names to IDs
}

resource "tfe_policy_set" "global" {
  name         = "global"
  description  = "Policies that should be enforced on ALL infrastructure."
  organization = "${var.tfe_organization}"
  global       = true

  policy_ids = [
    "${tfe_sentinel_policy.passthrough.id}",
    "${tfe_sentinel_policy.aws-block-allow-all-cidr.id}",
    "${tfe_sentinel_policy.aws-restrict-instance-type-default.id}",
  ]
}

resource "tfe_policy_set" "production" {
  name         = "production"
  description  = "Policies that should be enforced on production infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.prod-change-window-hours.id}",
    "${tfe_sentinel_policy.aws-restrict-instance-type-prod.id}",
  ]

  //
  // workspace_external_ids = [
  //   "${local.workspaces["${var.use_case_name}-production"]}",
  // ]
}

resource "tfe_policy_set" "development" {
  name         = "development"
  description  = "Policies that should be enforced on development or scratch infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.aws-restrict-instance-type-dev.id}",
    "${tfe_sentinel_policy.allowed-working-hours.id}",
  ]

  // workspace_external_ids = [
  //   "${local.workspaces["${var.use_case_name}-development"]}",
  // ]
}

resource "tfe_policy_set" "staging" {
  name         = "staging"
  description  = "Policies that should be enforced on staging environments."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.aws-restrict-instance-type-stage.id}",
  ]

  // workspace_external_ids = [
  //   "${local.workspaces["${var.use_case_name}-staging"]}",
  // ]
}

resource "tfe_policy_set" "sentinel" {
  name         = "sentinel"
  description  = "Policies that watch the watchman. Enforced only on the workspace that manages policies."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.tfe_policies_only.id}",
  ]

  // workspace_external_ids = [
  //   "${local.workspaces["${var.self_name}"]}",
  // ]
}

# Test/experimental policies:

resource "tfe_sentinel_policy" "passthrough" {
  name         = "passthrough"
  description  = "Just passing through! Always returns 'true'."
  organization = "${var.tfe_organization}"
  policy       = "${file("./passthrough.sentinel")}"
  enforce_mode = "advisory"
}

# Sentinel management policies:

resource "tfe_sentinel_policy" "tfe_policies_only" {
  name         = "tfe_policies_only"
  description  = "The Terraform config that manages Sentinel policies must not use the authenticated tfe provider to manage non-Sentinel resources."
  organization = "${var.tfe_organization}"
  policy       = "${file("./tfe_policies_only.sentinel")}"
  enforce_mode = "hard-mandatory"
}

# Networking policies:

resource "tfe_sentinel_policy" "aws-block-allow-all-cidr" {
  name         = "aws-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (AWS version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "azurerm-block-allow-all-cidr" {
  name         = "azurerm-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (Azure version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./azurerm-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "gcp-block-allow-all-cidr" {
  name         = "gcp-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (GCP version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./gcp-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

# Compute instance policies:

resource "tfe_sentinel_policy" "aws-restrict-instance-type-dev" {
  name         = "aws-restrict-instance-type-dev"
  description  = "Limit AWS instances to approved list (for dev infrastructure)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-dev.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "aws-restrict-instance-type-stage" {
  name         = "aws-restrict-instance-type-stage"
  description  = "Limit AWS instances to approved list (for dev infrastructure)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-stage.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "aws-restrict-instance-type-prod" {
  name         = "aws-restrict-instance-type-prod"
  description  = "Limit AWS instances to approved list (for prod infrastructure)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-prod.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "aws-restrict-instance-type-default" {
  name         = "aws-restrict-instance-type-default"
  description  = "Limit AWS instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-default.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "aws-vpc-must-be-pmr-approved" {
  name         = "aws-vpc-must-be-pmr-approved"
  description  = "Limit AWS VPC creation to pre-approved modules"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-vpc-must-be-pmr-approved.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "azurerm-restrict-vm-size" {
  name         = "azurerm-restrict-vm-size"
  description  = "Limit Azure instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./azurerm-restrict-vm-size.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "gcp-restrict-machine-type" {
  name         = "gcp-restrict-machine-type"
  description  = "Limit GCP instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./gcp-restrict-machine-type.sentinel")}"
  enforce_mode = "soft-mandatory"
}

# General management policies
resource "tfe_sentinel_policy" "allowed-working-hours" {
  name         = "allowed-working-hours"
  description  = "Only allow TF applies during specific working hours"
  organization = "${var.tfe_organization}"
  policy       = "${file("./working-hours.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "prod-change-window-hours" {
  name         = "prod-change-window-hours"
  description  = "Only allow TF applies to prod environments during change window hours"
  organization = "${var.tfe_organization}"
  policy       = "${file("./change-window-hours.sentinel")}"
  enforce_mode = "hard-mandatory"
}
