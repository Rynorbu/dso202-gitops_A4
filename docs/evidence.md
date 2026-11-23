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
$ helm lint charts/tasktracker -f environments/dev/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm lint charts/tasktracker -f environments/staging/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```
**Observation:** the chart passes lint for both environments with no errors or warnings (C11). The `[INFO]` line is only a suggestion to add an icon.

### 1.4 Kinds rendered by the chart
```text
$ helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep '^kind:' | sort | uniq -c
      2 kind: ConfigMap
      2 kind: Deployment
      3 kind: Service
      1 kind: ServiceAccount
      1 kind: StatefulSet
```
The two ConfigMaps are the application settings (`tasktracker-config`) and the frontend nginx proxy (`tasktracker-frontend-nginx`).
**Observation:** no Secret, ResourceQuota, LimitRange, Role, RoleBinding or Namespace is rendered (C3, C8).

### 1.5 Cluster
```text
PASTE: kind get clusters / kind create cluster / kubectl config current-context / kubectl get nodes / docker ps (30080 mapping)
```

---

## Task 2 - Install Argo CD declaratively

### 2.1 Render check (before applying)
```text
$ kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$' | sort | uniq -c
      6 kind: Deployment
      1 kind: StatefulSet

$ kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u
        image: ghcr.io/dexidp/dex:v2.45.1
        image: public.ecr.aws/docker/library/redis:8.2.3-alpine
        image: quay.io/argoproj/argocd:v3.5.6
```
**Observation:** before anything was applied, the Kustomization renders the expected 6 Deployments (server, repo-server, applicationset-controller, notifications-controller, dex-server, redis) and 1 StatefulSet (application-controller). Every Argo CD image is pinned to **v3.5.6**, and the only other images are Dex and Redis from their official registries. The upstream manifest is pinned by URL (`.../argo-cd/v3.5.6/manifests/install.yaml`), so the install is reproducible from Git.
### 2.2 Apply and wait
```text
$ kubectl apply -k bootstrap/argocd --server-side --force-conflicts
namespace/argocd serverside-applied
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io serverside-applied
serviceaccount/argocd-application-controller serverside-applied
... (ServiceAccounts, Roles, ClusterRoles and bindings trimmed) ...
configmap/argocd-cm serverside-applied
configmap/argocd-cmd-params-cm serverside-applied
configmap/argocd-gpg-keys-cm serverside-applied
configmap/argocd-notifications-cm serverside-applied
configmap/argocd-rbac-cm serverside-applied
configmap/argocd-ssh-known-hosts-cm serverside-applied
configmap/argocd-tls-certs-cm serverside-applied
secret/argocd-notifications-secret serverside-applied
secret/argocd-secret serverside-applied
... (Services trimmed) ...
deployment.apps/argocd-applicationset-controller serverside-applied
deployment.apps/argocd-dex-server serverside-applied
deployment.apps/argocd-notifications-controller serverside-applied
deployment.apps/argocd-redis serverside-applied
deployment.apps/argocd-repo-server serverside-applied
deployment.apps/argocd-server serverside-applied
statefulset.apps/argocd-application-controller serverside-applied
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy serverside-applied
... (6 more NetworkPolicies trimmed) ...
networkpolicy.networking.k8s.io/argocd-server-network-policy serverside-applied

$ kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
deployment.apps/argocd-applicationset-controller condition met
deployment.apps/argocd-dex-server condition met
deployment.apps/argocd-notifications-controller condition met
deployment.apps/argocd-redis condition met
deployment.apps/argocd-repo-server condition met
deployment.apps/argocd-server condition met

$ kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
partitioned roll out complete: 1 new pods have been updated...
```
**Observation:** server-side apply was needed (`--server-side --force-conflicts`). The `applicationsets` CRD is larger than the 256 KB limit of the `last-applied-configuration` annotation that client-side apply writes. `argocd-cm` and `argocd-rbac-cm` were applied with my patches already merged by Kustomize, so no manual edit of the cluster was needed.
### 2.3 Pods and CRDs
```text
$ kubectl get pods -n argocd
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          4m30s
argocd-applicationset-controller-58bb5c7479-zpj66   1/1     Running   0          4m31s
argocd-dex-server-dd6b85d9c-2spfq                   1/1     Running   0          4m31s
argocd-notifications-controller-6b85c65458-7wwq2    1/1     Running   0          4m31s
argocd-redis-869b85489d-xrrjt                       1/1     Running   0          4m31s
argocd-repo-server-5bf66565cd-njdjw                 1/1     Running   0          4m30s
argocd-server-7474bb8f76-h8h8z                      1/1     Running   0          4m30s

