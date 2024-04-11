
# Create a VPC
resource "aws_vpc" "ec2_private" {
  cidr_block = var.cidr_block

  tags = {
    Name = "ec2-private"
  }
}

# Create Public and Private Subnet
resource "aws_subnet" "publicSubnet1" {
  vpc_id     = aws_vpc.ec2_private.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone = var.availability_zone[0]

  tags = {
    Name = "Subnet1"
    Type = "Public"
  }
}

resource "aws_subnet" "publicSubnet2" {
  vpc_id     = aws_vpc.ec2_private.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 2)
  availability_zone = var.availability_zone[1]

  tags = {
    Name = "Subnet2"
    Type = "Public"
  }
}

resource "aws_subnet" "privateSubnet1" {
  vpc_id     = aws_vpc.ec2_private.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 3)
  availability_zone = var.availability_zone[0]

  tags = {
    Name = "pvtSubnet1"
    Type = "Private"
  }
}

resource "aws_subnet" "privateSubnet2" {
  vpc_id     = aws_vpc.ec2_private.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 4)
  availability_zone = var.availability_zone[1]

  tags = {
    Name = "pvtSubnet2"
    Type = "Private"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.ec2_private.id
  tags = {
    Name = "internetGateway"
  }
}

# Create Elastic IP which is required for NatGateway 
resource "aws_eip" "elasticIP" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.elasticIP.id
  subnet_id     = aws_subnet.publicSubnet1.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# Create Route Table for Public and Private subnet
resource "aws_route_table" "publicRouteTable" {
    vpc_id = aws_vpc.ec2_private.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Public"
    }
  
}

resource "aws_route_table" "privateRouteTable" {
    vpc_id = aws_vpc.ec2_private.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Private"
    }
  
}

# Assoicate Subnets with these route tables
resource "aws_route_table_association" "publicAssociation1" {
  subnet_id = aws_subnet.publicSubnet1.id
  route_table_id = aws_route_table.publicRouteTable.id
}

resource "aws_route_table_association" "publicAssociation2" {
  subnet_id = aws_subnet.publicSubnet2.id
  route_table_id = aws_route_table.publicRouteTable.id
}

resource "aws_route_table_association" "privateAssociation1" {
    subnet_id = aws_subnet.privateSubnet1.id
    route_table_id = aws_route_table.privateRouteTable.id  
}
resource "aws_route_table_association" "privateAssociation2" {
    subnet_id = aws_subnet.privateSubnet2.id
    route_table_id = aws_route_table.privateRouteTable.id  
}

# create aws securtiy group 

resource "aws_security_group" "webserver" {
  vpc_id = aws_vpc.ec2_private.id
  name = "webserverSG"
  dynamic "ingress" {
    for_each = var.webserver_sg_rules.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.webserver_sg_rules.egress_rules
    content {
      description = egress.value.description
      from_port = egress.value.from_port
      to_port = egress.value.to_port
      protocol = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
  tags = {
    Name = "allow traffic"
  }
}

resource "aws_security_group" "alb" {
    name = "LoadbalancerSG"
    vpc_id = aws_vpc.ec2_private.id
    ingress {
        description = "allow traffice on port 80"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.webserver.id]
    }

    tags = {
      Name = "LoadBalancerSG"
    }
}

# Create AWS Launch template  to launch instance required for ASG
resource "aws_launch_template" "web_launch_temp" {
    name = "webserver"
    image_id = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_security_group_ids = [aws_security_group.webserver.id]
    tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "WebServer"
    }
  }

  user_data = filebase64("${path.module}/ec2.userdata")
  
}

# create application load balancer
resource "aws_lb" "alb" {
  name = "ec2Private"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]
  subnets = [aws_subnet.publicSubnet1.id, aws_subnet.publicSubnet2.id]
  enable_deletion_protection = false

  tags = {
    Environment = "Prod"
  }
}

# Create AWS ALB target group 
resource "aws_alb_target_group" "webserver" {
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.ec2_private.id
}

# Create aws alb listener who forwards the request to target group 
resource "aws_alb_listener" "frontend" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
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
  vpc_zone_identifier = [aws_subnet.privateSubnet1.id, aws_subnet.privateSubnet2.id]
  desired_capacity = 2
  max_size = 2
  min_size = 2
  target_group_arns = [aws_alb_target_group.webserver.arn]

  launch_template {
    id = aws_launch_template.web_launch_temp.id
    version = "$Latest"
  }
}



