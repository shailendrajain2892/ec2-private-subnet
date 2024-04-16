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

#==============

resource "aws_route_table" "privateRouteTable" {
  vpc_id = aws_vpc.ec2_private.id
  count  = length(var.availability_zone)

  tags = {
    Name = "Private: ${element(var.availability_zone, count.index)}"
  }

}

resource "aws_route" "private_nat_gateway" {
  count                  = length(var.availability_zone)
  route_table_id         = element(aws_route_table.privateRouteTable.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
}




resource "aws_route_table_association" "privateAssociation1" {
  count          = var.instance_count
  subnet_id      = element(aws_subnet.privateSubnet.*.id, count.index)
  route_table_id = element(aws_route_table.privateRouteTable.*.id, count.index)
}
