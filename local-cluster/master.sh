#!/bin/bash

kubeadm init
export KUBECONFIG=/etc/kubernetes/admin.conf
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml