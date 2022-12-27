#!/bin/bash

function build_sample_app() {
  pushd sample-app || exit
  docker build -t sample-app .
  popd || exit
  minikube image load sample-app
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

case "$1" in
  "build-sample-app") build_sample_app ;;
  "simple-pod") run_simple_pod ;;
  "delete-simple-pod") delete_simple_pod ;;
  "sample-app-clean") sample_app_clean ;;
  "restart-simple-deployment") restart_simple_deployment ;;
  "create-simple-deployment") create_simple_deployment ;;
  "delete-simple-deployment") delete_simple_deployment ;;
esac