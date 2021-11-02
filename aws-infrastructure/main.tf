terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

locals {
  instance_name = "${terraform.workspace}-instance"
  vpc_name = "${terraform.workspace}-vpc"
  gateway_name = "${terraform.workspace}-gw"
  route_table_name = "${terraform.workspace}-rt"
  subnet_name = "${terraform.workspace}-subnet"
  security_group_name = "${terraform.workspace}-sg"
  network_interface_name = "${terraform.workspace}-nic"
  eip_name = "${terraform.workspace}-eip"
  key_pair_name = "${terraform.workspace}-key-pair"
  target_group_name = "${terraform.workspace}-target-group"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = local.vpc_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = local.gateway_name
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = local.route_table_name
  }

}

resource "aws_lb_target_group" "target-group" {
  name     = "app-target-group"
  port     = 80
  target_type = "instance"
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    interval = 10
    path = "/check"
    protocol = "HTTP"
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = local.target_group_name
  }
}

resource "aws_lb" "lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  ip_address_type = "ipv4"
  # security_groups = []
  # https://medium.com/cognitoiq/terraform-and-aws-application-load-balancers-62a6f8592bcf
  subnets            = [ aws_subnet.subnet-1.id , aws_subnet.subnet-2.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_attach_1" {
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.instance-1.id
  port             = 80
}


resource "aws_lb_target_group_attachment" "ec2_attach_2" {
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.instance-2.id
  port             = 80
}

# Security Group
resource "aws_security_group" "sg" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = local.security_group_name
  }
}

resource "aws_key_pair" "key-pair" {
  key_name = "key-for-demo"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDLD+EGHqtCSSGy0DAI05sAPKrtFkxN/qq0PGI0T+6mFDjW02qn0rXkyXmc7vH9/NMxuqrVYLdTK8ewSdbkKQfxd1aewY+ZykJ7q6QO67JbTOWTn/TG7ZenkCdGRbYnEiQzRf0QhVVkFk1jj+pr9NQhT0Y6u39QjNdqRNgAZa5Xvs4opG8rk9j5GRnMGy0hdKJ//E8G/heoTJOoB4u/5OgQV4toBlUo8Q5zo11IeIgu4bAL+bG+QeElbgjeocM1o1GonykaCDCa4P3S4tZ5Qw766QUff322+qQD94LDLzE4jCmpd4Zzw877JuNtEtMUJ/HkGN1FMg/jjERmUGezc7ZrJ6EF0mbXqagy1oML3uT9KJJErijO6CaYGnXOhIq2yhbbSPjSpgbv5FOXOjKAO1mknkWYH1CBM6N86yhm2Q4UUkzoI2Agg6eIOhwzyrAcmFXU9O4bGJc1Jt5tQcAklQ9beX5o5fYNX1M6egfgH8EoXKWKW2pjlNXC86x7EvfMdDM= aws-demo"
  tags = {
    Name = local.key_pair_name
  }
}
############################
# Resources for Instance 1 #
############################
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  

  tags = {
    Name = local.subnet_name
  }
}

resource "aws_route_table_association" "rta-1" {
  
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt.id
  
}
resource "aws_network_interface" "nic-1" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.sg.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }

  tags = {
    Name = local.network_interface_name
  }

}

resource "aws_eip" "eip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-1.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
  tags = {
    Name = local.eip_name
  }
}

resource "aws_instance" "instance-1" {
  ami               = "ami-05f7491af5eef733a"
  instance_type     = var.instance_type
  availability_zone = "eu-central-1a"
  key_name          = aws_key_pair.key-pair.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nic-1.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo curl https://releases.rancher.com/install-docker/20.10.sh | sh
              EOF

  tags = {
    Name = local.instance_name
  }
}

############################
# Resources for Instance 2 #
############################
resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = local.subnet_name
  }
}

resource "aws_route_table_association" "rta-2" {
  
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.rt.id
  
}
resource "aws_network_interface" "nic-2" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.sg.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }

  tags = {
    Name = local.network_interface_name
  }

}

resource "aws_eip" "eip-2" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-2.id
  associate_with_private_ip = "10.0.2.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
  tags = {
    Name = local.eip_name
  }
}

resource "aws_instance" "instance-2" {
  ami               = "ami-05f7491af5eef733a"
  instance_type     = var.instance_type
  availability_zone = "eu-central-1b"
  key_name          = aws_key_pair.key-pair.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nic-2.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo curl https://releases.rancher.com/install-docker/20.10.sh | sh
              EOF

  tags = {
    Name = local.instance_name
  }
}


##############
# Prometheus #
##############
resource "aws_security_group" "sg-prometheus" {
  name        = "allow prometheus and grafana"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.vpc.id
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = local.security_group_name
  }
}
resource "aws_network_interface" "nic-3" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.2.51"]
  security_groups = [aws_security_group.sg-prometheus.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }

  tags = {
    Name = local.network_interface_name
  }

}

resource "aws_eip" "eip-3" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-3.id
  associate_with_private_ip = "10.0.2.51"
  depends_on = [
    aws_internet_gateway.gw
  ]
  tags = {
    Name = local.eip_name
  }
}

resource "aws_instance" "instance-3" {
  ami               = "ami-05f7491af5eef733a"
  instance_type     = "t2.medium"
  availability_zone = "eu-central-1b"
  key_name          = aws_key_pair.key-pair.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nic-3.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo curl https://releases.rancher.com/install-docker/20.10.sh | sh
              EOF

  tags = {
    Name = "prometheus"
  }
}