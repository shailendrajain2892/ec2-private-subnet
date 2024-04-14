
# Create AWS Launch template  to launch instance required for ASG
resource "aws_launch_template" "web_launch_temp" {
  name                   = "webserver"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.webserver.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "WebServer"
    }
  }

  user_data = base64encode(file("userdata.tpl"))

}

# create application load balancer
resource "aws_lb" "alb" {
  name                       = "ec2Private"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.publicSubnet : subnet.id]
  enable_deletion_protection = false

  tags = {
    Environment = "Prod"
  }
}

# Create AWS ALB target group 
resource "aws_alb_target_group" "webserver" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ec2_private.id
}

# Create aws alb listener who forwards the request to target group 
resource "aws_alb_listener" "frontend" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }
}

# Creaet aws alb listener rule
resource "aws_alb_listener_rule" "rule1" {
  listener_arn = aws_alb_listener.frontend.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webserver.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "ec2Asg" {
  vpc_zone_identifier = [for subnet in aws_subnet.privateSubnet : subnet.id]
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  target_group_arns   = [aws_alb_target_group.webserver.arn]

  launch_template {
    id      = aws_launch_template.web_launch_temp.id
    version = "$Latest"
  }
}


resource "aws_instance" "BastionHost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.publicSubnet[0].id
  user_data                   = file("userdata.tpl")
  vpc_security_group_ids      = [aws_security_group.SGPublic.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  tags = {
    Name = "Bastion Host"
  }
}


