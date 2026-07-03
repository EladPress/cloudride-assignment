output "alb_url" {
  value = "http://${aws_lb.this.dns_name}"
}

output "connect_command" {
  description = "Opens a shell in one of the running tasks' containers (needs the Session Manager plugin)"
  value = join(" ", [
    "aws ecs execute-command --region us-east-1",
    "--cluster ${aws_ecs_cluster.this.name}",
    "--container cloudride --interactive --command /bin/sh",
    "--task {TASK_ID}",
  ])
}
