/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

terraform {
  required_version = ">= 1.2.1"

  required_providers {
    azurerm    = ">= 3.0.0, < 4.0.0"
    helm       = "2.5.0"
    kubernetes = "2.10.0"
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.15.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    local    = "2.2.2"
    template = "2.2.0"
  }
}