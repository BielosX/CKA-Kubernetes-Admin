#!/bin/bash

# Create static pod (managed directly by kubelet)
temp_path=$(mktemp)
kubectl run busybox \
  --image=busybox:1.36.0 \
  --dry-run=client \
  -o yaml -- sh -c 'sleep 10; echo "Hello"' > "$temp_path"
minikube cp "$temp_path" /etc/kubernetes/manifests/hello.yaml
rm "$temp_path"

# Expose Redis server created in test-namespace as NodePort service available on 30123
kubectl create namespace test-namespace
kubectl run redis --image=redis:7-alpine --port 6379 -n test-namespace
# Random NodePort will be generated
kubectl expose pod redis -n test-namespace --type NodePort --port 6379 --target-port 6379
# Setup editor
export KUBE_EDITOR=nvim
# Edit service config and change NodePort property to 30123
kubectl edit service redis -n test-namespace


# Deploy two replicas of Nginx version 1.23 then update image to 1.24
kubectl create deployment nginx --image=nginx:1.23 --replicas=2
kubectl set image deployment/nginx nginx=nginx:1.24


# Get podIPs of all Pods using JSONPATH
kubectl get pods -o=jsonpath='{.items[*].status.podIP}'


# Get podIPs of all Pods using JSONPATH, every IP in separated line
kubectl get pods -o=jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}'