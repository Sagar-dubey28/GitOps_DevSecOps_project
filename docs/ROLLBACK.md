# Rollback Strategy

## Preferred: Git revert

Git is the source of truth.

```bash
git log --oneline -- helm/python-app/values.yaml
git revert <bad-commit>
git push origin main
```

Argo CD detects the desired-state change and deploys the previous SHA-tagged image.

## Emergency Kubernetes rollback

```bash
./scripts/rollback.sh
```

This invokes:

```bash
kubectl rollout undo deployment/python-app
```

It is temporary if Argo CD automated sync is enabled. Follow it with a Git
revert to make the rollback permanent.

## Argo CD history

```bash
kubectl -n argocd get application python-app -o yaml
```

If using the Argo CD CLI:

```bash
argocd app history python-app
```

Prefer correcting Git rather than leaving the cluster in a state that differs
from the repository.
