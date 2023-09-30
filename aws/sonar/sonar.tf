provider "aws" {
  region = "us-east-1" 
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0d887a308369b6881"
}

variable "keypair_id" {
  description = "The Key Pair ID for the EC2 instance"
  type        = string
}



resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube-sg"
  description = "Security Group for SonarQube"

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
}

resource "aws_security_group" "sonarqube_alb_sg" {
  name        = "sonarqube-alb-sg"
  description = "Security Group for SonarQube ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "sonarqube_instance" {
  ami           = var.ami_id
  instance_type = "t2.medium"

  key_name = var.keypair_id
  security_groups = [aws_security_group.sonarqube_sg.name]

  tags = {
    Name = "SonarQube"
    owner = "diego"
    created_by = "tf_automation"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y wget unzip
              sudo amazon-linux-extras enable corretto8
              sudo yum install java-11-amazon-corretto.x86_64 -y
              sudo ln -sf /usr/lib/jvm/java-11-amazon-corretto.x86_64/bin/java /usr/bin/java
              export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto.x86_64
              wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.2.1.78527.zip
              unzip sonarqube-10.2.1.78527.zip
              sudo mv sonarqube-10.2.1.78527 /opt/sonarqube
              sudo chown -R ec2-user:ec2-user /opt/sonarqube
              echo '[Unit]' | sudo tee /etc/systemd/system/sonarqube.service
              echo 'Description=SonarQube service' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'After=syslog.target network.target' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo '' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo '[Service]' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'Type=forking' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'User=ec2-user' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'Restart=always' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo '' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo '[Install]' | sudo tee -a /etc/systemd/system/sonarqube.service
              echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/sonarqube.service
              sudo systemctl daemon-reload
              sudo systemctl enable sonarqube
              sudo systemctl start sonarqube
              EOF
}

terraform {
  backend "s3" {
  }
}

output "instance_id" {
  value = aws_instance.sonarqube_instance.id
}

# resource "aws_ebs_volume" "extra_storage" {
#   availability_zone = aws_instance.sonarqube_instance.availability_zone
#   size              = 50

#   tags = {
#     InstanceID = aws_instance.sonarqube_instance.id
#   }
# }