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

## Lesson 2 — Scaling IaC (modules, environments, remote state, CI/CD)

### Why lesson 2 exists (the big picture)

Lesson 1 reached **"maturity level 0"**: Terraform worked, but it ran *only on my
laptop*, with *one hardcoded bucket*, and the **state file lived locally**. That's
fine solo, but it breaks the moment (a) there's more than one environment, (b) more
than one person/machine touches the infra, or (c) a robot (CI) needs to run it.
Lesson 2 fixes all three with four moving parts:

| Part | What it is | The problem it solves |
|------|-----------|----------------------|
| **Remote state backend** | Move `terraform.tfstate` off the laptop into an S3 bucket, with locking + versioning | Local state can't be shared, can't be locked (two applies corrupt it), and is lost if the laptop dies. *The* prerequisite for teamwork + CI. |
| **Modules** | A reusable `modules/s3-bucket/` component | Stop copy-pasting resource blocks. Define "how we make a bucket" once, reuse everywhere (DRY). |
| **Multi-environment** | `environments/dev.tfvars` + `backends/dev.conf` (and tst/prd) | Same code, different inputs per stage. Promote dev→tst→prd without rewriting anything. |
| **GitHub Actions CI/CD** | A workflow that runs init→validate→plan→**approve**→apply on a pull request | Infra changes become reviewed, auditable, and automated — not "someone ran apply on their laptop." Needs AWS keys stored as GitHub repo secrets. |

🌟 **The "chicken-and-egg" problem:** the S3 bucket that holds Terraform's state
can't itself be created by the Terraform that *uses* it — so we **bootstrap that one
bucket manually first**, then everything else is managed as code.

### Key concept: state file vs. the actual resources (this confused me at first)

The remote-state backend bucket does **NOT** "manage" or "contain" the other buckets.
It stores the **state file** — and the state file is just Terraform's *notebook*, not
the buckets themselves.

- **The real bucket** lives in AWS S3 as an actual resource (the thing you see in the
  AWS console).
- **The state file** (`terraform.tfstate`) is a JSON ledger where Terraform writes
  down: *"I created a bucket named X, with these settings."* It's Terraform's
  **memory** of what it has built, so that on the next `plan` it can compare
  "what I think exists" vs. "what the code now says" and compute the difference.

By default that notebook sits **on the laptop**. The remote backend bucket's only job
is to **hold the notebook in the cloud instead**, so it can be shared and locked.

```
        ┌─────────────────────────────┐
        │  Backend S3 bucket          │   ← stores the NOTEBOOK (tfstate)
        │  "tf-remote-backend-..."    │      "I manage bucket X, bucket Y..."
        └──────────────┬──────────────┘
                       │ describes
            ┌──────────┴───────────┐
            ▼                      ▼
   ┌─────────────────┐   ┌─────────────────┐
   │ datastore bucket│   │  (more buckets) │   ← the ACTUAL resources
   └─────────────────┘   └─────────────────┘
```

So **destroying the old lesson-1 bucket and creating the remote-state bucket are
unrelated actions.** The backend bucket is new bookkeeping storage; the old bucket is
just an empty leftover resource. (Decision for this project: clean-slate — destroy the
empty lesson-1 bucket so the new modular structure rebuilds it the "mature" way.)

### Why remote state matters (3 concrete wins)
- **State Locking** — prevents two `apply` runs at once from corrupting state.
- **Versioning** — roll back to an earlier state if something goes wrong.
- **Encryption** — secrets that land in the state file are encrypted at rest.

### Core idea of the restructure: separate CODE from CONFIG (the DRY principle)

Lesson 2 splits the project into two kinds of files:

- **Code** (`provider.tf`, `variables.tf`, `s3_buckets.tf`, the module) — the *logic*:
  **how** things are built. Written **once**. It never names a specific region,
  environment, or bucket; it uses blanks like `var.aws_region`, `var.environment`.
- **Config** (`environments/dev.tfvars`, `tst.tfvars`, `prd.tfvars`) — the *values*:
  **what** to plug into those blanks for each stage. **One file per environment.**

Deploying = run the same code with a different config file:
```
terraform apply -var-file=environments/dev.tfvars   # → environment "dev"
terraform apply -var-file=environments/prd.tfvars   # → environment "prd"
```

**Why this is better than hardcoding.** If values were baked into the code, having
dev and prd differ would force you to either (a) hand-edit the code before every
deploy (error-prone, and you can't tell what's deployed where), or (b) copy the whole
project per environment (every fix made N times; copies drift apart). The variable +
tfvars approach avoids both: the thing that *varies* lives in a tiny per-env file; the
thing that *stays the same* lives in code maintained once. That's **DRY — Don't Repeat
Yourself** — applied to infrastructure.

