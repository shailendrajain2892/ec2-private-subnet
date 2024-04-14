
# Create a VPC
resource "aws_vpc" "ec2_private" {
  cidr_block = var.cidr_block

  tags = {
    Name = "ec2-private"
  }
}
#=========================================
# Create Public and Private Subnet
resource "aws_subnet" "publicSubnet" {
  count                   = var.instance_count
  vpc_id                  = aws_vpc.ec2_private.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet: ${element(var.availability_zone, count.index)}"
    Type = "Public"
  }
}


resource "aws_subnet" "privateSubnet" {
  vpc_id                  = aws_vpc.ec2_private.id
  count                   = var.instance_count
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index + length(var.availability_zone))
  availability_zone       = element(var.availability_zone, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "private Subnet: ${element(var.availability_zone, count.index)}"
    Type = "Private"
  }
}
#========================================
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
  count  = length(var.availability_zone)
}

resource "aws_nat_gateway" "ngw" {
  count         = length(var.availability_zone)
  allocation_id = element(aws_eip.elasticIP.*.id, count.index)
  subnet_id     = element(aws_subnet.publicSubnet.*.id, count.index)


  tags = {
    Name = "NAT: ${element(var.availability_zone, count.index)}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# Create Route Table for Public and Private subnet
resource "aws_route_table" "publicRouteTable" {
  vpc_id = aws_vpc.ec2_private.id

  tags = {
    Name = "Public"
  }

}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.publicRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Assoicate Subnets with these route tables
resource "aws_route_table_association" "publicAssociation" {
  count          = var.instance_count
  subnet_id      = element(aws_subnet.publicSubnet.*.id, count.index)
  route_table_id = aws_route_table.publicRouteTable.id
}


resource "aws_route_table" "privateRouteTable" {
  vpc_id = aws_vpc.ec2_private.id
  count  = length(var.availability_zone)

  tags = {
    Name = "Private: ${element(var.availability_zone, count.index)}"
  }

}

resource "aws_route" "private_nat_gateway" {
  count = length(var.availability_zone)
  route_table_id = element(aws_route_table.privateRouteTable.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = element(aws_nat_gateway.ngw.*.id, count.index)
}




resource "aws_route_table_association" "privateAssociation1" {
  count          = var.instance_count
  subnet_id      = element(aws_subnet.privateSubnet.*.id, count.index)
  route_table_id = element(aws_route_table.privateRouteTable.*.id, count.index)
}

# create aws securtiy group 

resource "aws_security_group" "SGPublic" {
  name   = "security_group_public"
  vpc_id = aws_vpc.ec2_private.id
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "80 from anywhere"
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
    Name = "SGPublic"
  }
}


resource "aws_security_group" "webserver" {
  vpc_id = aws_vpc.ec2_private.id
  name   = "webserverSG"
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.SGPublic.id]
  }

  ingress {
    description = "80 from public subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      #10.0.0.0/23 covers both pubic subnets
      cidrsubnet(var.cidr_block, 7, 0)
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow traffic"
  }
}

resource "aws_security_group" "alb" {
  name   = "LoadbalancerSG"
  vpc_id = aws_vpc.ec2_private.id
  ingress {
    description = "allow traffice on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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


