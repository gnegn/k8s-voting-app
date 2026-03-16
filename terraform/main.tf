terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-tfstate-vote-app"
    key            = "voting-eks/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-tfstate-vote-app-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Data sources ──────────────────────────────────────────────
data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC module ────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
  environment  = var.environment
}

# ── EKS module ────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment
}
