# Configure the AWS Provider
provider "aws" {
  region  = "eu-west-2"
}

# Create a VPC
resource "aws_vpc" "vpc-ecs" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-10"
  }
}

# Create a Public Subnet 1 
resource "aws_subnet" "public-ecs-1" {
  vpc_id     = aws_vpc.vpc-ecs.id
  cidr_block = "10.0.0.0/24" 
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public- ecs-2"
  }
}

# Create a Public Subnet 2 
resource "aws_subnet" "public-ecs-2" {
  vpc_id     = aws_vpc.vpc-ecs.id
  cidr_block = "10.0.1.0/24" 
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public- ecs-2"
  }
}

# Create AWS Public Route Table
resource "aws_route_table" "pub-ecs-route" {
  vpc_id = aws_vpc.vpc-ecs.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs-igw.id
  }

  tags = {
    Name = "pub-ecs-route"
  }
}

# Create Public Route Table Association 1
resource "aws_route_table_association" "esc-route-associa-1" {
  subnet_id      = aws_subnet.public-ecs-1.id
  route_table_id = aws_route_table.pub-ecs-route.id
}

# Create Public Route Table Association 2
resource "aws_route_table_association" "esc-route-associa-2" {
  subnet_id      = aws_subnet.public-ecs-2.id
  route_table_id = aws_route_table.pub-ecs-route.id
}

# Create a Internet Gateway
resource "aws_internet_gateway" "ecs-igw" {
  vpc_id = aws_vpc.vpc-ecs.id

  tags = {
    Name = "esc-igw"
  }
}

# Create a Security Group EC2
resource "aws_security_group" "ec2_sg" {
    name        = "ec2_sg"
    vpc_id      = aws_vpc.vpc-ecs.id

    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

       egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags = {
     Name = "ec2_sg"
  }
}

# Create a Security Group RDS
resource "aws_security_group" "db_sg" {
    name        = "db_sg"
    
    ingress {
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

       egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags = {
     Name = "db_sg"
  }
}

# AWS Auto-scaling group
resource "aws_autoscaling_group" "auto-ecs" {
  name                      = "auto-esc-test"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = aws_launch_configuration.ecs_conf.name
  vpc_zone_identifier       = [aws_subnet.public-ecs-1.id]

  timeouts {
    delete = "15m"
  }
}

resource "aws_launch_configuration" "ecs_conf" {
  name_prefix   = "terraform-lc-ecs-"
  image_id      = "ami-078a289ddf4b09ae0"
  security_groups      = [aws_security_group.ec2_sg.id]
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

# AWS db subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids  = [aws_subnet.public-ecs-1.id, aws_subnet.public-ecs-2.id]

  tags = {
    Name = "ecs DB subnet group"
  }
}

# RDS Instance
resource "aws_db_instance" "db-ecs" {
  allocated_storage    = 12
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  username             = "idealistic"
  password             = "project123"
  port                 = "3306"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
}

# AWS ECR Registry Repository
resource "aws_ecr_repository" "ecs-repos" {
  name                 = "ecs-repos"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# AWS ECS Cluster
resource "aws_ecs_cluster" "ecs-cluster-tritek" {
  name = "ecs-cluster-tritek"
}