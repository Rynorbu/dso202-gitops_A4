<!--
=============================================================================
File        : docs/evidence.md
Assignment  : DSO202 Assignment 4 - GitOps delivery with Argo CD
Descriptor  : 4.1-4.4 (evidence for every task)
Purpose     : Command output and screenshots proving each task. One section
              per task. Replace every "PASTE OUTPUT" block with real output.
              Never paste a password, the admin password or key contents.
=============================================================================
-->

# Evidence - DSO202 Assignment 4

Repository: https://github.com/Rynorbu/dso202-gitops_A4
Final commit on `main`: `PASTE git rev-parse HEAD`

---

## Task 1 - Repository, chart contract and cluster

### 1.1 Tool check
```text
PASTE OUTPUT of the 10 tool-check commands
```

### 1.2 Chart contract
See README section 5 (C1-C11 table).

### 1.3 helm lint (dev and staging)
```text
PASTE OUTPUT
```

### 1.4 Kinds rendered by the chart
```text
PASTE OUTPUT of helm template ... | grep '^kind:' | sort | uniq -c
```
**Observation:** no Secret, ResourceQuota, LimitRange, Role, RoleBinding or Namespace is rendered (C3, C8).

### 1.5 Cluster
```text
PASTE: kind get clusters / kind create cluster / kubectl config current-context / kubectl get nodes / docker ps (30080 mapping)
```

---

## Task 2 - Install Argo CD declaratively

### 2.1 Render check (before applying)
```text
PASTE: 6 Deployment + 1 StatefulSet, and the image list
```
### 2.2 Apply and wait
```text
PASTE: kubectl apply -k ... (last lines), kubectl wait, rollout status
```
### 2.3 Pods and CRDs
```text
PASTE: kubectl get pods -n argocd   (7 Running)
PASTE: kubectl get crd | grep argoproj.io
```
### 2.4 Local settings applied
```text
PASTE: kubectl get configmap argocd-cm ... | grep ...
PASTE: argocd version
```
![Argo CD UI after admin sign-in](screenshots/task2-argocd-ui.png)

---

## Task 3 - AppProjects and the root Application

### 3.1 Whitelist vs chart kinds
| Kind rendered by chart (Task 1.4) | In `dso202` whitelist |
|---|---|
| ConfigMap | yes |
| Deployment | yes |
| Service | yes |
| ServiceAccount | yes |
| StatefulSet | yes |
| Job (smoke test, Task 5) | yes |

### 3.2 Projects and root
```text
PASTE: kubectl get appproject,application -n argocd
PASTE: argocd app get root
PASTE: argocd proj get dso202
```
![root Application resource tree](screenshots/task3-root-tree.png)

---

## Task 4 - Platform layer and Sealed Secrets

### 4.1 Controller installed through Git
```text
PASTE: kubectl get applications -n argocd / kubectl get pods -n sealed-secrets / kubectl get crd sealedsecrets.bitnami.com
```
### 4.2 Sealing key backup (outside the repo and outside OneDrive)
```text
PASTE: ls -l ~/dso202-keys/     (NEVER the file contents)
```
### 4.3 Platform delivered
```text
PASTE: kubectl get applications -n argocd
PASTE: kubectl get namespaces | grep dso202
PASTE: kubectl get sealedsecret -n dso202-dev
PASTE: kubectl describe secret tasktracker-credentials -n dso202-dev      (key names + sizes only)
PASTE: kubectl describe secret tasktracker-credentials -n dso202-staging
PASTE: kubectl get resourcequota,limitrange -n dso202-dev
```
### 4.4 No plaintext in Git history
| Searched value (name only) | `git log -p --all -S'<value>' \| head` output |
|---|---|
| dev DB_USER | (empty) |
| dev DB_PASSWORD | (empty) |
| staging DB_USER | (empty) |
| staging DB_PASSWORD | (empty) |
```text
PASTE: git status --short --ignored
```

---

## Task 5 - Deliver workloads to dev and staging

### 5.1 Tag v1.0.0
```text
PASTE: git tag / git push origin v1.0.0
```
### 5.2 Dev: wave order and smoke test
```text
PASTE: kubectl get pods -n dso202-dev -w   (db -> backend -> frontend -> smoke-test)
PASTE: kubectl get job -n dso202-dev
PASTE: kubectl logs job/tasktracker-smoke-test -n dso202-dev
PASTE: argocd app get tasktracker-dev
```
![tasktracker-dev resource tree](screenshots/task5-dev-tree.png)

### 5.3 CRUD in dev
![Create](screenshots/task5-crud-create.png)
![Update](screenshots/task5-crud-update.png)
![Delete](screenshots/task5-crud-delete.png)

