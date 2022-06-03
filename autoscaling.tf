//IAM Roles and Policy
resource "aws_iam_role" "ecs-autoscale-role" {
 name = "ecs-scale-application"

 assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "application-autoscaling.amazonaws.com"
     },
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-autoscale" {
 role       = aws_iam_role.ecs-autoscale-role.id
 policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
 depends_on = [
   aws_iam_role.ecs-autoscale-role
 ]
}

resource "aws_appautoscaling_target" "target" {
 service_namespace  = "ecs"
 resource_id        = "service/${aws_ecs_cluster.grafana.name}/${aws_ecs_service.grafana.name}"
 scalable_dimension = "ecs:service:DesiredCount"
 role_arn           = aws_iam_role.ecs-autoscale-role.arn
 min_capacity       = 3
 max_capacity       = 6
}

// Automatically scale capacity up by one
resource "aws_appautoscaling_policy" "up" {
 name               = "cb_scale_up"
 service_namespace  = "ecs"
 resource_id        = "service/${aws_ecs_cluster.grafana.name}/${aws_ecs_service.grafana.name}"
 scalable_dimension = "ecs:service:DesiredCount"

 step_scaling_policy_configuration {
   adjustment_type         = "ChangeInCapacity"
   cooldown                = 60
   metric_aggregation_type = "Maximum"

   step_adjustment {
     metric_interval_lower_bound = 0
     scaling_adjustment          = 1
   }
 }

 depends_on = [aws_appautoscaling_target.target]
}

// Automatically scale capacity down by one
resource "aws_appautoscaling_policy" "down" {
 name               = "cb_scale_down"
 service_namespace  = "ecs"
 resource_id        = "service/${aws_ecs_cluster.grafana.name}/${aws_ecs_service.grafana.name}"
 scalable_dimension = "ecs:service:DesiredCount"

 step_scaling_policy_configuration {
   adjustment_type         = "ChangeInCapacity"
   cooldown                = 60
   metric_aggregation_type = "Maximum"

   step_adjustment {
     metric_interval_lower_bound = 0
     scaling_adjustment          = -1
   }
 }

 depends_on = [aws_appautoscaling_target.target]
}

// CloudWatch alarm that triggers the autoscaling up policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
 alarm_name          = "cb_cpu_utilization_high"
 comparison_operator = "GreaterThanOrEqualToThreshold"
 evaluation_periods  = "2"
 metric_name         = "CPUUtilization"
 namespace           = "AWS/ECS"
 period              = "60"
 statistic           = "Average"
 threshold           = "85"

 dimensions = {
   ClusterName = aws_ecs_cluster.grafana.id
   ServiceName = aws_ecs_service.grafana.id
 }

 alarm_actions = [aws_appautoscaling_policy.up.arn]
}

// CloudWatch alarm that triggers the autoscaling down policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_low" {
 alarm_name          = "cb_cpu_utilization_low"
 comparison_operator = "LessThanOrEqualToThreshold"
 evaluation_periods  = "2"
 metric_name         = "CPUUtilization"
 namespace           = "AWS/ECS"
 period              = "60"
 statistic           = "Average"
 threshold           = "10"

 dimensions = {
   ClusterName = aws_ecs_cluster.grafana.id
   ServiceName = aws_ecs_service.grafana.id
 }

 alarm_actions = [aws_appautoscaling_policy.down.arn]
}

// Set up CloudWatch group and log stream and retain logs for 30 days
resource "aws_cloudwatch_log_group" "grafana_log_group" {
 name              = "/ecs/cb-app"
 retention_in_days = 30

 tags = {
   Name = "cb-log-group"
 }
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
 name           = "cb-log-stream"
 log_group_name = aws_cloudwatch_log_group.grafana_log_group.name
}

