provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "main" {
  cidr_block = "10.82.0.0/20"
  tags = { Name = "vmss-vnet" }
}

resource "aws_subnet" "zone_a" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.82.0.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "subnet-zone-a" }
}

resource "aws_subnet" "zone_b" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.82.1.0/24"
  availability_zone = "eu-north-1b"
  tags = { Name = "subnet-zone-b" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "vmss-igw" }
}

resource "aws_instance" "vm1" {
  ami = "ami-09a9858973b288bdd"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.zone_a.id
  availability_zone = "eu-north-1a"
  tags = { Name = "az104-vm1" }
}

resource "aws_instance" "vm2" {
  ami = "ami-09a9858973b288bdd"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.zone_b.id
  availability_zone = "eu-north-1b"
  tags = { Name = "az104-vm2" }
}

resource "aws_security_group" "vmss_sg" {
  name   = "vmss1-nsg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow-http"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vmss1-nsg" }
}

resource "aws_launch_template" "vmss" {
  name = "vmss1-template"
  image_id = "ami-09a9858973b288bdd"
  instance_type = "t3.micro"

  network_interfaces {
    security_groups = [aws_security_group.vmss_sg.id]
  }

  tags = { Name = "vmss1" }
}

resource "aws_autoscaling_group" "vmss" {
  name = "vmss1"

  min_size = 2
  max_size = 10
  desired_capacity = 2

  vpc_zone_identifier = [
    aws_subnet.zone_a.id,
    aws_subnet.zone_b.id,
  ]

  launch_template {
    id = aws_launch_template.vmss.id
    version = "$Latest"
  }

  tag {
    key = "Name"
    value = "vmss1-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name = "scale-out"
  autoscaling_group_name = aws_autoscaling_group.vmss.name
  policy_type = "SimpleScaling"
  adjustment_type = "PercentChangeInCapacity"
  scaling_adjustment = 50
  cooldown = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name = "cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Average"
  threshold = 70
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vmss.name
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name = "scale-in"
  autoscaling_group_name = aws_autoscaling_group.vmss.name
  policy_type = "SimpleScaling"
  adjustment_type = "PercentChangeInCapacity"
  scaling_adjustment = -50
  cooldown = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name = "cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Average"
  threshold = 30
  alarm_actions = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vmss.name
  }
}
