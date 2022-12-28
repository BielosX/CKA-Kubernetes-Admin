#!/bin/bash

function build_sample_app() {
  eval "$(minikube docker-env)"
  pushd sample-app || exit
  docker build -t sample-app .
  popd || exit
  minikube image load sample-app
}

function build_frontend() {
  pushd frontend || exit
  docker build -t frontend .
  popd || exit
}

function sample_app_clean() {
  docker image rm --force sample-app
}

function run_simple_pod() {
  kubectl apply -f simple-pod/pod.yaml
  kubectl apply -f simple-pod/service.yaml
  minikube service simple-service --url
}

function delete_simple_pod() {
  kubectl delete -f simple-pod/service.yaml
  kubectl delete -f simple-pod/pod.yaml
}

function restart_simple_deployment() {
  kubectl rollout restart deployment simple-deployment
}

function create_simple_deployment() {
  kubectl apply -f simple-deployment/deployment.yaml
  kubectl apply -f simple-deployment/service.yaml
  minikube service simple-deployment-service --url
}

function delete_simple_deployment() {
  kubectl delete -f simple-deployment/service.yaml
  kubectl delete -f simple-deployment/deployment.yaml
}

function set_pod_health_unhealthy() {
  url=$(minikube service pod-health-check-service --url)
  curl -X POST "${url}/health" --data '{"health": "UNHEALTHY"}' -H 'Content-Type: application/json'
}

function set_pod_health_healthy() {
  url=$(minikube service pod-health-check-service --url)
  curl -X POST "${url}/health" --data '{"health": "HEALTHY"}' -H 'Content-Type: application/json'
}

function run_pod_health_check() {
  kubectl apply -f pod-health-check/pod.yaml
  kubectl apply -f pod-health-check/service.yaml
}

function delete_pod_health_check() {
  kubectl delete -f pod-health-check/service.yaml
  kubectl delete -f pod-health-check/pod.yaml
}

function describe_pod_health_check() {
    kubectl describe pods pod-health-check
}

case "$1" in
  "build-sample-app") build_sample_app ;;
  "simple-pod") run_simple_pod ;;
  "delete-simple-pod") delete_simple_pod ;;
  "sample-app-clean") sample_app_clean ;;
  "restart-simple-deployment") restart_simple_deployment ;;
  "create-simple-deployment") create_simple_deployment ;;
  "delete-simple-deployment") delete_simple_deployment ;;
  "set-pod-health-unhealthy") set_pod_health_unhealthy ;;
  "set-pod-health-healthy") set_pod_health_healthy ;;
  "run-pod-health-check") run_pod_health_check ;;
  "delete-pod-health-check") delete_pod_health_check ;;
  "describe-pod-health-check") describe_pod_health_check ;;
  "build-frontend") build_frontend ;;
esac