# CONFIGURE AWS PROVIDER 
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "us-east-1"
  #profile = "Admin"
}
# CREATE VPC
resource "aws_vpc" "d5vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true

  tags = {
    Name = var.vpcname
  }
}
# CREATE SUBNETS
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.d5vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.subnet1AZ
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet1name
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.d5vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.subnet2AZ
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet2name
  }
}

# CREATE SECURITY GROUPS
resource "aws_security_group" "jenkins_sg" {
  name        = var.SGName1
  vpc_id = aws_vpc.d5vpc.id
  description = "open jenkins port"
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" : var.SGName1
    "Terraform" : "true"
  }

}

resource "aws_security_group" "app_sg" {
  name        = var.SGName2
  vpc_id = aws_vpc.d5vpc.id
  description = "open port for gunicorn and ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" : var.SGName2
    "Terraform" : "true"
  }

}

# CREATE INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.d5vpc.id

  tags = {
    Name = var.IGName
  }
}

# CONFIGURE DEFAULT ROUTE TABLE
resource "aws_default_route_table" "routetable" {
  default_route_table_id = aws_vpc.d5vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.RTname
  }
}

# CREATE INSTANCES
resource "aws_instance" "jenkinsserver" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id = aws_subnet.subnet1.id
  key_name = var.key_name
  associate_public_ip_address = true

  user_data = "${file("jenkins.sh")}"

  tags = {
    "Name" : var.InstanceName1
  }

}

resource "aws_instance" "application" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id = aws_subnet.subnet2.id
  key_name = var.key_name
  associate_public_ip_address = true

# user_data = "${file("deploy.sh")}"

  tags = {
    "Name" : var.InstanceName2
  }

}


output "instance_ip" {
  value = [aws_instance.jenkinsserver.public_ip, aws_instance.application.public_ip]
}

