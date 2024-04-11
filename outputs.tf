output "vpcid" {
  value = aws_vpc.ec2_private.id
}

output "publicSubnet1Id" {
  value = aws_subnet.publicSubnet1.id
}

output "publicSubnet2Id" {
  value = aws_subnet.publicSubnet2.id
}

output "privateSubnet1Id" {
  value = aws_subnet.privateSubnet1.id
}

output "privateSubnet2Id" {
  value = aws_subnet.privateSubnet2.id
}

output "alb_dns_name" {
  description = "alb dns"
  value       = aws_lb.alb.dns_name
}

output "web_app_wait_command" {
  value       = "until curl -is --max-time 5 http://${aws_lb.alb.dns_name} | grep '200 OK'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready!!'"
  description = "Test command - tests readiness of the web app"
}