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

### Why a feature branch + pull request (not committing to main)

Our workflow triggers on `pull_request` into `main` — i.e. "run when someone proposes
merging *into* main." A PR is by definition a request to merge **one branch into
another**, so we need a separate branch (`lesson-2-cicd`) to hold the changes. If we
committed straight to `main`, there'd be no PR and **the pipeline would never trigger**.

But it's not just a technicality — branches are what make *review* possible, which is
the whole maturity jump of lesson 2:

```
main  ───●───────────────────────●──────►   (source of truth, always-deployable)
          \                      /
           \                    / merge (after approval)
lesson-2-cicd ●──●──●  ← changes live here
                   │
                   └─ open PR → CI runs plan → human approves → apply
```

- **`main`** = trusted state of the infra; you don't want half-finished edits there.
- **feature branch** = safe scratch space; changes don't affect main until reviewed.
- **pull request** = the review checkpoint: shows the diff, runs `plan` so you can SEE
  what would change in AWS, and holds the approval gate BEFORE anything is applied.

This is the standard **GitHub Flow / trunk-based** workflow: main stays clean, work
happens on short-lived branches, changes merge back only after passing CI + review.

> Video line: *"We work on a branch and open a pull request because that's what lets
> the pipeline review and approve infra changes before they touch AWS — instead of
> applying blindly from a laptop."*

🌟 Extra-credit: enable **branch protection** on main (require the CI check to pass +
an approval before merge) so the gate can't be bypassed.

### Deprecation warnings we hit (theme: dependencies evolve, IaC/CI needs maintenance)

Both are **warnings, not errors** — everything ran green. Worth a mention in the video
because they show a real MLOps truth: the tools and dependencies underneath you keep
moving, so infra/CI code has to be maintained over time, not written once and forgotten.

1. **Terraform AWS provider (v6.49):** `acceleration_status is deprecated...` Several
   settings that used to live directly on `aws_s3_bucket` (acceleration, versioning,
   encryption) are being split into their own resources. We see it because our module's
   `output "data"` returns the *whole* bucket object. 🌟 Fix = output only specific
   fields (e.g. `value = aws_s3_bucket.s3.arn`) instead of the whole object.

2. **GitHub Actions Node.js 20 deprecation:** `checkout@v4`,
   `configure-aws-credentials@v4`, `setup-terraform@v3` run on Node 20, which GitHub is
   retiring (forced to Node 24 on 2026-06-16; Node 20 removed 2026-09-16). 🌟 Fix = bump
   each action to a newer version built for Node 24 when the maintainers release one
   (one line per action, no logic change).

**Takeaway:** pinning versions (`@v4`, provider `>=5.97`) keeps builds reproducible
*today*; periodically updating them keeps you supported. A mature team watches both.

## Lesson 3 — Data Versioning & Model Containerization (DVC + Docker)

### Why lesson 3 exists (the big picture)

Lessons 1–2 made the **infrastructure** reproducible. Lesson 3 does the same for the
**ML work itself**: the data, the model, and the runtime environment. It tackles four
real ML problems:

| Problem | What breaks without a fix | Lesson 3's answer |
|---------|---------------------------|-------------------|
| **Messy code** | One giant script nobody can debug or reproduce | A modular pipeline (`ingest→clean→train→predict`) driven by `config.yml` |
| **Data drift** | Data changes over time; "which data made this model?" is unanswerable | **DVC** versions the data alongside the code |
| **Reproducibility** | "Works on my machine" — different Python/deps elsewhere | A **virtual environment** + pinned `requirements.txt`, then **Docker** |
| **Deployment** | A `.pkl` file can't be called by anyone | **FastAPI** serves it as an API; **Docker** packages it to deploy |

### The ML pipeline (code structured for reproducibility)

**What we did:** split the ML work into single-responsibility stages, all parameterized
by one config file:
- `pipelines/ingest.py` — load `train.csv`/`test.csv` (paths from config)
- `pipelines/clean.py` — drop unused columns, impute missing values, strip the `£`/commas
  from `AnnualPremium`, remove outliers (IQR). *Real data is messy.*
- `pipelines/train.py` — preprocess (scale numerics, one-hot encode categoricals),
  apply **SMOTE**, fit the model, save `models/model.pkl`
- `pipelines/predict.py` — load the model, evaluate (accuracy, ROC-AUC, report)
- `main.py` — orchestrates the four stages; `config.yml` holds every parameter.

**Why config-driven?** To swap a DecisionTree for a RandomForest you edit **config, not
code** — so the experiment is described by a versioned file, not by remembering what you
typed. Same declarative philosophy as Terraform, applied to ML.

**Result:** `DecisionTreeClassifier` → accuracy **0.834**, ROC-AUC **0.715**.
🌟 **Why ROC-AUC, not accuracy?** The data is imbalanced (~85.6k "no" vs ~11.8k "yes").
A model that always says "no" scores ~88% accuracy while being useless. **SMOTE**
(Synthetic Minority Over-sampling) generates synthetic "yes" examples so the model
actually learns the rare class — recall on the minority went to ~0.56 instead of ~0.

> Video line: *"Each stage has one job and every parameter lives in config, so the whole
> experiment is described by versioned files — reproducible, not improvised."*

### DVC — version control for data ("git for data")

**The problem:** git is terrible at large/binary files. Our CSVs are ~6 MB *each* and
`model.pkl` is ~6 MB — committing them bloats the repo and binary diffs are meaningless.

**How DVC solves it (the core mechanic):**
- We `dvc add data` → DVC computes a **content hash**, moves the real bytes to a cache,
  and writes a tiny text **pointer file `data.dvc`** (just the hash + size).
