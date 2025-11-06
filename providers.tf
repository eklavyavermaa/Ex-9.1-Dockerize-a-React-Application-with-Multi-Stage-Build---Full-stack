terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
  required_version = ">= 1.6.0"
}
provider "aws" {
  region = "ap-south-1"
}
