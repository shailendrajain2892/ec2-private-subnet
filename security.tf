
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