- **Git tracks the pointer; S3 holds the bytes.** `data/` goes in `.gitignore`; `dvc push`
  uploads the actual data to the S3 remote. Git stays small and fast.
- The remote is **the Lesson-2 `datastore-dev` bucket** — the infrastructure we built
  earlier is now the storage backend for our ML data. 🎬 nice full-circle moment.

**Content-hashing gives us three things** (visible in S3 as `data/files/md5/xx/<hash>`):
integrity (a changed byte changes the hash), deduplication (identical files stored once),
and a manifest (`.dir`) mapping hashes back to filenames.

**Versioning demo (the payoff):**
| Action | Command | Result |
|--------|---------|--------|
| Tag initial data | `dvc add data` → `git tag v1` → `dvc push` | `v1` = 100,001 rows |
| Simulate drift | delete 1 row → `dvc add data` → `git tag v2` → `dvc push` | `v2` = 100,000 rows |
| Roll back | `git checkout v1 -- data.dvc` → `dvc checkout` | original data restored! |

On the `v2` push, only **2 files** uploaded (changed `train.csv` + manifest) — `test.csv`
was deduplicated and skipped. And rollback moved only a **pointer** in git; DVC swapped
the bytes. `dvc checkout` restores from local cache; `dvc pull` fetches from S3 (what a
fresh `git clone` on another machine would use).

> Video line: *"Git tracks a small hash pointer; the data bytes live in S3. So git stays
> fast, and any tagged data version is reproducible with git + dvc."*

🌟 **Extra-credit:** the same idea extends to **model versioning** — a model is truly
reproducible when code (git) + data (DVC tag) + config are pinned together; you could
also `dvc add models/` to version the artifact itself.

### Dependency drift we hit (theme: reproducibility is hard — and continues from L2)

Running the teacher's code "today" (a newer package landscape) broke twice — *not* in the
teacher's recording. Both fixed by **pinning** in `requirements.txt`:
1. **`pathspec`** — pip pulled a 1.x version that removed `_DIR_MARK`, crashing
   `dvc init`. Pinned `pathspec==0.12.1`.
2. **`boto3`/`botocore`** — `dvc[s3]` needs `boto3`, but newer `aiobotocore` stopped
   pulling it in *and* requires `botocore<1.43.1`. Pinned `boto3==1.43.0` + `botocore==1.43.0`.

🌟 This is the same lesson as L2's deprecation warnings: **dependencies evolve; pinning
keeps builds reproducible today, and you maintain those pins over time.** Living it
firsthand is good extra-credit material — the README literally names "reproducibility" as
a core challenge.

### Docker — packaging the model so it runs anywhere (and can be deployed)

**The problem Docker solves: "works on my machine."** The model currently runs only
inside *my* `.venv`, on *my* Mac, with *my* Python 3.10 and exact packages. A cloud
server won't have that. **Docker bundles the OS + Python + all dependencies + the code +
the model into one portable image** that runs *identically anywhere*. It's the virtual-env
idea taken all the way down to the operating system.

**The two files:**
- **`app.py` (FastAPI)** — wraps the `.pkl` in a web API. A `BaseModel` schema declares
  the 7 input features and their types, so pydantic **validates** every request (a
  production API can't trust its callers). `GET /` is a **health check** (cloud platforms
  ping it to confirm the container is alive — matters in Lesson 4); `POST /predict` takes
  JSON → returns `{"predicted_class": 0/1}`. The model is loaded **once at startup**.
- **`Dockerfile`** — the build recipe: `FROM python:3.13-slim` → `COPY` in app/model/
  requirements → `pip install` → `CMD` launches uvicorn on port 80.

**How we ran it:**
```
docker build -t mlops-course-03-image .
docker run -d --name mlops-course-03-container -p 80:80 mlops-course-03-image
curl http://127.0.0.1/            → {"health_check":"OK"}
curl -X POST .../predict -d '{...}' → {"predicted_class":1}
```
`-p 80:80` bridges the Mac's port 80 into the container's port 80. Interactive Swagger UI
at **http://127.0.0.1/docs**.

**Why Docker is the prerequisite for Lesson 4:** you can't deploy a loose `.pkl` + scripts
to the cloud — AWS App Runner runs **containers**. Docker turns "I trained a model" into
"I have a deployable artifact." That's the bridge.

> Video line: *"Docker packages the whole environment into a portable image that runs the
> same everywhere — which is exactly what AWS needs to deploy it in Lesson 4."*

🌟 **Extra-credit — `.dockerignore` + image hygiene:** I added a `.dockerignore`
(beyond the teacher's repo) to keep `.venv/`, `data/`, and the DVC cache out of the build
context — that's why the context was only ~6 MB. A further improvement: the serving image
installs the *full* `requirements.txt` (mlflow, jupyter, dvc) which serving doesn't need;
a production fix is a slim `requirements-serve.txt` (fastapi, uvicorn, scikit-learn,
imbalanced-learn, pandas, joblib) → smaller, faster, more secure image.

### The thread tying all three lessons together (the video's backbone)

The MLOps move is identical every time: **declare it in a file → version it in git →
reproduce it anywhere.** Only the *thing* being managed changes:

| Layer | "Code" that declares it | Versioned in |
|-------|------------------------|--------------|
| **Infrastructure** | Terraform `.tf` files | git |
| **Data** | DVC `data.dvc` pointers + tags | git (pointer) + S3 (bytes) |
| **Runtime environment** | `Dockerfile` + `requirements.txt` | git |

> Closing video line: *"Whether it's infrastructure, data, or the runtime environment,
> the MLOps move is the same — describe it as code, version it, and reproduce it on
> demand. That's what makes the whole project repeatable instead of 'it worked once on my
> laptop.'"*

