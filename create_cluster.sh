#!/bin/bash
if kind get clusters | grep $1; then
	kind delete cluster --name $1
fi

kind create cluster --name $1
docker cp ~/tesco_root_ca.pem "$1-control-plane":/usr/local/share/ca-certificates/tesco_root_ca.crt 
docker exec -i "$1-control-plane" bash -c "update-ca-certificates && systemctl restart containerd"