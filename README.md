<!--
=============================================================================
File        : README.md
Assignment  : DSO202 Assignment 4 - GitOps delivery with Argo CD
Descriptor  : 4.1-4.4 (whole assignment)
Purpose     : Report: purpose, architecture, pinned versions, chart contract,
              build-from-empty commands, cleanup, credential handling and the
              answers to Q1-Q6. Command output lives in docs/evidence.md.
=============================================================================
-->

# DSO202 Assignment 4: GitOps Delivery of the Task Tracker with Argo CD

## 1. Introduction

In Assignments 1 to 3 I deployed the three-tier **Task Tracker** (nginx frontend, Node.js backend, PostgreSQL) by hand: first with `kubectl apply`, then with Kustomize and Helm. Every change still needed a person to run a command against the cluster.

In this assignment that manual step is removed. **Argo CD** runs inside the cluster, reads the desired state from this Git repository and keeps the cluster equal to it. This is **GitOps**: Git is the single source of truth, and the cluster *pulls* its configuration instead of somebody *pushing* it.

> **Repository name:** the brief asks for `dso202-gitops`. That name was already used by another repository on my GitHub account, so this repository is **`dso202-gitops_A4`**. Every `repoURL` and `sourceRepos` entry uses https://github.com/Rynorbu/dso202-gitops_A4.git.

### Aim

To deliver the Task Tracker to a **dev** and a **staging** environment using Argo CD, so that every change, release, recovery and even a complete cluster rebuild happens through Git.

### Objectives

- Install Argo CD **declaratively** from versioned files (Kustomize, pinned to v3.5.6).
- Use the **app-of-apps** pattern: one hand-applied root Application creates everything else.
- Separate an administrator **platform** project from a least-privilege **dso202** workload project.
- Keep database credentials in Git **encrypted** with Sealed Secrets.
- Run **dev** on branch `main` with automated sync and **staging** on a Git tag with manual sync.
- Ship a release, survive a faulty release and recover with `git revert`.
- Prove reconciliation (drift, prune, project guardrails) and **rebuild the whole cluster** from Git plus one key.

### The four GitOps principles and where they are shown

| Principle (OpenGitOps) | How this repo meets it | Evidence |
|---|---|---|
| Declarative | Every object is a file; nothing is created with `kubectl create` after bootstrap | Tasks 3, 4, 5 |
| Versioned and immutable | Pinned tool, chart and image versions; staging follows tags; recovery is `git revert` | Tasks 2, 5, 7 |
| Pulled automatically | Argo CD polls GitHub every 60 s; no pipeline pushes to the cluster | Tasks 5, 7 |
| Continuously reconciled | Drift in dev reverted, drift in staging reported, deleted files pruned | Task 8 |

## 2. Architecture

```
Laptop (Docker Desktop)
└── kind cluster "dso202-gitops" (1 control-plane + 2 workers)
    ├── argocd          Argo CD v3.5.6 (7 Pods), polls github.com/Rynorbu/dso202-gitops_A4 every 60 s
    ├── sealed-secrets  Sealed Secrets controller 0.40.0 (1 Pod), holds the sealing key
    ├── dso202-dev      Task Tracker  <- branch main, automated sync  -> http://localhost:30080
    └── dso202-staging  Task Tracker  <- tag v1.x.y, manual sync      -> kubectl port-forward 8082
```

### What is applied by hand and what comes from Git

| Layer | Files | How it reaches the cluster |
|---|---|---|
| Argo CD itself | `bootstrap/argocd/` | by hand, once per cluster (`kubectl apply -k`) |
| Root + platform project | `bootstrap/root/` | by hand, once per cluster (`kubectl apply -f`) |
| dso202 AppProject | `argocd/projects/dso202.yaml` | root, sync wave **-3** |
| Sealed Secrets controller | `argocd/applications/sealed-secrets.yaml` | root, wave **-2** |
| Namespaces, quota, limits, RBAC, credentials | `argocd/applications/platform-*.yaml` -> `platform/<env>/` | root, wave **-1** |
| Task Tracker workloads | `argocd/applications/tasktracker-*.yaml` -> `charts/tasktracker` | root, wave **0** |

