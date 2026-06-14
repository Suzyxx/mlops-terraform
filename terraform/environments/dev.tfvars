environment = "dev"
aws_region  = "eu-west-1"

s3_buckets = [
  {
    key  = "mlops-course-shan-datastore"
    tags = {}
  }
]

ecr_repositories = [
  {
    key                  = "mlops-course-shan-repository"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration = {
      scan_on_push = true
    }
    tags = {}
  }
]

# App Runner deployment is fully defined in apprunner_services.tf +
# modules/apprunner-service/. It is left disabled (empty list via the variable
# default) because this AWS account is not subscribed to App Runner:
#   CreateService -> SubscriptionRequiredException.
# The config we WOULD use is preserved below for reference / the writeup.
# See NOTES.md (Lesson 4) for the explanation and the ECR-based fallback.
#
# apprunner_services = [
#   {
#     key = "mlops-course-shan-app"
#     source_configuration = {
#       image_repository = {
#         image_identifier      = "001277371466.dkr.ecr.eu-west-1.amazonaws.com/mlops-course-shan-repository-dev:latest"
#         image_repository_type = "ECR"
#         image_configuration = {
#           port = 80
#         }
#       }
#       auto_deployments_enabled = true
#     }
#     tags = {}
#   }
# ]
