# Cloudride Assignment

A "Hello World" web container on AWS ECS Fargate behind an Application Load
Balancer, defined as Terraform and shipped through GitHub Actions. Region:
`us-east-1`.

## Design decisions

Two deliberate departures from the "textbook production" setup.

### VPC Endpoints — considered, not implemented

The ECS tasks run in private subnets and reach AWS APIs (ECR, CloudWatch Logs, SSM
for ECS Exec) through the **NAT Gateway → Internet Gateway** path. VPC Endpoints
would keep those calls inside the VPC — cheaper (a NAT Gateway bills hourly *and*
per GB) and more private (traffic never leaves the VPC).

Not implemented because:

1. The image is pulled from **Docker Hub, not ECR**. Endpoints only cover AWS
   services, so the Docker Hub pull still needs the NAT — it can't be removed
   without first moving the image to ECR.
2. Interface endpoints are billed ENIs (~$0.01/hr each + data). At this scale they
   cost *more* than the single NAT they'd partially offload.

In production (image in ECR, steady traffic) I'd add the free S3 gateway endpoint
plus interface endpoints and drop the NAT Gateway.

### Hand-written VPC vs. `terraform-aws-modules/vpc/aws`

[terraform/network.tf](terraform/network.tf) writes the VPC out resource by
resource. The production-standard alternative is the HashiCorp-verified
[`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
module, which collapses subnets/NAT/route tables into one list-driven block and
makes adding an AZ a one-line change.

The explicit version is kept here because the module hides the mechanics. Writing
the resources out shows how the pieces wire together (route table associations,
NAT placement in a public subnet, the IGW dependency) — the point of the exercise.
In production I'd use the module.
