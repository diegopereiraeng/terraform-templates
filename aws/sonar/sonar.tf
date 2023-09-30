provider "aws" {
  region = "us-east-1" 
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

resource "aws_instance" "sonarqube_instance" {
  ami           = var.ami_id
  instance_type = "t2.medium"

  key_name = "diego-aws" 
  security_groups = [aws_security_group.sonarqube_sg.name]

  tags = {
    Name = "SonarQube"
    owner = "diego"
    created_by = "tf_automation"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y java-11-openjdk-devel wget unzip",
      "wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.2.1.78527.zip",
      "unzip sonarqube-10.2.1.78527.zip",
      "sudo mv sonarqube-10.2.1.78527 /opt/sonarqube",
      "echo '[Unit]' | sudo tee /etc/systemd/system/sonarqube.service",
      "echo 'Description=SonarQube service' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'After=syslog.target network.target' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo '' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo '[Service]' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'Type=forking' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'User=ec2-user' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'Restart=always' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo '' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo '[Install]' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/sonarqube.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable sonarqube",
      "sudo systemctl start sonarqube"
    ]
  }
}

terraform {
  backend "s3" {
  }
}

output "instance_id" {
  value = aws_instance.sonarqube_instance.id
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0d887a308369b6881" # Replace this with a valid default AMI ID if you have one
}

# resource "aws_ebs_volume" "extra_storage" {
#   availability_zone = aws_instance.sonarqube_instance.availability_zone
#   size              = 50

#   tags = {
#     InstanceID = aws_instance.sonarqube_instance.id
#   }
# }