Inside the chart: database wave 0 -> backend wave 1 -> frontend wave 2 -> PostSync smoke-test Job.
The root Application waits for each wave to be **Healthy** before the next, thanks to the Application health check added in `argocd-cm`.

### Environments

| Property | dev | staging |
|---|---|---|
| Namespace | `dso202-dev` | `dso202-staging` |
| Application | `tasktracker-dev` | `tasktracker-staging` |
| Revision | branch `main` (moves) | tag `v1.0.0` -> `v1.1.0` -> `v1.2.0` (never moves) |
| Sync | automated, prune, self-heal | manual |
| Values | `environments/dev/values.yaml` | `environments/staging/values.yaml` |
| Frontend | NodePort 30080 -> http://localhost:30080 | NodePort 30081 (not mapped) -> port-forward 8082 |
| Credentials | SealedSecret in `platform/dev/` | separate SealedSecret in `platform/staging/` |
| Role | fast feedback | release gate |

### AppProjects

| Project | Used by | Destinations | Kinds | Created by |
|---|---|---|---|---|
| `platform` | root, sealed-secrets, platform-dev, platform-staging | argocd, sealed-secrets, dso202-dev, dso202-staging | all (admin) | hand (bootstrap) |
| `dso202` | tasktracker-dev, tasktracker-staging | dso202-dev, dso202-staging | Deployment, StatefulSet, Service, ConfigMap, ServiceAccount, Job; no cluster-scoped | root (Git) |

## 3. Repository layout

```
dso202-gitops/
├── README.md                     this report
├── .gitignore                    first commit: keeps keys and plaintext out
├── cluster/kind-cluster.yaml     kind cluster (from Practical 1)
├── bootstrap/                    applied by hand, once per cluster
│   ├── argocd/                   Argo CD install (Kustomize + 2 patches)
│   └── root/                     platform AppProject + root Application
├── argocd/                       watched by root (app of apps)
│   ├── projects/dso202.yaml      workload AppProject
│   └── applications/             sealed-secrets, platform-*, tasktracker-*
├── platform/{dev,staging}/       namespace, quota + limits, RBAC, SealedSecret
├── charts/tasktracker/           Helm chart (from A3, adjusted to the contract)
├── environments/{dev,staging}/   values that differ per environment
└── docs/
    ├── evidence.md               command output for every task
    └── screenshots/              UI screenshots referenced from evidence.md
```

## 4. Pinned versions

| Component | Version |
|---|---|
| Argo CD (server) | v3.5.6 (`install.yaml` from tag v3.5.6) |
| argocd CLI | v3.5.6 |
| Sealed Secrets Helm chart | 2.20.0 (controller 0.40.0) |
| kubeseal | v0.40.0 |
| kind | v0.32.0, node image `kindest/node:v1.36.1` (pinned by digest) |
| kubectl | v1.36.3 client |
| Helm | v3.18.6 |
| Images | `rynorbu11/dso202-frontend`, `-backend`, `-db` tags `1.0` / `1.1` only; `busybox:1.37` |

## 5. Chart contract (C1-C11)

The Assignment 3 chart was adjusted so Argo CD can deliver it safely.

| # | Requirement | File | Key / change |
|---|---|---|---|
| C1 | Image repo and tag are per-tier values, no tag in templates | `templates/*-deployment.yaml`, `db-statefulset.yaml` | `required ... .Values.<tier>.image.tag` (A3 fallback to `.Chart.AppVersion` removed) |
| C2 | Config from values; new backend env var = values change only | `values.yaml`, `backend-deployment.yaml` | `backend.extraEnv` map rendered as `env:` |
| C3 | Chart never renders a Secret; reads `existingSecret` | `values.yaml`, `_helpers.tpl` | A3 `secret.yaml` deleted; `existingSecret: tasktracker-credentials` |
| C4 | Readiness probes on all tiers, backend `GET /api/status` | all workload templates | `readinessProbe` |
| C5 | Sync waves db 0, backend 1, frontend 2 | workload templates | `argocd.argoproj.io/sync-wave` |
| C6 | `progressDeadlineSeconds: 120` on backend and frontend | `backend-deployment.yaml`, `frontend-deployment.yaml` | `spec.progressDeadlineSeconds` |
| C7 | Requests and limits on every container | `values.yaml`, `smoke-test-job.yaml` | `resources` |
| C8 | No Namespace, ResourceQuota, LimitRange, Role, RoleBinding | chart | A3 `quota.yaml` deleted; these live in `platform/<env>/` |
| C9 | Ingress disabled by default | chart | no Ingress template exists |
| C10 | Frontend NodePort, port is a value | `frontend-service.yaml`, env values | 30080 dev, 30081 staging |
| C11 | `helm lint` clean, `helm template` works for both envs | whole chart | see evidence Task 1 |

