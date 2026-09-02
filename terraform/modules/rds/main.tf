# Lessons from the msp-loyalty sprint baked in:
#   - special = false          -> no URL-breaking characters in the password (the %8s incident)
#   - skip_final_snapshot=true -> destroy never blocks asking for a snapshot name (dev only)
#   - engine_version = "16"    -> floating minor, AWS picks a supported 16.x (the retired-16.1 incident)
#   - the ready-made DATABASE_URL lives in Secrets Manager -> app reads it at runtime, nothing in git
#   - sslmode=no-verify        -> RDS Postgres 16 forces SSL by default; node-pg honors sslmode in the URL
#                                 (production hardening: verify-full with the RDS CA bundle)

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage   = 20
  storage_encrypted   = true
  multi_az            = false
  publicly_accessible = false

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project_name}-${var.environment}-db" }
}

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.project_name}-${var.environment}-database-url"
  recovery_window_in_days = 0 # dev: allow immediate recreate on destroy/apply cycles
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=no-verify"
}