$ kubectl get crd | grep argoproj.io
applications.argoproj.io      2026-11-23T08:22:40Z
applicationsets.argoproj.io   2026-11-23T08:22:41Z
appprojects.argoproj.io       2026-11-23T08:22:41Z
```
**Observation:** all 7 Argo CD Pods are Running and Ready with 0 restarts. The 3 Argo CD CRDs (Application, ApplicationSet, AppProject) are installed.
### 2.4 Local settings applied
```text
$ argocd admin initial-password -n argocd
(output not shown - the initial admin password is never recorded)

$ kubectl get configmap argocd-cm -n argocd -o yaml | grep -E 'timeout.reconciliation|accounts.reviewer'
  accounts.reviewer: login
  timeout.reconciliation: 60s
  timeout.reconciliation.jitter: 10s

$ argocd version
argocd: v3.5.6+c2b1e30
  BuildDate: 2026-10-20T19:01:52Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
  GitTreeState: clean
  GoVersion: go1.26.10
  Compiler: gc
  Platform: linux/amd64
PASTE: the "argocd-server: v3.5.6..." lines after running argocd login
```
**Observation:** my `argocd-cm` patch is live in the cluster. Argo CD polls Git every 60 s, with up to 10 s of jitter, and the local account `reviewer` exists with login permission (used in Task 6). The CLI is v3.5.6, the same version as the server.
![Argo CD UI after admin sign-in](screenshots/task2-argocd-ui.png)

---

## Task 3 - AppProjects and the root Application

### 3.1 Whitelist vs chart kinds
The kinds rendered by the chart (Task 1.4) compared with `namespaceResourceWhitelist` in `argocd/projects/dso202.yaml`:

| Kind rendered by chart | Count | Objects | Group | In `dso202` whitelist |
|---|---|---|---|---|
| ConfigMap | 2 | `tasktracker-config`, `tasktracker-frontend-nginx` | `""` (core) | yes |
| Deployment | 2 | `tasktracker-backend`, `tasktracker-frontend` | `apps` | yes |
| Service | 3 | `tasktracker-db`, `tasktracker-backend`, `tasktracker-frontend` | `""` (core) | yes |
| ServiceAccount | 1 | `tasktracker` | `""` (core) | yes |
| StatefulSet | 1 | `tasktracker-db` | `apps` | yes |
| Job (PostSync smoke test, added in Task 5) | 1 | `tasktracker-smoke-test` | `batch` | yes |

| *ReplicaSet (child, added in Task 6)* | - | created by each Deployment | `apps` | yes |
| *ControllerRevision (child, added in Task 6)* | - | created by the StatefulSet | `apps` | yes |
| *Pod (child, added in Task 6)* | - | created by ReplicaSets / StatefulSet / Job | `""` (core) | yes |

**Result:** the whitelist has the 6 kinds the chart renders, and every one is used, so nothing is allowed that the chart does not need (least privilege).
- **Child kinds (found in Task 6):** Argo CD filters the application's resource tree through the project whitelist. With only the 6 rendered kinds, the tree stopped at the Deployments: the UI showed "Your application has no pod groups" and `argocd app logs` returned nothing, even after RBAC allowed logs. ReplicaSet, ControllerRevision and Pod were added. Git never contains them, so this lets Argo CD *see* the Pods; it does not widen what the chart deploys in practice.
- **Not in the whitelist on purpose:** Secret (comes from SealedSecrets), ResourceQuota, LimitRange, Role, RoleBinding (platform layer, `platform` project), PersistentVolumeClaim (the StatefulSet creates its own PVC through `volumeClaimTemplates`, so the chart never renders one) and Ingress (C9).
- **Cluster-scoped kinds:** `clusterResourceWhitelist: []`, so the workload project cannot create Namespaces, ClusterRoles or CRDs.
- Drill 4 in Task 8 proves this: a ResourceQuota added to the chart is refused with "not permitted in project".

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

![task5-tag-v1.0.0](screenshots/task5-tag-v1.0.0.png)

```text
PASTE: git tag / git push origin v1.0.0
```
### 5.2 Dev: wave order and smoke test

![task5-dev-progressing](screenshots/task5-dev-progressing.png)
![task5-wave-order](screenshots/task5-wave-order.png)
![task5-smoke-test](screenshots/task5-smoke-test.png)

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

![task5-staging-before-cli](screenshots/task5-staging-before-cli.png)
![task5-staging-after-cli](screenshots/task5-staging-after-cli.png)
![task5-staging-outofsync](screenshots/task5-staging-outofsync.png)
![task5-all-apps](screenshots/task5-all-apps.png)

```text
PASTE: kubectl get applications -n argocd   (BEFORE staging sync: root state)
PASTE: argocd app get tasktracker-staging   (OutOfSync / Missing)
PASTE: argocd app sync tasktracker-staging
PASTE: kubectl get applications -n argocd   (AFTER: root Healthy)
```
![Staging frontend on localhost:8082](screenshots/task5-staging.png)

---

## Task 6 - Access control for Argo CD users

![task6-account-list](screenshots/task6-account-list.png)
![task6-reviewer-cani](screenshots/task6-reviewer-cani.png)
![task6-logs-enabled](screenshots/task6-logs-enabled.png)


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

![task7-dev-history](screenshots/task7-dev-history.png)
![task7-staging-outofsync-cli](screenshots/task7-staging-outofsync-cli.png)

```text
PASTE: argocd app get tasktracker-dev / argocd app history tasktracker-dev
PASTE: argocd app get tasktracker-staging  (OutOfSync, not deployed)
```
![Dev header 1.1](screenshots/task7-dev-header-1.1.png)
![Staging still old header before sync](screenshots/task7-staging-old-header.png)

### 7.3 Faulty backend - observation (no intervention)

![task7-degraded-cli](screenshots/task7-degraded-cli.png)

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

![task7-pod-describe](screenshots/task7-pod-describe.png)

```text
PASTE: kubectl describe pod ... / kubectl logs ...
```
Required by the image (exact log line): `PASTE`

### 7.5 Rollback refused

![task7-rollback-refused](screenshots/task7-rollback-refused.png)

```text
PASTE: argocd app rollback tasktracker-dev
```

### 7.6 Recovery by git revert, fix forward, promotion

![task7-revert-healthy](screenshots/task7-revert-healthy.png)
![task7-fixforward-healthy](screenshots/task7-fixforward-healthy.png)
![task7-history-gitlog](screenshots/task7-history-gitlog.png)

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

![task8-drill1](screenshots/task8-drill1.png)

- **Prediction:** 
- **Commands and output:**
```text
PASTE
```
- **Result and explanation:** 

### Drill 2 - drift in staging

![task8-drill2](screenshots/task8-drill2.png)

- **Prediction:** 
```text
PASTE
```
- **Result and explanation:** 

### Drill 3 - prune

![task8-drill3](screenshots/task8-drill3.png)

- **Prediction:** 
```text
PASTE
```
- **Result and explanation:** (also explain why deleting `namespace.yaml` would NOT delete the namespace: `Prune=false`)

### Drill 4 - project guardrail

![task8-drill4-cli](screenshots/task8-drill4-cli.png)

- **Prediction:** 
```text
PASTE (exact "not permitted in project" message)
```
![Drill 4 sync error](screenshots/task8-drill4.png)
- **Result and explanation:** (why staging is unaffected)

---

## Task 9 - Rebuild from Git

![task9-before](screenshots/task9-before.png)
![task9-start](screenshots/task9-start.png)
![task9-key-restore](screenshots/task9-key-restore.png)
![task9-apps-order](screenshots/task9-apps-order.png)
![task9-staging-sync](screenshots/task9-staging-sync.png)
![task9-end](screenshots/task9-end.png)


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

![task10-cli](screenshots/task10-cli.png)


```text
PASTE: argocd app get tasktracker-dev   (2 sources, Synced, Healthy)
```
![Two sources](screenshots/task10-sources.png)

When separating sources helps: [one paragraph]
