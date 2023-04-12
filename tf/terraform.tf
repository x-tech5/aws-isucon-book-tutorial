# --- generated ---
terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      version = "~> 4.0"
    }
  }

  # backend "s3" {
  #   bucket = "private-isu.terraform.xxxxxxxxxxx.ap-northeast-1"
  #   key    = "private-isu/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Project = var.project_name
      AppEnv  = var.app_env
    }
  }
}

provider "aws" {
  # Usage (in data, resource):
  #   provider = aws.us_east_1
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project = var.project_name
      AppEnv  = var.app_env
    }
  }
}
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = data.aws_region.current.name
}

variable "project_name" {
  default = "private-isu"
}

variable "pubkey_url" {
  type    = string
  default = ""
}

locals {
  ec2_user_data = var.pubkey_url == "" ? "" : <<EOF
#cloud-config
runcmd:
  - 'install -d -o isucon -g isucon -m 700 /home/isucon/.ssh || :'
  - 'curl -sL ${var.pubkey_url} | tee -a /home/isucon/.ssh/authorized_keys'
  - 'chown isucon:isucon /home/isucon/.ssh/authorized_keys'
  - 'chmod 600 /home/isucon/.ssh/authorized_keys'
EOF

}

# ---

variable "app_env" {
  type    = string
  default = "dev"
}

## vpc

variable "vpc_cidr_block" {
  type    = string
  default = "172.27.1.0/24"
}

variable "public_subnets" {
  type = list(any)
  default = [
    {
      cidr_block        = "172.27.1.0/26"
      availability_zone = "ap-northeast-1a"
    },
    {
      cidr_block        = "172.27.1.64/26"
      availability_zone = "ap-northeast-1c"
    },
    {
      cidr_block        = "172.27.1.128/26"
      availability_zone = "ap-northeast-1d"
    },
  ]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-${var.app_env}"
  }
}

## vpc.subnet.public
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index].cidr_block
  availability_zone       = var.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-${var.app_env}-public-${var.public_subnets[count.index].availability_zone}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-${var.app_env}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-${var.app_env}-public-route-table"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

## seucurity_group

resource "aws_security_group" "public" {
  name = "${var.project_name}-${var.app_env}-public-sg"
  tags = {
    Name = "${var.project_name}-${var.app_env}-public-sg"
  }
  vpc_id = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress = [
    {
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = true
      to_port          = 0
    },
  ]
}

## SSM -->
data "aws_iam_policy_document" "vpc_endpoint_ssm" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_instance_profile" "work" {
  name = "${var.project_name}-${var.app_env}-work"
  role = aws_iam_role.ec2_work.id
}

resource "aws_iam_role" "ec2_work" {
  name               = "${var.project_name}-${var.app_env}-work"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_work.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
## <-- SSM

## Observability -->
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_work.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Configuring Permissions | AWS Open Distro for OpenTelemetry
# https://aws-otel.github.io/docs/setup/permissions
resource "aws_iam_policy" "otel_collector" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
          "ssm:GetParameters",
        ]
        Resource = ["*"]
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "otel_collector" {
  role       = aws_iam_role.ec2_work.id
  policy_arn = aws_iam_policy.otel_collector.arn
}
## <-- Observability

## Instance -->
resource "aws_instance" "benchmarker" {
  ami                  = "ami-079828aa0027ea43f"
  instance_type        = "c6i.xlarge"
  iam_instance_profile = aws_iam_instance_profile.work.name

  disable_api_termination              = var.app_env == "dev" ? false : true
  instance_initiated_shutdown_behavior = "stop"

  associate_public_ip_address = true

  subnet_id              = aws_subnet.public_subnet[2].id # "ap-northeast-1d"
  vpc_security_group_ids = [aws_security_group.public.id]

  # ebs_optimized = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = 20
    volume_type           = "gp3"
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-${var.app_env}-benchmarker"
  }
  user_data = local.ec2_user_data
}

resource "aws_instance" "webapp" {
  ami                  = "ami-08bde596066780be7"
  instance_type        = "c6i.large"
  iam_instance_profile = aws_iam_instance_profile.work.name

  disable_api_termination              = var.app_env == "dev" ? false : true
  instance_initiated_shutdown_behavior = "stop"

  associate_public_ip_address = true

  subnet_id              = aws_subnet.public_subnet[2].id # "ap-northeast-1d"
  vpc_security_group_ids = [aws_security_group.public.id]

  # ebs_optimized = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = 20
    volume_type           = "gp3"
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-${var.app_env}-webapp"
  }
  user_data = local.ec2_user_data
}

# ---

output "benchmarker-instance_id" {
  value = aws_instance.benchmarker.id
}

output "webapp-instance_id" {
  value = aws_instance.webapp.id
}
