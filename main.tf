terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}

provider "aws" {
    profile = "default"
    region = "eu-west-1"
}

resource "tls_private_key" "devops" {
  algorithm   = "RSA"
  ecdsa_curve = 4096
}

resource "aws_key_pair" "devops" {
  key_name   = "jrmanes"
  public_key = tls_private_key.devops.public_key_openssh
}


resource "aws_vpc" "devops_vpc" {
    cidr_block = "172.16.10.0/24"
}

resource "aws_subnet" "devops_subnet" {
    vpc_id            = aws_vpc.devops_vpc.id
    cidr_block        = "172.16.10.0/24"
}


resource "aws_security_group" "sg_devops_sonar_psql" {
    name = "Allow access to instance Sonar PSQL"
    vpc_id            = aws_vpc.devops_vpc.id
    
    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = [ aws_vpc.devops_vpc.cidr_block ]
    }
    tags = {
      Name = "allow-access-from-internet-sonar-psql-jrmanes"
    }
}

resource "aws_security_group" "sg_devops_sonar" {
    name = "Allow access to instance Sonar"
    vpc_id            = aws_vpc.devops_vpc.id
    
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 9000
        to_port     = 9000
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
      Name = "allow-access-from-internet-sonar-jrmanes"
    }
}

resource "aws_instance" "ec2_sonar_psql" {
    # Ubuntu AMI
    ami = "ami-0aef57767f5404a3c"
    instance_type = "t2.micro"
    key_name = aws_key_pair.devops.key_name
    
    subnet_id   = aws_subnet.devops_subnet.id
    security_groups = [
        aws_security_group.sg_devops_sonar_psql.name,
        aws_security_group.sg_devops_sonar.name
    ]
    
    provisioner "remote-exec" {
        inline = [
                "sudo apt update",
                "sudo apt install -y vim net-tools docker docker-compose",
                "sudo docker run -p 5432:5432 -e POSTGRES_USER=sonar -e SONARQUBE_JDBC_USERNAME=sonar -e POSTGRES_PASSWORD=sonar -d postgres"
        ]
        connection {
            host        = aws_instance.ec2_sonar_psql.public_ip
            type        = "ssh"
            user        = "ubuntu"
            private_key = tls_private_key.devops.private_key_pem
            timeout     = "3m"
        }
    }
    
    tags = {
      Name = "jrmanes_sonar_psql"
    }
}

resource "aws_instance" "ec2_sonar" {
    ami = "ami-0aef57767f5404a3c"
    instance_type = "t2.micro"
    key_name = aws_key_pair.devops.key_name
    
    subnet_id   = aws_subnet.devops_subnet.id
    security_groups = [
        aws_security_group.sg_devops_sonar_psql.name,
        aws_security_group.sg_devops_sonar.name
    ]
    
    provisioner "remote-exec" {
        inline = [
                "sudo apt update",
                "sudo apt install -y vim net-tools docker docker-compose",
                "sudo sysctl -w vm.max_map_count=262144",
                "sudo sysctl -w fs.file-max=65536",
                "sudo docker run -p 9000:9000 -e SONARQUBE_JDBC_URL=jdbc:postgresql://${aws_instance.ec2_sonar_psql.private_ip}:5432/sonar -e SONARQUBE_JDBC_USERNAME=sonar -e SONARQUBE_JDBC_PASSWORD=sonar -d sonarqube"
        ]
        connection {
            host        = aws_instance.ec2_sonar.public_ip
            type        = "ssh"
            user        = "ubuntu"
            private_key = tls_private_key.devops.private_key_pem
            timeout     = "3m"
        }
    }
    
    tags = {
      Name = "jrmanes_sonar"
    }
}