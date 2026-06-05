# MLOps Course — Project Notes & Video Script

These notes build up lesson by lesson into the script for the final video.
For each lesson: **what** we did, **how**, **why** it matters, and **what problem
it solves**. Extra-credit exploration ideas are marked 🌟.

---

## Lesson 1 — Infrastructure as Code with Terraform

**What we did:** Wrote two text files (`terraform/provider.tf`, `terraform/s3.tf`)
describing an AWS S3 bucket, then used Terraform to create it in AWS.

**How:**
- `provider.tf` declares the cloud (AWS), region (`eu-west-1`), and provider version.
- `s3.tf` declares one resource: an S3 bucket with a globally-unique name.
- Credentials are supplied via environment variables, never written in the code.
- Workflow: `terraform init` → `validate` → `fmt` → `plan` → `apply` (→ `destroy`).

**Why Infrastructure as Code instead of clicking in the AWS console?**
- **Reproducible** — anyone can recreate the exact same setup from the files.
- **Version-controlled** — infra lives in git; changes are tracked and reversible.
- **No manual drift** — code is the single source of truth, not undocumented clicks.
- **Scalable** — the same file can spin up dev/test/prod identically (lesson 2).

**Why an S3 bucket first?** It's the storage foundation of the whole project —
later it holds data, trained models, and Terraform's own state file. This is
"maturity level 0": the simplest real piece of cloud infra, managed as code.

**Problem it solves:** ML projects break when infra is built by hand and nobody
can reproduce it. IaC makes the environment itself versioned and repeatable —
the bedrock of MLOps.

**Key commands explained:**
- `terraform init` — downloads the AWS provider plugin (run once per project).
- `terraform validate` — checks the config syntax is correct.
- `terraform fmt` — auto-formats files to a consistent style.
- `terraform plan` — previews changes without making them (dry run).
- `terraform apply` — actually creates/changes the infrastructure.
- `terraform destroy` — tears everything down (avoids leftover costs).

🌟 **Extra-credit ideas to explore:**
- **Remote state**: Terraform stores state locally by default; teams move it to
  S3 + DynamoDB locking so the team shares one source of truth and avoids
  concurrent-edit corruption. (Touched in lesson 2 — can go deeper.)
- **Least-privilege IAM**: the lesson uses root/admin keys; production uses a
  scoped-down IAM role with only the permissions it needs — why that matters.

---
<!-- Lesson 2, 3, 4 notes will be added here as we go. -->
