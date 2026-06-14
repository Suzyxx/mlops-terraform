# Reusable building block: "how we run one container as a managed service."
# App Runner pulls an image from ECR, runs it, gives us a public HTTPS URL, and
# handles scaling/TLS for us — no servers to manage. The caller passes the image
# location + port in.
resource "aws_apprunner_service" "ars" {
  service_name = var.name

  source_configuration {
    # App Runner is a separate AWS service, so it must assume a role that is
    # allowed to read from our PRIVATE ECR repo (defined below).
    authentication_configuration {
      access_role_arn = aws_iam_role.iamr.arn
    }

    image_repository {
      image_identifier      = var.source_configuration.image_repository.image_identifier
      image_repository_type = var.source_configuration.image_repository.image_repository_type
      image_configuration {
        # The port our FastAPI app listens on inside the container (80).
        port = var.source_configuration.image_repository.image_configuration.port
      }
    }

    # When a new image is pushed to that ECR tag, App Runner redeploys itself.
    auto_deployments_enabled = var.source_configuration.auto_deployments_enabled
  }

  tags = var.tags
}

# The identity App Runner assumes. The "build.apprunner.amazonaws.com" principal
# is App Runner's image-pulling service — this role exists so it can fetch from ECR.
resource "aws_iam_role" "iamr" {
  name = "${var.name}-ars-iam-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "build.apprunner.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Grant that role AWS's ready-made managed policy for reading images from ECR.
resource "aws_iam_role_policy_attachment" "iamrpa" {
  role       = aws_iam_role.iamr.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}
