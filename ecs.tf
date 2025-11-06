resource "aws_ecs_cluster" "this" { name = "fullstack-cluster" }

data "aws_iam_policy_document" "task" {
  statement { actions = ["logs:CreateLogStream","logs:PutLogEvents","logs:CreateLogGroup"] resources = ["*"] }
}
resource "aws_iam_role" "task_role" {
  name = "fullstack-task-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect="Allow", Principal={ Service="ecs-tasks.amazonaws.com" }, Action="sts:AssumeRole" }] })
}
resource "aws_iam_role" "task_exec_role" {
  name = "fullstack-task-exec-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect="Allow", Principal={ Service="ecs-tasks.amazonaws.com" }, Action="sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "task_exec_logs" {
  name = "task-exec-logs"
  role = aws_iam_role.task_exec_role.name
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_cloudwatch_log_group" "api" { name = "/ecs/fullstack-api" retention_in_days = 14 }

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}
resource "aws_security_group" "svc" {
  name   = "svc-sg"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 3000 to_port = 3000 protocol = "tcp" security_groups = [aws_security_group.alb.id] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_lb" "this" {
  name = "fullstack-alb"
  load_balancer_type = "application"
  subnets = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
}
resource "aws_lb_target_group" "api" {
  name     = "tg-api"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check { path = "/health" interval = 30 timeout = 5 healthy_threshold = 2 unhealthy_threshold = 2 }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port = 80
  protocol = "HTTP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.api.arn }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "fullstack-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_exec_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions    = jsonencode([
    {
      name = "api"
      image = "${aws_ecr_repository.api.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.api.name, awslogs-region = "ap-south-1", awslogs-stream-prefix = "ecs" } }
      environment = [{ name="NODE_ENV", value="production" }]
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "api-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    assign_public_ip = false
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.svc.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }
  depends_on = [aws_lb_listener.http]
}
