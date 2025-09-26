###################
# Auto Scaling Configuration for ECS Service
###################

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.screenshot_processing.name}/${aws_ecs_service.screenshot_processor.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name        = "${var.project}-${var.env}-ecs-autoscaling"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

###################
# CPU-Based Auto Scaling Policy
###################

resource "aws_appautoscaling_policy" "ecs_cpu_scaling" {
  name               = "${var.project}-${var.env}-ecs-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

###################
# SQS-Based Auto Scaling Policy
###################

resource "aws_appautoscaling_policy" "ecs_sqs_scaling" {
  name               = "${var.project}-${var.env}-ecs-sqs-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 10.0 # Target 10 messages per task

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = aws_sqs_queue.screenshot_processing.name
      }
    }
  }
}
