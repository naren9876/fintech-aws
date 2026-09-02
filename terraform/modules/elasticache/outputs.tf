output "endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_url_secret_arn" {
  value = aws_secretsmanager_secret.redis_url.arn
}
