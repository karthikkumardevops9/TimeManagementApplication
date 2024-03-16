################################################################################
# Load Balancer
################################################################################


output "id" {
  description = "The ID and ARN of the load balancer we created"
  value       = aws_lb.ecs_alb.id
}


output "arn" {
  description = "The ID and ARN of the load balancer we created"
  value       = aws_lb.ecs_alb.arn
}


output "arn_suffix" {
  description = "ARN suffix of our load balancer - can be used with CloudWatch"
  value       = aws_lb.ecs_alb.arn_suffix
}


output "dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.ecs_alb.dns_name
}


output "zone_id" {
  description = "The zone_id of the load balancer to assist with creating DNS records"
  value       = aws_lb.ecs_alb.zone_id
}
