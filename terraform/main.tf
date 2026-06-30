resource "aws_security_group" "alb" {
  name   = "hello-alb"
  vpc_id = aws_vpc.lab.id

  ingress {
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
}

# Tasks: only accept traffic from the ALB
resource "aws_security_group" "service" {
  name   = "hello-service"
  vpc_id = aws_vpc.lab.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_ecs_cluster" "this" {
  name = "hello-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "hello"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name      = "hello"
      image     = var.container_image
      essential = true
      portMappings = [
        { containerPort = 80 }
      ]
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "hello-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true # needed to pull the image (no NAT yet)
  }

}
