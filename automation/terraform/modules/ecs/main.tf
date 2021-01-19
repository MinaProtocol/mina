locals {
  ec2_resources_name = "${var.name}-${var.environment}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = var.name

  cidr = "10.1.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = false # this is faster, but should be "true" for real

  tags = {
    Environment = var.environment
    Name        = var.name
  }
}

#----- ECS --------
module "ecs" {
  source = "terraform-aws-modules/ecs/aws"
  name   = var.name
}

module "ec2-profile" {
  source = "github.com/terraform-aws-modules/terraform-aws-ecs/modules/ecs-instance-profile"
  name   = var.name
}

#----- ECS  Resources--------

#For now we only use the AWS ECS optimized ami <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html>
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

module "this" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = local.ec2_resources_name

  # Launch configuration
  lc_name = local.ec2_resources_name

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = var.cluster_instance_type
  security_groups      = [module.vpc.default_security_group_id, aws_security_group.allow_prometheus_9090.id, aws_security_group.allow_egress.id, aws_security_group.allow_ssh.id, aws_security_group.allow_lotsa_ports.id]
  iam_instance_profile = module.ec2-profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered
  key_name = var.cluster_ssh_key_name

  # Auto scaling group
  asg_name                  = local.ec2_resources_name
  vpc_zone_identifier       = module.vpc.public_subnets
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = var.cluster_max_size
  desired_capacity          = var.cluster_desired_capacity
  wait_for_capacity_timeout = 0
  associate_public_ip_address = "true"

  tags = [
    {
      key                 = "Environment"
      value               = var.environment
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = var.name
      propagate_at_launch = true
    },
    {
      key                 = "module"
      value               = "ecs"
      propagate_at_launch = true
    },
  ]
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = var.name
  }
}