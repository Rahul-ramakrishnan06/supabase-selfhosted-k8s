terraform {
  required_version = ">= 1.5"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.5"
    }
  }

  # Local backend for local/DC use (no S3 like the cloud playbook).
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "kind" {}
