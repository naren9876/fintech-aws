# FinTech Platform on AWS — Fully Automated CI/CD

Node.js auth-service deployed to **ECS Fargate** behind an **ALB**, with **RDS Postgres**
and **ElastiCache Redis** on a private-only network. Every change — application and
infrastructure — ships through GitHub Actions. Authentication is **keyless** (GitHub
OIDC → IAM role). No human runs a deploy command after the one-time bootstrap.

This is the AWS twin of the GCP fintech-platform deployment (Cloud Run + Cloud SQL +
Memorystore + WIF + Trivy + canary), carrying over every enterprise practice it proved.

## Architecture

```
Internet → ALB (public subnets) → ECS Fargate tasks (private subnets, no public IPs)
                                        │ port 5432          │ port 6379
                                   RDS Postgres 16      ElastiCache Redis (AUTH+TLS)
Secrets Manager → DATABASE_URL / REDIS_URL / JWT_SECRET injected at runtime
CloudWatch → dashboard, 5xx alarm → SNS
Terraform state → S3 (versioned+encrypted) + DynamoDB lock
CI identity → GitHub OIDC → github-actions-fintech role (trust locked to this repo)
```

## Pipelines

| Trigger | Pipeline | Stages |
|---|---|---|
| PR touching `terraform/**` | Terraform | fmt → validate → **plan posted as PR comment** (human reviews the plan, not the deploy) |
| Merge to main (`terraform/**`) | Terraform | saved-plan **apply** — executes exactly what was reviewed |
| Push to main (`app/**`) | App | npm test → docker build → **Trivy gate (CRITICAL/HIGH fail)** → push `:GIT_SHA` → new ECS task revision → wait stable (circuit breaker auto-rolls-back) → `/health` verification through the ALB |

## Rollout plan (each phase = one pull request)

| Phase | PR contents | Enables |
|---|---|---|
| 1 | Scaffold as-is (network module + ECR active) | VPC, subnets, SG chain, registry |
| — | Push any `app/` change | First image lands in ECR (deploy step skips gracefully) |
| 2 | Uncomment `secrets`, `rds`, `elasticache` in `main.tf` (+outputs) | Data layer, private-only |
| 3 | Uncomment `ecs` module (+`alb_dns_name` output) | Live service; app pipeline now deploys end-to-end |
| 4 | Uncomment `monitoring` module | Dashboard + alarms |
| 5 | Hardening (future): CodeDeploy canary traffic-shifting, least-privilege CI policy, HTTPS via ACM | Full enterprise parity |

## One-time bootstrap (already executed)

`bootstrap/bootstrap.sh` — state bucket, lock table, OIDC provider, CI role.
The role ARN lives in GitHub → Settings → Actions → **Variables** → `AWS_ROLE_ARN`.

## Lessons from previous sprints, baked in

- DB password: `special = false` → URL-safe (the `%8s` incident)
- `skip_final_snapshot = true`, ECR `force_delete = true`, secrets `recovery_window = 0` → destroys never block (the teardown battles)
- Postgres `engine_version = "16"` floating minor (the retired-16.1 incident)
- Images pinned by git SHA — `latest` exists only to bootstrap the first task definition (the forgotten-`docker tag` incident)
- `sslmode=no-verify` in DATABASE_URL — RDS Postgres 16 forces SSL (prod: `verify-full` + RDS CA)
- ECS service `ignore_changes = [task_definition]` — Terraform and the app pipeline never fight (the GCP state-drift lesson)
- Shared resources live at the root; plans are contracts — read every one before merge (the GCP VPC near-destroy)

## Costs (dev sizing)

Roughly $4–6/day while Phase 3+ is applied (ALB + NAT + RDS t3.micro + cache.t3.micro
+ 2 Fargate tasks). Tear down by opening a PR that comments the modules back out —
or `terraform destroy -var-file=environments/dev.tfvars` locally in a pinch.
