# Stage 1

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/key.pub")
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = var.ec2_instance_type
  # Stage 1
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  # Stage 2
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags = {
    Name          = "test-instance"
    drift_example = "v1"
  }
}

resource "aws_security_group" "sg_ssh" {
  name = "sg_ssh"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [var.admin_public_ip]
  }
}

# Stage 2

#resource "aws_security_group" "sg_web" {
#  name        = "sg_web"
#  description = "allow 8080"
#}

#resource "aws_security_group_rule" "sg_web" {
#  type      = "ingress"
#  to_port   = "8080"
#  from_port = "8080"
#  protocol  = "tcp"
#  cidr_blocks = ["0.0.0.0/0"]
#  security_group_id = aws_security_group.sg_web.id
#}
