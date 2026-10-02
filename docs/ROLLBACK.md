# Rollback Strategy

## GitOps rollback (recommended)

Git is the source of truth.

```bash
git log --oneline -- helm/python-app/values.yaml
git revert <bad-commit>
git push origin main
```

Argo CD detects the reverted desired state and deploys the previous image.

## Argo CD rollback

If Argo CD CLI is installed:

```bash
argocd app history python-app
argocd app rollback python-app <HISTORY_ID>
```

Because GitOps expects Git to remain authoritative, follow a manual Argo CD rollback with a Git revert or equivalent desired-state correction.

## Kubernetes emergency rollback

```bash
./scripts/rollback.sh
```

Verify:

```bash
kubectl -n python-app rollout status deployment/python-app
kubectl -n python-app get pods
```

## Deployment safety

The Deployment uses:

- RollingUpdate
- maxUnavailable: 0
- maxSurge: 1
- readiness probes
- liveness probes
- revisionHistoryLimit: 5
- HPA
- PDB

These controls reduce the chance of serving an unhealthy revision.
