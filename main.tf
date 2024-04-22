provider "aws" {
     region = "us-east-2"
     access_key = "AKIAQRH4ND34WNGRNWOP"
     secret_key = "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"
}

# Create a VPC

resource "aws_vpc" "testvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
     Name = "testvpc" 
  }
}
# Create a Public Subnet

resource "aws_subnet" "testsbnt1" {
   vpc_id = aws_vpc.testvpc.id
   cidr_block = "10.0.1.0/24"
     map_public_ip_on_launch = "true"
     availability_zone = "us-east-2a"
   
   tags = {
       Name = "testsbnt1"
    } 
}
# Create a Private Subnet

resource "aws_subnet" "testsbnt2" {
    vpc_id = aws_vpc.testvpc.id
    cidr_block = "10.0.2.0/24"
      map_public_ip_on_launch = "false"
      availability_zone = "us-east-2b"

     tags = {
       Name = "testsbnt2"
     } 
}
# Create an Internet Gateway

resource "aws_internet_gateway" "testigw" {
    vpc_id = aws_vpc.testvpc.id
    tags = {
      Name = "testigw"
    }
}
# Create a Route Table for Public Subnet

resource "aws_route_table" "testrtb1" {
      vpc_id = aws_vpc.testvpc.id

      route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.testigw.id
      }

      route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.testigw.id
      }
}
# Associate Public Route Table with Public Subnet

resource "aws_route_table_association" "testassoc1" {
        subnet_id = aws_subnet.testsbnt1.id
        route_table_id = aws_route_table.testrtb1.id
}
# Create a Private Route Table for Subnet 2

resource "aws_route_table" "testrtb2" {
     vpc_id = aws_vpc.testvpc.id

     route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.nat.id
     }
      
     tags = {
       Name = "testrtb2"
     }
}
# Associate Route Table with Private Subnet

resource "aws_route_table_association" "testassoc2" {
      subnet_id = aws_subnet.testsbnt2.id
      route_table_id = aws_route_table.testrtb2.id
}
# Assign ENI with IP

resource "aws_network_interface" "testeni1" {
           subnet_id = aws_subnet.testsbnt1.id
           private_ips = ["10.0.1.10"]
           security_groups = [aws_security_group.testsg.id]
}

resource "aws_network_interface" "testeni2" {
           subnet_id = aws_subnet.testsbnt2.id
           private_ips = ["10.0.2.10"]
           security_groups = [aws_security_group.testsg.id]
}
# Assign Elastic IP to ENI

resource "aws_eip" "testeip1" {
        domain = "vpc"
        network_interface = aws_network_interface.testeni1.id
        associate_with_private_ip = "10.0.1.10"
        depends_on= [aws_internet_gateway.testigw, aws_instance.Instance1]
        tags = {
           Name = "testeip1"
        }
}
# Create an Elastic IP Address for NAT Gateway

resource "aws_eip" "testeip2" {
        domain = "vpc"
        associate_with_private_ip = "10.0.2.10"
        depends_on= [aws_internet_gateway.testigw]
        tags = {
           Name = "testeip2"
        }
}
# Create a NAT Gateway for VPC

resource "aws_nat_gateway" "nat" {
     allocation_id = aws_eip.testeip2.id
     subnet_id = aws_subnet.testsbnt2.id

     tags = {
      Name = "nat"
     }
}
# Create a Security Group

resource "aws_security_group" "testsg" {
   description = "Allow limited inbound external traffic"
   vpc_id = aws_vpc.testvpc.id
   name = "testsg"

   ingress {
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 22
     to_port = 22
   }
   
   ingress {
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 80
     to_port = 80
   }
   
    ingress {
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      from_port = 443
      to_port = 443
     }
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
              
    }
    tags = { 
      Name = "testsg"
    }
}
# Create Linux Server & Install/Enable Apache2 (Instance 1)

resource "aws_instance" "Instance1" {
    ami = "ami-0b8b44ec9a8f90422"
    instance_type = "t2.micro"
    availability_zone = "us-east-2a"
    key_name = "Terraform"
    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.testeni1.id
   }

 user_data = <<-EOF
   #!/bin/bash
   sudo apt update -y
   sudo apt install apache2 -y
   sudo systemctl start apache2
   sudo systemctl enable apache2
   EOF
   
   tags = {
     Name = "Instance1" 
    }
}
# Create Linux Server & Install/Enable Apache2 Here (Instance 2)

resource "aws_instance" "Instance2" {
    ami = "ami-0b8b44ec9a8f90422"
    instance_type = "t2.micro"
    availability_zone = "us-east-2b"
    key_name = "Terraform"
    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.testeni2.id
   }

 user_data = <<-EOF
   #!/bin/bash
   sudo apt update -y
   sudo apt install apache2 -y
   sudo systemctl start apache2
   sudo systemctl enable apache2
   EOF
   
   tags = {
     Name = "Instance2" 
    }
}
