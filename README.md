# ec2-private-subnet
Ec2 deployed in private subnet in multi availability zone with ASG and ALB 

![AWS Architecture](./AWS-VPC-ASG-Nginx.png)

#### Project Structure

```
├── userdata.tpl
├── alb_asg.tf
|-- data.tf
|-- network.tf
|-- provider.tf
|-- security.tf
|-- variables.tf
|-- vpc.tf
├── outputs.tf
├── terraform.tfvars
└── variables.tf
```