output "vpcid" {
  value = aws_vpc.ec2_private.id
}

output "publicSubnetIds" {
  value = aws_subnet.publicSubnet.*.id
}

output "privateSubnetIds" {
  value = aws_subnet.privateSubnet.*.id
}

output "alb_dns_name" {
  description = "alb dns"
  value       = aws_lb.alb.dns_name
}

output "web_app_wait_command" {
  value       = "until curl -is --max-time 5 http://${aws_lb.alb.dns_name} | grep '200 OK'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready!!'"
  description = "Test command - tests readiness of the web app"
}

output "Bastion_IP" {
  value = aws_instance.BastionHost.public_ip
}
