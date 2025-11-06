# terraform-ecs-alb-stack

ECS Fargate service behind an Application Load Balancer.

## Prereqs
awscli, terraform, docker, ECR repo exists or created by this stack.

## Build and push image
aws ecr get-login-password | docker login --username AWS --password-stdin <acct>.dkr.ecr.ap-south-1.amazonaws.com
docker build -t fullstack-api:latest .
docker tag fullstack-api:latest <acct>.dkr.ecr.ap-south-1.amazonaws.com/fullstack-api:latest
docker push <acct>.dkr.ecr.ap-south-1.amazonaws.com/fullstack-api:latest

## Deploy
terraform init
terraform apply

## Notes
Replace domain and zone id in ssl-dns.tf if using HTTPS. Add a 443 listener referencing the validated certificate.