### 5.4 Staging (manual sync)
```text
PASTE: kubectl get applications -n argocd   (BEFORE staging sync: root state)
PASTE: argocd app get tasktracker-staging   (OutOfSync / Missing)
PASTE: argocd app sync tasktracker-staging
PASTE: kubectl get applications -n argocd   (AFTER: root Healthy)
```
![Staging frontend on localhost:8081](screenshots/task5-staging.png)

---

## Task 6 - Access control for Argo CD users

```text
PASTE: argocd account list
PASTE: the 5 reviewer commands (app list, 3x can-i, proj get platform)
PASTE: kubectl apply -k ... and can-i get logs  -> yes
```
![Reviewer cannot see logs (before)](screenshots/task6-reviewer-nologs.png)
![Reviewer sees Pod logs (after the commit)](screenshots/task6-reviewer-logs.png)

---

## Task 7 - A release, a faulty release and recovery

### 7.1 Pull requests
| PR | Title | Purpose |
|---|---|---|
| #1 | | frontend 1.1 |
| #2 | | promote staging to v1.1.0 |
| #3 | | backend 1.1 (faulty) |
| #4 | | revert backend 1.1 |
| #5 | | backend 1.1 + required setting |
| #6 | | promote staging to v1.2.0 |

![Pull request list](screenshots/task7-prs.png)

### 7.2 Frontend 1.1 in dev, staging gate
```text
PASTE: argocd app get tasktracker-dev / argocd app history tasktracker-dev
PASTE: argocd app get tasktracker-staging  (OutOfSync, not deployed)
```
![Dev header 1.1](screenshots/task7-dev-header-1.1.png)
![Staging still old header before sync](screenshots/task7-staging-old-header.png)

### 7.3 Faulty backend - observation (no intervention)
Bad commit: `_______`
```text
PASTE: kubectl get pods -n dso202-dev -w   (new Pod CrashLoopBackOff, old Pod still Running)
PASTE: argocd app get tasktracker-dev      (Synced + Degraded)
```
- New backend Pod state:
- Old backend Pod state:
- Sync / health:
- Smoke test ran?:
- Frontend still responds?:

![Degraded tasktracker-dev](screenshots/task7-degraded.png)

### 7.4 Diagnosis
```text
PASTE: kubectl describe pod ... / kubectl logs ...
```
Required by the image (exact log line): `PASTE`

### 7.5 Rollback refused
```text
PASTE: argocd app rollback tasktracker-dev
```

### 7.6 Recovery by git revert, fix forward, promotion
```text
PASTE: git revert ...
PASTE: argocd app get tasktracker-dev  (Healthy on 1.0)
PASTE: argocd app get tasktracker-dev  (Healthy on 1.1 with the setting, smoke test passed)
PASTE: argocd app history tasktracker-dev
PASTE: argocd app history tasktracker-staging   (never ran the faulty backend)
PASTE: git log --oneline --graph --decorate -n 15
```

---

## Task 8 - Drift, pruning and project guardrails

### Drill 1 - drift in dev
- **Prediction:** 
- **Commands and output:**
```text
PASTE
```
- **Result and explanation:** 

### Drill 2 - drift in staging
- **Prediction:** 
```text
PASTE
```
- **Result and explanation:** 

### Drill 3 - prune
- **Prediction:** 
```text
PASTE
```
- **Result and explanation:** (also explain why deleting `namespace.yaml` would NOT delete the namespace: `Prune=false`)

### Drill 4 - project guardrail
- **Prediction:** 
```text
PASTE (exact "not permitted in project" message)
```
![Drill 4 sync error](screenshots/task8-drill4.png)
- **Result and explanation:** (why staging is unaffected)

---

## Task 9 - Rebuild from Git

```text
PASTE: git rev-parse HEAD / kubectl get applications -n argocd (before)
PASTE: date (start) / kind delete / kind create
PASTE: key restore
PASTE: bootstrap commands
PASTE: kubectl get applications -n argocd -w   (order + times)
PASTE: argocd app sync tasktracker-staging
PASTE: date (end)
```
| Application | Healthy at |
|---|---|
| | |

Elapsed time from `kind create cluster` to working dev frontend: **__ min __ s**
Database contents were lost (not in Git): the tasks created before the rebuild are gone; one new task was created in each environment.

![Dev after rebuild](screenshots/task9-dev.png)
![Staging after rebuild](screenshots/task9-staging.png)
![All applications Healthy after rebuild](screenshots/task9-apps.png)

---

## Task 10 - Bonus: chart and values from separate sources

```text
PASTE: argocd app get tasktracker-dev   (2 sources, Synced, Healthy)
```
![Two sources](screenshots/task10-sources.png)

When separating sources helps: [one paragraph]
