provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "main" {
  cidr_block = "10.60.0.0/16"
  tags = { Name = "az104-06-vnet" }
}

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.60.1.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "subnet1" }
}

resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.60.2.0/24"
  availability_zone = "eu-north-1b"
  tags = { Name = "subnet2" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "az104-06-igw" }
}

resource "aws_lb" "main" {
  name = "az104-lb"
  internal = false
  load_balancer_type = "network"
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = { Name = "az104-lb" }
}

resource "aws_lb_target_group" "main" {
  name = "az104-be"
  port = 80
  protocol = "TCP"
  vpc_id = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port = 80
    interval = 30
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port = 80
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb" "appgw" {
  name = "az104-appgw"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = { Name = "az104-appgw" }
}

resource "aws_lb_target_group" "images" {
  name = "az104-imagebe"
  port = 80
  protocol = "HTTP"
  vpc_id  = aws_vpc.main.id
}

resource "aws_lb_target_group" "videos" {
  name = "az104-videobe"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
}

resource "aws_lb_listener" "appgw" {
  load_balancer_arn = aws_lb.appgw.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.images.arn
  }
}

resource "aws_lb_listener_rule" "images" {
  listener_arn = aws_lb_listener.appgw.arn
  priority = 10

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.images.arn
  }

  condition {
    path_pattern { values = ["/image/*"] }
  }
}

resource "aws_lb_listener_rule" "videos" {
  listener_arn = aws_lb_listener.appgw.arn
  priority = 20

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.videos.arn
  }

  condition {
    path_pattern { values = ["/video/*"] }
  }
}
