# Demo

# create clusters

./create_cluster dev

# bootstrap dev

flux bootstrap github \
 --context=kind-dev \
 --owner=allymparker \
 --repository=was_fleet \
 --branch=main \
 --interval=5s \
 --personal \
 --path=clusters/dev

git pull

# apply flux multitenancy isolation

# https://fluxcd.io/docs/installation/#multi-tenancy-lockdown

cat <<EOT >> ./clusters/dev/flux-system/kustomization.yaml
patches:

- patch: |
  - op: add
    path: /spec/template/spec/containers/0/args/0
    value: --no-cross-namespace-refs=true  
    target:
    kind: Deployment
    name: "(kustomize-controller|helm-controller|notification-controller|image-reflector-controller|image-automation-controller)"
- patch: |
  - op: add
    path: /spec/template/spec/containers/0/args/0
    value: --default-service-account=default  
    target:
    kind: Deployment
    name: "(kustomize-controller|helm-controller)"
- patch: | - op: add
  path: /spec/serviceAccountName
  value: kustomize-controller  
   target:
  kind: Kustomization
  name: "flux-system"
EOT

# add team1

mkdir -p ./tenants/base/team1

flux create tenant team1 --with-namespace=apps1 \
 --export > ./tenants/base/team1/rbac.yaml

flux create source git team1 \
 --namespace=apps1 \
 --url=https://github.com/allymparker/was_team1 \
 --branch=main \
 --interval=5s \
 --export > ./tenants/base/team1/sync.yaml

flux create kustomization team1 \
 --namespace=apps1 \
 --service-account=team1 \
 --source=GitRepository/team1 \
 --interval=5s \
 --prune=true \
 --path="./" \
 --export >> ./tenants/base/team1/sync.yaml

cd tenants/base/team1
kustomize create
kustomize edit add resource \*
cd ../../..

# add team2

mkdir -p ./tenants/base/team2

flux create tenant team2 --with-namespace=apps2 \
 --export > ./tenants/base/team2/rbac.yaml

flux create source git team2 \
 --namespace=apps2 \
 --url=https://github.com/allymparker/was_team2 \
 --branch=main \
 --interval=5s \
 --export > ./tenants/base/team2/sync.yaml

flux create kustomization team2 \
 --namespace=apps2 \
 --service-account=team2 \
 --source=GitRepository/team2 \
 --interval=5s \
 --prune=true \
 --path="./" \
 --export >> ./tenants/base/team2/sync.yaml

cd tenants/base/team2
kustomize create
kustomize edit add resource \*
cd ../../..

# add tenant overlays

mkdir -p tenants/dev
cd tenants/dev

kustomize create --resources ../base/team1,../base/team2

cat <<EOF > team1-patch.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
name: team1
namespace: apps1
spec:
path: ./dev
EOF

kubectl create quota quota --namespace apps1 --hard=cpu=1 --dry-run=client -oyaml >> team1-quota.yaml

kustomize edit add patch --path team1-patch.yaml
kustomize edit add resource team1-quota.yaml

cat <<EOF > team2-patch.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
name: team2
namespace: apps2
spec:
path: ./dev
EOF

kubectl create quota quota --namespace apps2 --hard=cpu=0.2 --dry-run=client -oyaml >> team2-quota.yaml

kustomize edit add patch --path team2-patch.yaml
kustomize edit add resource team2-quota.yaml
cd ../..

flux create kustomization tenants \
--path=./tenants/dev \
--interval=5s \
--source flux-system \
--service-account=kustomize-controller \
--prune=true \
--export > clusters/dev/tenants.yaml

# Let's be naughty

cd ../team1/dev
kubectl create deploy --namespace=apps2 naughty --image=nginx --dry-run=client -oyaml > naughty.yaml
kubectl create ns naughty --dry-run=client -oyaml > naughtyns.yaml

git add .
git commit -am .
git push

# Resource Quota

kubectl scale -n apps2 deployment team2-app --replicas 3
k get events -n apps2

kubectl describe -n apps2 deployments.apps team2-app
