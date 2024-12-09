variable "vpc_availability_zone_SaoPaulo" {
  type        = list(string)
  description = "Availability Zone"
  default     = ["sa-east-1a", "sa-east-1c"]
}

// VPC
resource "aws_vpc" "saopaulo" {
  cidr_block           = "10.233.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  provider             = aws.sao_paulo
  tags = {
    Name = "Sao Paulo VPC"
  }
}

// Subnets
resource "aws_subnet" "public_subnet_SaoPaulo" {
  vpc_id            = aws_vpc.saopaulo.id
  count             = length(var.vpc_availability_zone_SaoPaulo)
  cidr_block        = cidrsubnet(aws_vpc.saopaulo.cidr_block, 8, count.index + 1)
  availability_zone = element(var.vpc_availability_zone_SaoPaulo, count.index)
  provider          = aws.sao_paulo
  tags = {
    Name = "Sao Paulo Public Subnet${count.index + 1}",
  }
}

resource "aws_subnet" "private_subnet_SaoPaulo" {
  vpc_id            = aws_vpc.saopaulo.id
  count             = length(var.vpc_availability_zone_SaoPaulo)
  cidr_block        = cidrsubnet(aws_vpc.saopaulo.cidr_block, 8, count.index + 11)
  availability_zone = element(var.vpc_availability_zone_SaoPaulo, count.index)
  provider          = aws.sao_paulo
  tags = {
    Name = "Sao Paulo Private Subnet${count.index + 1}",
  }
}

// IGW
resource "aws_internet_gateway" "saoaws_sao_paulo_igw" {
  vpc_id   = aws_vpc.saopaulo.id
  provider = aws.sao_paulo

  tags = {
    Name = "saoaws_sao_paulo_igw"
  }
}

// RT for the public subnet
resource "aws_route_table" "saoaws_sao_paulo_route_table_public_subnet" {
  vpc_id   = aws_vpc.saopaulo.id
  provider = aws.sao_paulo

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.saoaws_sao_paulo_igw.id
  }

  tags = {
    Name = "Route Table for Public Subnet",
  }

}

// Association between RT and IG
resource "aws_route_table_association" "saoaws_sao_paulo_public_subnet_association" {
  route_table_id = aws_route_table.saoaws_sao_paulo_route_table_public_subnet.id
  count          = length((var.vpc_availability_zone_SaoPaulo))
  subnet_id      = element(aws_subnet.public_subnet_SaoPaulo[*].id, count.index)
  provider       = aws.sao_paulo
}

// EIP
resource "aws_eip" "saoaws_sao_paulo_eip" {
  domain   = "vpc"
  provider = aws.sao_paulo
}

// NAT
resource "aws_nat_gateway" "saopaulo_nat" {
  allocation_id = aws_eip.saoaws_sao_paulo_eip.id
  subnet_id     = aws_subnet.public_subnet_SaoPaulo[0].id
  provider      = aws.sao_paulo
}

// RT for private Subnet
resource "aws_route_table" "saoaws_sao_paulo_route_table_private_subnet" {
  vpc_id   = aws_vpc.saopaulo.id
  provider = aws.sao_paulo

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.saopaulo_nat.id
  }
/*
  route {
    cidr_block         = "10.230.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.local_sao_paulo.id
  }
*/
  tags = {
    Name = "Route Table for Private Subnet",
  }

}

// RT Association Private
resource "aws_route_table_association" "saoaws_sao_paulo_private_subnet_association" {
  route_table_id = aws_route_table.saoaws_sao_paulo_route_table_private_subnet.id
  count          = length((var.vpc_availability_zone_SaoPaulo))
  subnet_id      = element(aws_subnet.private_subnet_SaoPaulo[*].id, count.index)
  provider       = aws.sao_paulo
}

// Security Groups
resource "aws_security_group" "saoaws_sao_paulo_alb_sg" {
  name        = "saoaws_sao_paulo-alb-sg"
  description = "Security Group for Application Load Balancer"
  provider    = aws.sao_paulo

  vpc_id = aws_vpc.saopaulo.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "sao-paulo-alb-sg"
  }
}

// Security Group For EC2

resource "aws_security_group" "saoaws_sao_paulo_ec2_sg" {
  name        = "sao-paulo-ec2-sg"
  description = "Security Group for Webserver Instance"
  provider    = aws.sao_paulo

  vpc_id = aws_vpc.saopaulo.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "TCP"
    security_groups = [aws_security_group.saoaws_sao_paulo_alb_sg.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sao-paulo-ec2-sg"
  }
}

// Load Balancer
resource "aws_lb" "saopaulo_alb" {
  name                       = "saopaulo-load-balancer"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = aws_subnet.public_subnet_SaoPaulo[*].id
  depends_on                 = [aws_internet_gateway.saoaws_sao_paulo_igw]
  enable_deletion_protection = false
  provider                   = aws.sao_paulo

  tags = {
    Name    = "saopauloLoadBalancer"
    Service = "saopaulo"
  }
}

// Target Group
resource "aws_lb_target_group" "saopaulo-tg" {
  name        = "saopaulo-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.saopaulo.id
  provider    = aws.sao_paulo
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name    = "saopaulo-tg"
    Service = "saopauloTG"
  }
}

// Listener
resource "aws_lb_listener" "saopaulo_http" {
  load_balancer_arn = aws_lb.saopaulo_alb.arn
  port              = 80
  protocol          = "HTTP"
  provider          = aws.sao_paulo

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.saopaulo-tg.arn
  }
}

// Launch Template
resource "aws_launch_template" "saopaulo_LT" {
  provider      = aws.sao_paulo
  name_prefix   = "saopaulo_LT"
  image_id      = "ami-0c820c196a818d66a"
  instance_type = "t2.micro"

  user_data = filebase64("userdata.sh")

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.saoaws_sao_paulo_ec2_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "saoaws_sao_paulo-ec2-web-server"
    }
  }
}

// Auto Scaling Group
resource "aws_autoscaling_group" "saoaws_sao_paulo_ec2_asg" {
  max_size            = 3
  min_size            = 2
  desired_capacity    = 2
  name                = "saoaws_sao_paulo-web-server-asg"
  target_group_arns   = [aws_lb_target_group.saopaulo-tg.id]
  vpc_zone_identifier = aws_subnet.private_subnet_SaoPaulo[*].id
  provider            = aws.sao_paulo

  launch_template {
    id      = aws_launch_template.saopaulo_LT.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}
/*
// TGW
resource "aws_ec2_transit_gateway" "saoaws_sao_paulo-TGW" {
  description = "saoaws_sao_paulo-TGW"
  provider    = aws.sao_paulo

  tags = {
    Name     = "saoaws_sao_paulo-TGW"
    Service  = "TGW"
    Location = "saoaws_sao_paulo"
  }
}

// VPC Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "saoaws_sao_paulo-TGW-attachment" {
  subnet_ids         = aws_subnet.public_subnet_SaoPaulo[*].id
  transit_gateway_id = aws_ec2_transit_gateway.saoaws_sao_paulo-TGW.id
  vpc_id             = aws_vpc.saopaulo.id
  provider           = aws.sao_paulo
}
*/