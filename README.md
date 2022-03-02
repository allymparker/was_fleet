# Demo

Multi Cluster
Multi Team
onboard new tenant
fail to deploy to another ns
fail to go over RQ

flux bootstrap github \
 --context=kind-dev \
 --owner=allymparker \
 --repository=was_fleet \
 --branch=main \
 --personal \
 --path=clusters/dev

add team2

mkdir -p ./tenants/base/team2

flux create tenant team2 --with-namespace=apps2 \
 --export > ./tenants/base/team2/rbac.yaml

flux create source git team2 \
 --namespace=apps2 \
 --url=https://github.com/allymparker/was_team2 \
 --branch=main \
 --export > ./tenants/base/team2/sync.yaml

flux create kustomization team2 \
 --namespace=apps2 \
 --service-account=team2 \
 --source=GitRepository/team2 \
 --path="./" \
 --export >> ./tenants/base/team2/sync.yaml

kustomize create
kustomize add resource *