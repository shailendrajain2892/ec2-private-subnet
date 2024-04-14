
# Create a VPC
resource "aws_vpc" "ec2_private" {
  cidr_block = var.cidr_block

  tags = {
    Name = "ec2-private"
  }
}