terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key          = "study-board/terraform.tfstate"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = { Project = "optima-devops-final" }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "deploy" {
  key_name   = "optima-devops-final"
  public_key = trimspace(var.ssh_public_key)
}

resource "aws_security_group" "web" {
  name        = "optima-devops-final"
  description = "Study board HTTP and SSH from the current CI runner"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "GitHub Actions runner"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Public HTTP for the study board"
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deploy.key_name
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 12
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-BOOTSTRAP
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o Acquire::Retries=3 update -qq
    apt-get -o Acquire::Retries=3 install -y -qq docker.io
    systemctl enable --now docker
    printf 'STUDY_BOARD_HOST_KEY %s\n' "$(cut -d ' ' -f 1,2 /etc/ssh/ssh_host_ed25519_key.pub)" > /dev/console
  BOOTSTRAP

  tags = { Name = "optima-devops-final" }
}
