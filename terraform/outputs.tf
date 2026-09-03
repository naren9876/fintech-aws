# ---- Phase 1 outputs ----

output "vpc_id" {
  value = module.network.vpc_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.auth_service.repository_url
}

# ---- Phase 2 outputs (uncomment with the Phase 2 PR) ----

output "database_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}
output "redis_endpoint" {
  value     = module.elasticache.endpoint
  sensitive = true
}

# ---- Phase 3 outputs (uncomment with the Phase 3 PR) ----

output "alb_dns_name" {
  description = "Public URL of the service"
  value       = module.ecs.alb_dns_name
}
