# Age keys

Generate a key and load to Argo CD as Secret `sops-age`:

```sh
age-keygen -o age.agekey
kubectl -n argocd create secret generic sops-age \
  --from-file=keys.txt=./age.agekey
```

Then Argo repo-server will mount it per gitops/argocd/values/argocd-values.yaml.