Other changes from A3: the database is now a **StatefulSet** with `volumeClaimTemplates` (as in A2), so the chart renders no PersistentVolumeClaim and the `dso202` whitelist matches the chart exactly. A **ServiceAccount** without a mounted token is used by all Pods. `fullnameOverride: tasktracker` gives fixed Service names (`tasktracker-backend`, ...). The Helm test Pod and `NOTES.txt` were removed (Argo CD does not use them; the PostSync smoke test replaces the test). A second ConfigMap, `tasktracker-frontend-nginx`, is mounted over the image's `nginx.conf` and proxies `/api/` to `tasktracker-backend:8080`. The browser only ever calls the frontend's own URL (`frontend.backendUrl`: `http://localhost:30080` in dev, `http://localhost:8082` in staging), so no hosts-file entry or extra port-forward is needed.

## 6. Build the whole environment from an empty machine

Requirements: Docker Desktop (>= 6 GB memory), kind, kubectl, Helm, argocd CLI v3.5.6, kubeseal v0.40.0, Git, and the sealing-key backup `~/dso202-keys/sealing-key.backup.yaml`.

```bash
# 1. Get the repo
git clone https://github.com/Rynorbu/dso202-gitops_A4.git
cd dso202-gitops

# 2. Create the cluster
kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml

# 3. Restore the sealing key BEFORE the controller is installed
kubectl create namespace sealed-secrets
kubectl apply -f ~/dso202-keys/sealing-key.backup.yaml

# 4. Install Argo CD and wait
kubectl apply -k bootstrap/argocd --server-side --force-conflicts
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

# 5. Hand over to Git
kubectl apply -f bootstrap/root
kubectl get applications -n argocd -w      # wait for waves -3 .. 0

# 6. Sign in (port-forward in a second terminal) and release staging
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd app sync tasktracker-staging

# 7. Use the app
#    dev:     http://localhost:30080
#    staging: kubectl port-forward -n dso202-staging svc/tasktracker-frontend 8082:8080
#             then http://localhost:8082
```

## 7. Cleanup

```bash
# stop the port-forwards (Ctrl+C in their terminals), then:
kind delete cluster --name dso202-gitops
# KEEP ~/dso202-keys/sealing-key.backup.yaml - without it the SealedSecrets
# in this repo can never be decrypted again.
```

## 8. Credential handling

- Database credentials exist in Git **only as SealedSecrets** (`platform/<env>/tasktracker-credentials.sealed.yaml`), encrypted with the controller's public key. Only the controller in the cluster holds the private key.
- Plaintext inputs were written in an editor to `secrets-plain/<env>.env` (gitignored), piped through `kubectl create secret --dry-run=client | kubeseal` so no plaintext Secret ever touched disk, and then deleted. The values are kept in a password manager.
- Dev and staging use **different passwords** and are **sealed separately**: strict scope binds each ciphertext to its name *and* namespace.
- The sealing key is backed up to `~/dso202-keys/` - outside this repo and outside any cloud-synced folder - and refreshed after the rebuild.
- `.gitignore` (first commit) blocks key files and plaintext inputs, but it is only a safety net. The proof that no value is in history is in `docs/evidence.md` Task 4 (`git log -p --all -S'<value>'` prints nothing for every value).

## 9. Releases

| Tag | Contents | Staging promoted by |
|---|---|---|
| `v1.0.0` | baseline: all images 1.0, chart + smoke test | initial `targetRevision` |
| `v1.1.0` | frontend 1.1 | PR #__ + manual sync |
| `v1.2.0` | backend 1.1 + required setting `__________` | PR #__ + manual sync |

