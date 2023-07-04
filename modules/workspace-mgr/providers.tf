terraform {
  required_version = ">= 1.0.5"
  required_providers {
    tfe = {
      source = "hashicorp/tfe"
      #version = "~>0.36.0"
      version = "~>0.41.0"
    }
  }
}