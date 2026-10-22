terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Mesmo bucket do oficina-infra-k8s, outra key. O nome do bucket chega no init:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "infra-db/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