Faulty release: commit `_______` (backend 1.1 without the required setting) was reverted by commit `_______` (PR #__). Staging never ran it (see `argocd app history tasktracker-staging` in evidence Task 7).

## 10. Answers to the questions

> Fill the bracketed parts with YOUR real output, SHAs, messages and times. Specific answers earn the marks.

### Q1 - Why is `platform` applied by hand while `dso202` is created by root? What risk arises if `dso202` may deploy into `argocd`?

`platform` is the project that root itself belongs to and that is allowed to create anything, including objects in the `argocd` namespace. If it were delivered from Git by root, a commit could change the permissions of the project that delivers that very commit - the project would be able to widen its own rights. Applying it by hand, once, during bootstrap puts it outside what Git can change; only an administrator with cluster access can alter it. `dso202` on the other hand is an ordinary, low-privilege project, so it is safe (and better, because declarative and reviewed) to create it from Git through root.

If `dso202` could deploy into `argocd`, a chart commit to `charts/tasktracker` could render an `AppProject`, an `Application` or an Argo CD ConfigMap (e.g. `argocd-rbac-cm`) into the `argocd` namespace. That would let the workload layer create a new project with `*` permissions, give itself admin RBAC or create an Application that deploys anything anywhere - privilege escalation through Git. In my setup `argocd` is listed only in `platform` (evidence Task 3: `argocd proj get dso202` shows destinations `[dso202-dev, dso202-staging]`).

### Q2 - What does strict scope prevent, what is lost, and what must be done if the sealing key is lost?

**Prevents:** with strict scope the Secret's name and namespace are part of the encryption. Someone who can create objects in another namespace (or under another name) cannot copy my SealedSecret there and have the controller decrypt it for them, so a sealed file cannot be used to steal credentials from another namespace.
**Lost:** flexibility. One sealed file cannot be reused for dev and staging (I had to seal twice, see `platform/dev` and `platform/staging`), and renaming the Secret or moving it to another namespace requires re-sealing from the plaintext.
**If the key is lost:** no existing SealedSecret can be decrypted any more (`no key could decrypt secret`). The controller generates a new key; every credential must be re-sealed from the original plaintext (kept in the password manager) and committed. If the old key may have *leaked* rather than just been lost, the actual database passwords must also be rotated, because anyone with the old key can decrypt the old ciphertext from Git history.

### Q3 - Difference between Synced and Healthy, with an example

**Sync status** compares the live objects with Git: *Synced* means they match the rendered manifests. **Health status** says whether the objects actually work: Deployments available, Pods ready, Jobs succeeded. They are independent.
Example from my cluster: [paste the moment, e.g. right after the first sync `tasktracker-dev` showed `Sync Status: Synced`, `Health Status: Progressing` while the database Pod was still starting; and in Task 7 the backend 1.1 release was `Synced` but `Degraded` after 120 s because the new Pods never became ready]. Git and cluster agreed - the configuration was exactly what was committed - but that configuration did not work.

### Q4 - Argo CD RBAC vs Kubernetes RBAC; SSO change to `policy.csv`

| | Argo CD RBAC | Kubernetes RBAC |
|---|---|---|
| Controls | what a user may do **through Argo CD** (view/sync/delete Applications, view logs, read projects) | what an identity may do **against the Kubernetes API** (get pods, create deployments ...) |
| Subjects | Argo CD accounts (local `reviewer`) or SSO groups | users, groups, ServiceAccounts |
| Configured in | `argocd-rbac-cm` -> `policy.csv` (`bootstrap/argocd/argocd-rbac-cm-patch.yaml`) | Role/ClusterRole + RoleBinding objects (`platform/<env>/rbac.yaml`, A2) |

Argo CD itself talks to Kubernetes with its own ServiceAccounts, so a reviewer who can "sync" in Argo CD does not need any Kubernetes rights at all - and a reviewer without Argo CD rights cannot sync even though Argo CD could.
**With SSO (not configured):** users would come from the identity provider, so `policy.csv` would grant rights to IdP **groups** instead of the local account, typically through a role:
```
p, role:reviewer, applications, get, dso202/*, allow
p, role:reviewer, projects, get, dso202, allow
p, role:reviewer, logs, get, dso202/*, allow
g, dso202-reviewers, role:reviewer
```
and the local `accounts.reviewer` entry in `argocd-cm` would be removed.

### Q5 - Why rollback is refused, the GitOps equivalent, and why `git revert`

`argocd app rollback tasktracker-dev` was refused with: `[paste the exact message]`. Rollback would set the live state to an older revision, but `tasktracker-dev` has automated sync: on the next reconcile Argo CD would see the difference from `main` and sync forward to the bad commit again. Argo CD therefore refuses rollback while automated sync is enabled.
The GitOps equivalent is to change the **desired state** in Git: `git revert <bad-commit>` creates a new commit that undoes the change, and Argo CD delivers it like any other change (PR #__ in my repo).
`git revert` is preferred over deleting the commit (`git reset` + force push) because history stays immutable: the bad change and its undo are both recorded and auditable, tags and other clones that already contain the commit do not break, and no force-push is needed on a protected branch.

### Q6 - (a) One repo for chart and config; (b) what is not under GitOps control

**(a)** Advantages: (1) one place to look - a reviewer sees chart and values together; (2) a release is atomic - one commit/tag contains the matching chart and values (e.g. backend 1.1 and its new setting in `v1.2.0`).
Disadvantages: (1) application changes and environment promotions are mixed in one history and one permission set - anyone who can change the chart can also change staging config; (2) every commit (even a README fix) is a new revision for every Application that follows `main`, and the staging tag must be cut for the whole repo. Argo CD best practices therefore recommend a separate config repo.

**(b)** Not under GitOps control after the rebuild:

| Item | How production teams usually handle it |
|---|---|
| Bootstrap layer (Argo CD install) | Installed by infrastructure-as-code (Terraform / cluster API) or a managed Argo CD, often then managed by Argo CD itself. |
| Root Application (+ platform project) | Created by the same IaC that creates the cluster, so it is reproducible without a person. |
| Sealing key | Stored in a cloud KMS / Vault / secret manager with access control and audit, or replaced by External Secrets Operator. |
| Database contents | Regular automated backups (e.g. Velero, `pg_dump` to object storage) or a managed database service with point-in-time recovery. |

Rebuild time in my test: [__ minutes from `kind create cluster` to a working dev frontend] (evidence Task 9).

## 11. Challenges

| Problem | Cause | Solution |
|---|---|---|
| Kustomize patch "no matches for argocd-cm.argocd" | upstream `install.yaml` ConfigMaps have no namespace | removed `namespace:` from both patches; the Kustomization adds it |
| Chart rendered Secret, ResourceQuota, LimitRange, PVC | A3 chart design | deleted those templates; DB -> StatefulSet; platform layer owns quota/RBAC |
| Browser could not reach the API (`tasktracker-backend` does not resolve outside the cluster; `localhost:8080` is used by the Argo CD port-forward) | A1-A3 had the browser call the backend directly | added `frontend-nginx-configmap.yaml`: nginx proxies `/api/` to the backend Service; `frontend.backendUrl` is the frontend's own URL per environment |
| Port 8081 (planned for the staging port-forward) was already used by another project on my machine | local port clash | moved staging to `localhost:8082`: changed `backendUrl` and `corsOrigin` in `environments/staging/values.yaml` (a values-only change), committed, and re-synced staging. NodePort 30081 is unchanged |
| Smoke-test Job below LimitRange minimum | A2 LimitRange min 50m / 64Mi | lowered min to 10m / 16Mi in `platform/<env>/quota-and-limits.yaml` |
| [add your own] | | |

## 12. Conclusion

[Write 4-6 sentences: what now happens when you merge a PR, how the faulty release was contained by the staging gate, how long the rebuild took, and what you would change for production.]

## 13. References

- Argo CD v3.5 documentation - https://argo-cd.readthedocs.io/ (Declarative Setup, Projects, Sync Phases and Waves, Automated Sync, Sync Options, Resource Health, RBAC, User Management, Multiple Sources, Best Practices)
- Sealed Secrets - https://github.com/bitnami/sealed-secrets
- OpenGitOps principles - https://opengitops.dev/
- Kubernetes documentation - https://kubernetes.io/docs/
- Helm documentation - https://helm.sh/docs/
- Kustomize - https://kustomize.io/
- Vinto, N. and Bueno, A. (2023) *GitOps Cookbook*. O'Reilly.
