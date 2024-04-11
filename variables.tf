variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "webserver_sg_rules" {
  type = object({
    ingress_rules = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress_rules = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  })
  default = {
    ingress_rules = [
      {
        description = "SSH from management workstation"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["147.161.166.209/32"] # <- replace with your own workstation IP
      },
      {
        description = "80 from public subnets (ALB)"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
      },
    ]
    egress_rules = [
      {
        description = "All outbound internet traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  default = "allow_ssh"
}

variable "availability_zone" {
  type = list(string)
  default = [ "us-east-1a", "us-east-1b" ]
}