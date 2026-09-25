# mlops-terraform

An end-to-end MLOps project that takes a scikit-learn insurance cross-sell classifier from raw data to a deployable, containerized API, with every layer declared as code and versioned in git. It was built across four lessons that progressively add reproducible infrastructure, data management, and model deployment.

The guiding idea throughout: **declare as code, version in git, reproduce anywhere**, whether the thing being managed is infrastructure, data, environments, or deployments.

## What the model does

A binary classifier that predicts whether an insurance customer is likely to be interested in a vehicle insurance policy, based on features such as age, region, driving licence status, past accidents, and annual premium. The model is served behind a FastAPI `/predict` endpoint.

## Tech stack

| Layer | Tools |
|-------|-------|
| Infrastructure as Code | Terraform (AWS provider), remote S3 backend with state locking |
| Cloud (AWS) | S3, ECR, App Runner |
| ML pipeline | Python, scikit-learn, pandas, imbalanced-learn |
| Data versioning | DVC (S3 remote) |
| Experiment tracking | MLflow (tracking + model registry) |
| Serving | FastAPI, Uvicorn |
| Packaging | Docker |
| CI/CD | GitHub Actions (with a manual approval gate on infrastructure) |

## Repository structure

```
mlops-terraform/
├── terraform/                     # Infrastructure as Code
│   ├── provider.tf                # AWS provider + S3 remote backend
│   ├── variables.tf               # Root input variables
│   ├── s3_buckets.tf              # Datastore + backend buckets
│   ├── ecr_repositories.tf        # Container registry
│   ├── apprunner_services.tf      # App Runner service (see note in Lesson 4)
│   ├── outputs.tf
│   ├── environments/              # Per-stage variable files: dev / tst / prd
│   ├── backends/                  # Per-stage remote backend configs
│   └── modules/                   # Reusable modules: s3-bucket, ecr-repository, apprunner-service
│
├── src/                           # ML application
│   ├── config.yml                 # Pipeline + model configuration
│   ├── main.py                    # Runs the full pipeline (plus an MLflow-tracked variant)
│   ├── app.py                     # FastAPI serving app
│   ├── pipelines/                 # ingest -> clean -> train -> predict stages
│   ├── data.dvc                   # DVC pointer to the versioned dataset
│   ├── requirements.txt
│   └── Dockerfile
│
├── .github/workflows/
│   ├── infra-cicd-dev.yml         # Terraform plan/apply on terraform/** changes (approval gated)
│   └── app-cicd-dev.yml           # Retrain, build, and push the image on src/** changes
│
└── NOTES.md                       # Extended lesson-by-lesson write-up of the how and why
```

## Prerequisites

- Python 3.13
- Terraform 1.x with the AWS provider (>= 5.97)
- An AWS account with credentials configured, and permission for S3, ECR, and App Runner
- Docker
- DVC with S3 support (installed via `requirements.txt`)

## Getting started

### 1. Run the ML pipeline locally

```bash
cd src
pip install -r requirements.txt
dvc pull                 # fetch the versioned dataset from the S3 remote
python main.py           # ingest -> clean -> train -> evaluate, writes models/model.pkl
```

This prints the model, accuracy, and ROC AUC score. The model to train is selected in `config.yml` (Decision Tree by default; Random Forest and Gradient Boosting are provided as commented alternatives).

### 2. Track experiments with MLflow (optional)

`main.py` includes an MLflow-tracked variant of the pipeline that logs parameters and metrics, saves the model artifact, and registers a new version in the MLflow Model Registry. After a tracked run, view the experiments with:

```bash
mlflow ui --backend-store-uri sqlite:///mlflow.db
```

### 3. Serve the model as an API

```bash
cd src
uvicorn app:app --host 0.0.0.0 --port 80
```

Endpoints:
- `GET /` returns a health check.
- `POST /predict` accepts the customer features as JSON and returns the predicted class.

### 4. Build and run the container

```bash
cd src
docker build --provenance=false -t insurance-model .
docker run -p 80:80 insurance-model
```

> The `--provenance=false` flag keeps the build a plain single-platform manifest so that ECR's scan-on-push can read it. A buildx OCI image index cannot be scanned.

### 5. Provision the infrastructure

Terraform is configured per environment (`dev`, `tst`, `prd`). Each stage has its own backend config and variable file.

```bash
cd terraform
terraform init -backend-config='backends/dev.conf'
terraform validate
terraform plan  --var-file='environments/dev.tfvars'
terraform apply --var-file='environments/dev.tfvars'
```

## CI/CD

Two GitHub Actions workflows keep infrastructure and application changes separate, each triggered only when its own files change:

- **`infra-cicd-dev.yml`** runs on pull requests that touch `terraform/**`. It runs `fmt`, `init`, `validate`, and `plan`, then pauses on a **manual approval gate** before `apply`, so no infrastructure change reaches AWS without a human review of the plan.
- **`app-cicd-dev.yml`** runs on pull requests that touch `src/**`. It pulls the versioned data with DVC, retrains the model, then builds and pushes the container image to ECR. There is no approval gate here, since it only ships a new application image.

## Lessons overview

1. **Infrastructure as Code with Terraform.** Provision AWS resources through Terraform rather than manual console clicks, for reproducibility and version control. The workflow is `init` then `validate` then `fmt` then `plan` then `apply`.
2. **Scaling IaC.** Move state to a remote S3 backend with locking and versioning, factor resources into reusable modules, add per-environment configuration, and automate deployments with an approval gate.
3. **Data versioning and containerization.** A modular pipeline (ingest, clean, train, predict) driven by config, DVC for content-hashed data stored in S3 with git-tracked pointers, and Docker to package the model with FastAPI into a portable image.
4. **Cloud deployment.** Publish images to ECR with vulnerability scanning on push, and deploy to App Runner with continuous redeployment on image updates.

A fuller lesson-by-lesson explanation of the reasoning behind each step is in [NOTES.md](NOTES.md).

## Note on App Runner

The App Runner service is fully written as Infrastructure as Code in `apprunner_services.tf` and `modules/apprunner-service/`, but it is left disabled by default. The AWS account used for this project is not subscribed to App Runner, so `CreateService` returns `SubscriptionRequiredException`. The configuration that would be used is preserved (commented) in `environments/dev.tfvars` for reference, and the ECR-based build-and-push path serves as the working fallback. See [NOTES.md](NOTES.md) (Lesson 4) for the full explanation.