What actually differs across our environments:

| | dev.tfvars | tst.tfvars | prd.tfvars |
|---|---|---|---|
| `environment` | `"dev"` | `"tst"` | `"prd"` |
| `aws_region` | `eu-west-1` | `eu-west-1` | `eu-west-1` |
| resulting bucket | `...-datastore-dev` | `...-datastore-tst` | `...-datastore-prd` |

Same code, three isolated environments, driven entirely by swapping one `-var-file`.
🌟 Region *could* differ per env too (e.g. prd in `eu-central-1`) — just change one
line in that env's tfvars, no code edit. For this project all three stay `eu-west-1`;
the point is the **capability**.

> Note: the AWS console's region dropdown is only a *viewing filter* — it does NOT
> control where Terraform deploys. Terraform obeys only the `region` in its provider
> config, which comes from `var.aws_region` ← the tfvars file. Control flows
> code → AWS, never the reverse.

### How the backend bucket organizes state (one notebook per environment)

The backend bucket stores **Terraform state files** (the "notebooks") — NOT our data,
models, or app artifacts (those live in separate purpose-built buckets like the
datastore bucket). Its only job is bookkeeping: remembering *what infrastructure
Terraform manages*, per environment.

Environments stay isolated because each gets its own state file, set by the `key` line
in its backend config:

```
backends/dev.conf  →  key = "terraform-dev.tfstate"
backends/tst.conf  →  key = "terraform-tst.tfstate"
backends/prd.conf  →  key = "terraform-prd.tfstate"
```

So the ONE backend bucket holds three separate objects:

```
tf-remote-backend-shan-mlops45793
├── terraform-dev.tfstate   ← notebook for dev's infrastructure
├── terraform-tst.tfstate   ← notebook for tst's infrastructure
└── terraform-prd.tfstate   ← notebook for prd's infrastructure
```

This isolation means an `apply` against dev touches only the dev notebook — a mistake
in dev can never accidentally change what prd manages. That's why `init` points at a
specific `backends/<env>.conf`: it selects which notebook to use.

**Two meanings of "snapshot":**
1. **Separation by environment** — different `key`s = different notebooks (isolation).
2. **Version history** — because versioning is ON, every change to a state file keeps
   the previous version, so a corrupted state can be rolled back to an earlier one.

> One-liner for the video: *"The backend bucket is where Terraform keeps its memory —
> one notebook per environment, version-tracked so we can roll back."*

### CI/CD with GitHub Actions — automating the apply (and gating it)

**The problem:** so far *I* run `init → plan → apply` on my laptop. That's fine solo
but doesn't scale: no review, no audit trail, no consistency (works-on-my-machine),
and anyone with the keys can change prod by hand. **CI/CD** moves these runs to a
neutral, automated environment triggered by version control.

**How (`.github/workflows/infra-cicd-dev.yml`, at the REPO ROOT):**
- **Trigger:** opening a pull request into `main` that touches `terraform/**` (plus a
  manual `workflow_dispatch` button). PR = the natural place to *review* infra changes.
- **Steps:** checkout → setup Terraform → configure AWS creds (from GitHub Secrets) →
  `fmt -check` → `init` (with `backends/dev.conf`) → `validate` → `plan` →
  **manual approval gate** → `apply`. Same sequence I ran locally, now automated.
- **The approval gate** (`trstringer/manual-approval`) pauses the run and opens a
  GitHub issue; nothing is applied until an approver (me, `Suzyxx`) confirms. This is
  the "human in the loop before touching cloud infra" safeguard.

**Secrets vs. config — a key security point:**
- The AWS access key + secret are stored in **GitHub repo Secrets**, NOT in any file.
  Secrets are encrypted and never printed in logs. Committing keys to git is a classic
  breach; this avoids it.
- The `.tfvars`/`.conf` files ARE committed — they're non-secret configuration. State
  files (`*.tfstate`) and `.terraform/` stay gitignored (state can contain secrets and
  lives in S3 anyway).

🌟 **Extra-credit angles:** separate plan-on-PR vs. apply-on-merge; OIDC role
assumption instead of long-lived keys (no stored secret at all); a matrix to run
dev/tst/prd; `terraform plan` output posted as a PR comment.

<!-- Lesson 2 step-by-step (bootstrap → restructure → migrate → CI/CD) added below as we do them. -->
