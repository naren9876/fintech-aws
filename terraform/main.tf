terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "naren9876/fintech-aws"
    }
  }
}

# ============================================================
# PHASE 1 - Foundation: network + container registry
# ============================================================

module "network" {
  source = "./modules/network"

  project_name   = var.project_name
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  container_port = var.container_port
}

resource "aws_ecr_repository" "auth_service" {
  name                 = "${var.project_name}-auth-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # dev convenience; lesson from the msp-loyalty teardown

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "auth_service" {
  repository = aws_ecr_repository.auth_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ============================================================
# PHASE 2 - Data layer: Postgres + Redis + app secrets
# (uncomment in the Phase 2 pull request)
# ============================================================

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  db_name           = var.db_name
  db_username       = var.db_username
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.db_security_group_id
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.redis_security_group_id
}

# ============================================================
# PHASE 3 - Compute: ECS Fargate service + ALB
# (uncomment in the Phase 3 pull request)
# ============================================================

module "ecs" {
  source = "./modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  container_port     = var.container_port
  ecr_repository_url = aws_ecr_repository.auth_service.repository_url

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  app_security_group_id = module.network.app_security_group_id

  database_url_secret_arn = module.rds.database_url_secret_arn
  redis_url_secret_arn    = module.elasticache.redis_url_secret_arn
  jwt_secret_arn          = module.secrets.jwt_secret_arn
}

# ============================================================
# PHASE 4 - Observability: dashboard + alarms
# (uncomment in the Phase 4 pull request)
# ============================================================

module "monitoring" {
  source = "./modules/monitoring"
  #
  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region
  alert_email    = var.alert_email
  alb_arn_suffix = module.ecs.alb_arn_suffix
  cluster_name   = module.ecs.cluster_name
  service_name   = module.ecs.service_name
}
