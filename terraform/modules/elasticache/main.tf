# Redis with AUTH + in-transit encryption (mirrors the GCP Memorystore AUTH setup).
# The ready-made rediss:// URL (TLS scheme) is stored in Secrets Manager;
# node-redis v4 handles TLS automatically for rediss:// URLs.

resource "random_password" "auth_token" {
  length  = 32
  special = false # Redis AUTH token: alphanumeric keeps it URL-safe too
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Cache and session store for ${var.project_name}"

  engine             = "redis"
  engine_version     = "7.1"
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1
  port               = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.security_group_id]

  auth_token                 = random_password.auth_token.result
  transit_encryption_enabled = true # required for AUTH
  at_rest_encryption_enabled = true

  automatic_failover_enabled = false # single node in dev

  tags = { Name = "${var.project_name}-${var.environment}-redis" }
}

resource "aws_secretsmanager_secret" "redis_url" {
  name                    = "${var.project_name}-${var.environment}-redis-url"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = "rediss://:${random_password.auth_token.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:6379"
}
