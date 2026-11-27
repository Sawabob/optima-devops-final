terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_region" {
  description = "Region for the state bucket and deployment permissions."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = { Project = "optima-devops-final" }
  }
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

locals {
  project     = "optima-devops-final"
  ec2_arn     = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}"
  project_tag = { "aws:ResourceTag/Project" = local.project }
}

resource "aws_s3_bucket" "state" {
  bucket_prefix = "optima-devops-final-state-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_user" "ci" {
  name = "optima-devops-final-ci"
}

resource "aws_iam_policy" "ci" {
  name        = "optima-devops-final-deploy"
  description = "Permissions for the dedicated study board CI user"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.state.arn}/study-board/terraform.tfstate"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.state.arn}/study-board/terraform.tfstate.tflock"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:Describe*"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.aws_region }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:ImportKeyPair", "ec2:DeleteKeyPair"]
        Resource = "${local.ec2_arn}:key-pair/${local.project}"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = ["${local.ec2_arn}:security-group/*", data.aws_vpc.default.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:DeleteSecurityGroup"
        ]
        Resource  = "${local.ec2_arn}:security-group/*"
        Condition = { StringEquals = local.project_tag }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:RunInstances"]
        Resource = "*"
        Condition = {
          StringEquals         = { "aws:RequestedRegion" = var.aws_region }
          StringEqualsIfExists = { "ec2:InstanceType" = "t3.micro" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = ["${local.ec2_arn}:instance/*", "${local.ec2_arn}:security-group/*", "${local.ec2_arn}:key-pair/${local.project}"]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = ["RunInstances", "CreateSecurityGroup", "ImportKeyPair"]
          }
        }
      },
      {
        Effect    = "Allow"
        Action    = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource  = ["${local.ec2_arn}:instance/*", "${local.ec2_arn}:security-group/*", "${local.ec2_arn}:key-pair/${local.project}"]
        Condition = { StringEquals = local.project_tag }
      },
      {
        Effect    = "Allow"
        Action    = ["ec2:GetConsoleOutput", "ec2:ModifyInstanceAttribute", "ec2:TerminateInstances"]
        Resource  = "${local.ec2_arn}:instance/*"
        Condition = { StringEquals = local.project_tag }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ci" {
  user       = aws_iam_user.ci.name
  policy_arn = aws_iam_policy.ci.arn
}

output "state_bucket" {
  description = "Private S3 bucket name for the TF_STATE_BUCKET repository variable."
  value       = aws_s3_bucket.state.bucket
}

output "ci_user" {
  description = "Dedicated IAM identity whose credential is provisioned separately."
  value       = aws_iam_user.ci.name
}
