variable "profile" {
  default = "default"
}

variable "region" {
  default = "cn-hangzhou"
}

provider "alicloud" {
  region  = var.region
  profile = var.profile
}

data "alicloud_emr_main_versions" "default" {
  cluster_type = ["DRUID"]
}

data "alicloud_vpcs" "default" {
  is_default = true
}
variable "name" {
  default = "terraform_test_001"
}
resource "alicloud_vpc" "default" {
  count = length(data.alicloud_vpcs.default.ids) > 0 ? 0 : 1
  vpc_name = var.name
  cidr_block = "172.16.0.0/12"
}
resource "alicloud_vswitch" "default" {
  count             = length(data.alicloud_vswitches.default.ids) > 0 ? 0 : 1
  vpc_id            = data.alicloud_vpcs.default.ids.0
  zone_id           = "cn-hangzhou-h"
  cidr_block        = cidrsubnet(data.alicloud_vpcs.default.vpcs.0.cidr_block, 4, 15)
}

data "alicloud_vswitches" "default" {
  zone_id = "cn-hangzhou-g"
  vpc_id = data.alicloud_vpcs.default.ids.0
}

module "security_group" {
  region  = var.region
  profile = var.profile
  source  = "alibaba/security-group/alicloud"
  vpc_id  = length(data.alicloud_vpcs.default.ids) > 0 ? data.alicloud_vpcs.default.ids.0 : concat(alicloud_vpc.default.*.id, [""])[0]
  version = "~> 2.0"
}

module "emr-druid" {
  source = "../.."

  create = true

  emr_version = data.alicloud_emr_main_versions.default.main_versions.0.emr_version
  charge_type = "PostPaid"

  vswitch_id                  = length(data.alicloud_vswitches.default.ids) > 0 ? data.alicloud_vswitches.default.ids.0 : concat(alicloud_vswitch.default.*.id, [""])[0]
  security_group_id = module.security_group.this_security_group_id

  high_availability_enable = true
  is_open_public_ip        = true
  ssh_enable               = true
  master_pwd               = "YourPassword123!"
}