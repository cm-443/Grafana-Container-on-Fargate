//Grafana Container Running on a Fargate Cluster

//Provider
provider "aws" {
 region = "us-east-1"
}

terraform {
 required_providers {
   aws = {
     source = "hashicorp/aws"

   }
 }
}

//Grafana Application Security Group
resource "aws_security_group" "grafana" {
 name        = "grafana"
 description = "Grafana Application Security Group"
 vpc_id      = var.vpc_id

 ingress {
   description     = "Allows the load balancer to access Grafana"
   from_port       = 0
   to_port         = 65535
   protocol        = "tcp"
   security_groups = [aws_security_group.grafana-lb-sec.id]
 }

 egress {
   from_port        = 0
   to_port          = 0
   protocol         = "-1"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }

 tags = {
   Name = "grafana"
 }

 depends_on = [
   aws_security_group.grafana-lb-sec
 ]

}

//Load Balancer Security Group
resource "aws_security_group" "grafana-lb-sec" {
 name        = "grafana-lb-sec"
 description = "Grafana Load Balancer Sec Group"
 vpc_id      = var.vpc_id


 ingress {
   description = "HTTP ingress rule"
   from_port   = 80
   to_port     = 80
   protocol    = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
 }

 ingress {
   description = "HTTPS ingress rule"
   from_port   = 443
   to_port     = 443
   protocol    = "TCP"
   cidr_blocks = ["0.0.0.0/0"]
 }

 egress {
   from_port        = 0
   to_port          = 0
   protocol         = "-1"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }
}

//ECS Cluster
resource "aws_ecs_cluster" "grafana" {
 name = "grafana"
}

//Task Definition
resource "aws_ecs_task_definition" "grafana" {
 family                   = "grafana"
 requires_compatibilities = ["FARGATE"]
 network_mode             = "awsvpc"
 cpu                      = "256"
 memory                   = "512"

 container_definitions = <<DEFINITION
[
 {
   "name": "grafana",
   "image": "grafana/grafana:latest",
   "essential": true,
   "portMappings": [
     {
       "containerPort": 3000,
       "hostPort": 3000
     }
   ]
 }
]
DEFINITION
}

//ECS Service
resource "aws_ecs_service" "grafana" {
 name                              = "grafana"
 cluster                           = aws_ecs_cluster.grafana.id
 task_definition                   = aws_ecs_task_definition.grafana.arn
 desired_count                     = 1
 health_check_grace_period_seconds = 300
 network_configuration {
   subnets          = var.subnets
   security_groups  = [aws_security_group.grafana.id, aws_security_group.grafana-two.id]
   assign_public_ip = true
 }
 load_balancer {
   target_group_arn = aws_lb_target_group.grafana-test-tg.arn
   container_name   = "grafana"
   container_port   = 3000
 }
 launch_type      = "FARGATE"
 platform_version = "1.4.0"
}

//Load Balancer
resource "aws_lb" "grafana-lb" {
 name                       = "grafana-lb"
 internal                   = false
 load_balancer_type         = "application"
 security_groups            = [aws_security_group.grafana-lb-sec.id]
 subnets                    = var.subnets
 enable_deletion_protection = false
}

//Load Balancer Listener HTTP
resource "aws_lb_listener" "grafana-test-l" {
 load_balancer_arn = aws_lb.grafana-lb.arn
 port              = "80"
 protocol          = "HTTP"


 default_action {
   type = "redirect"

   redirect {
     port        = "443"
     protocol    = "HTTPS"
     status_code = "HTTP_301"
   }
 }
}

//Load Balancer Listener HTTPS
resource "aws_lb_listener" "grafana-test-l-https" {
 load_balancer_arn = aws_lb.grafana-lb.arn
 port              = "443"
 protocol          = "HTTPS"
 depends_on        = [aws_lb_target_group.grafana-test-tg]
 certificate_arn   = var.certificate_arn

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.grafana-test-tg.id
 }
}

//Target Group
resource "aws_lb_target_group" "grafana-test-tg" {
 name        = "tf-example-lb-tg"
 port        = 80
 protocol    = "HTTP"
 target_type = "ip"
 vpc_id      = var.vpc_id

 health_check {
   matcher = "200,302"
 }
}

//DNS Alias Record
resource "aws_route53_record" "record-one" {
 zone_id = var.zone_id
 name    = var.name
 type    = "A"

 alias {
   name                   = aws_lb.grafana-lb.dns_name
   zone_id                = aws_lb.grafana-lb.zone_id
   evaluate_target_health = true
 }
 depends_on = [
   aws_lb.grafana-lb
 ]
}




