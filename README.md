# Cloudride Assignment

A "Hello World" web container on AWS ECS Fargate behind an Application Load
Balancer, defined as Terraform and shipped through GitHub Actions. Region:
`us-east-1`.

## AWS Infrastructure design

This project deploys an ECS service that deploys a minimum of 2 tasks and a maximum of 4 (depends on average CPU usage), spread across 2 AZs in the us-east-1 region.

For every AZ exists a public and a private subnet. The ecs service itself exists in the private subnet with a security group that limits inbound requests to port 80 only. The private subnets' route table routes all requests destined outside of the VPC to the VPC's NAT Gateway which then routes the requests into the VPC's Internet Gateway

The Application Load Balancer sits in the public subnets and is the only entry point from the internet. It listens on port 80 and forwards to a target group of the running tasks.

Tasks have ECS Exec enabled, which opens an interactive shell into a running container over AWS SSM — no SSH, bastion, or public IP needed. The task role carries the `AmazonSSMManagedInstanceCore` policy, and the SSM traffic follows the same NAT Gateway path out.

## CI/CD

[.github/workflows/ci.yml](.github/workflows/ci.yml) runs on every push. The
**build-and-push** job builds the image and pushes it to Docker Hub
tagged `branch-buildnumber`. On `main`, the **deploy** job renders that image into
the live task definition and rolls it out with
`amazon-ecs-deploy-task-definition`.

Deployments are **zero-downtime**: ECS starts the new tasks, waits for them to pass
the ALB health check, shifts traffic, then drains the old ones. Terraform owns the
task definition and desired count (`ignore_changes`), so the pipeline updates the
image without Terraform reverting it.

## Monitoring

Container logs ship to the `/ecs/cloudride` CloudWatch log group (14-day
retention). Three CloudWatch alarms notify an SNS topic (email subscriber set via
`alert_email`):

- **Unhealthy hosts** — fewer than 2 healthy targets
- **Target 5XX** — more than 5 backend 5xx responses in a minute
- **CPU high** — service CPU above 85% (sustained)

## Auto scaling

The service runs 2–4 tasks behind a target-tracking policy that holds average CPU
at 70% — it scales out when tasks run hot and back in when they cool, never below
the floor of 2.

## AWS Well-Architected

- **Reliability** — 2 AZs, auto scaling with a floor of 2 tasks, ALB health checks.
- **Security** — tasks in private subnets with no public IP; SG only allows the
  ALB; shell access is IAM-gated ECS Exec over SSM, no SSH or bastion.
- **Performance** — CPU target-tracking auto scaling (2–4 tasks).
- **Cost** — Fargate (no idle EC2), a single NAT Gateway, short log retention.
- **Best Practices** — everything is Terraform + a CI/CD pipeline; alarms
  page over SNS.

## Running it

For the CI to run, it needs the following variables:
DOCKERHUB_USERNAME and DOCKERHUB_TOKEN for pushing and pulling the Docker image, and:
AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for accessing AWS.

Needs Terraform and AWS credentials for `us-east-1`. All variables have defaults,
so:

```bash
cd terraform
terraform init
terraform apply
```

Set `alert_email` to receive the CloudWatch alarm notifications (and confirm the
SNS subscription email). The app URL is the `alb_url` output.

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


### Hand-written VPC vs. `terraform-aws-modules/vpc/aws`

[terraform/network.tf](terraform/network.tf) writes the VPC out resource by
resource. The production-standard alternative is the 
[`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
module, which collapses subnets/NAT/route tables into one list-driven block and
makes adding an AZ a one-line change.

The explicit version is kept here because the module hides the mechanics. Writing
the resources out shows how the pieces wire together (route table associations,
NAT placement in a public subnet, the IGW dependency) — the point of the exercise.
In production I'd use the module.
