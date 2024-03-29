#!/bin/bash

function build_sample_app() {
  eval "$(minikube docker-env)"
  timestamp=$(date +%s)
  pushd sample-app || exit
  echo "{ \"version\": \"${timestamp}\" }" > manifest.json
  docker build -t "sample-app:${timestamp}" -t "sample-app:latest" .
  popd || exit
}

function build_maven_env() {
  eval "$(minikube docker-env)"
  timestamp=$(date +%s)
  pushd job || exit
  docker build -t "maven-env:${timestamp}" -t "maven-env:latest" .
  popd || exit
}

function build_frontend() {
  eval "$(minikube docker-env)"
  pushd frontend || exit
  docker build -t frontend .
  popd || exit
  minikube image load frontend
}

function sample_app_clean() {
  docker image rm --force sample-app
}

function run_simple_pod() {
  build_sample_app
  temp_file=$(mktemp)
  sed -e "s/{tag}/${timestamp}/g" simple-pod/pod.yaml > "$temp_file"
  kubectl apply -f "$temp_file"
  rm -f "$temp_file"
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

function run_ingress() {
  minikube addons enable ingress
  kubectl apply -f ingress/backend-deployment.yaml
  kubectl apply -f ingress/frontend-deployment.yaml
  kubectl apply -f ingress/backend-service.yaml
  kubectl apply -f ingress/frontend-service.yaml
  kubectl apply -f ingress/ingress.yaml
}

function delete_ingress() {
  kubectl delete -f ingress/ingress.yaml
  kubectl delete -f ingress/frontend-service.yaml
  kubectl delete -f ingress/backend-service.yaml
  kubectl delete -f ingress/frontend-deployment.yaml
  kubectl delete -f ingress/backend-deployment.yaml
}

function create_namespaces() {
  kubectl apply -f namespaces/namespaces.yaml
}

function list_first_namespace() {
  kubectl get all --namespace=first-namespace
  minikube service first-deployment-service -n first-namespace --url
}

function list_second_namespace() {
  kubectl get all --namespace=second-namespace
  minikube service second-deployment-service -n second-namespace --url
}

function delete_namespaces() {
  kubectl delete namespace first-namespace
  kubectl delete namespace second-namespace
}

function deploy_init_container() {
  eval "$(minikube docker-env)"
  timestamp=$(date +%s)
  pushd init-container || exit
  kubectl apply -f db.yaml
  kubectl wait pods --for condition=Ready -l name=postgres --timeout 120s
  docker build -t "flyway-migration:${timestamp}" flyway
  yarn build
  docker build -t "demo-app:${timestamp}" .
  helm upgrade --set "app.flywayTag=${timestamp}" --set "app.tag=${timestamp}" --install app ./app
  popd || exit
}

function delete_init_container() {
  pushd init-container || exit
  helm uninstall app
  kubectl delete -f db.yaml
  popd || exit
}

function deploy_multi_container_pod() {
  kubectl apply -f multi-container-pod/config.yaml
  minikube service multi-container-pod-service --url
}

function delete_multi_container_pod() {
  kubectl delete -f multi-container-pod/config.yaml
}

function get_fluent_bit_logs() {
  kubectl logs -l name=multi-container-pod -c fluent-bit
}

function deploy_static_pod() {
  minikube cp static-pod/pod.yaml /etc/kubernetes/manifests/nginx.yaml
}

function deploy_startup_probe() {
  kubectl apply -f startup-probe/config.yaml
  kubectl wait pods --for condition=Ready -l name=postgres --timeout 120s
  minikube service startup-probe-service --url
}

function delete_startup_probe() {
  kubectl delete -f startup-probe/config.yaml
}

function deploy_rolling_deployment() {
  build_sample_app
  temp_file=$(mktemp)
  sed -e "s/{tag}/${timestamp}/g" deployment-strategy/rolling.yaml > "$temp_file"
  kubectl apply -f "$temp_file"
  kubectl rollout status deployment rolling-deployment
  rm -f "$temp_file"
  minikube service rolling-service --url
}

function rolling_deployment_rollback() {
  kubectl rollout undo deployment rolling-deployment
  kubectl rollout status deployment rolling-deployment
}

function deploy_recreate_deployment() {
  build_sample_app
  sed -e "s/{tag}/${timestamp}/g" deployment-strategy/recreate.yaml | kubectl apply -f -
  kubectl rollout status deployment recreate-deployment
  minikube service recreate-service --url
}

function recreate_deployment_rollback() {
  kubectl rollout undo deployment recreate-deployment
  kubectl rollout status deployment recreate-deployment
}

function create_build_job() {
  build_maven_env
  sed -e "s/{tag}/${timestamp}/g" job/job.yaml | kubectl apply -f -
  kubectl wait pods --for condition=Ready -l job-name=spring-petclinic-build --timeout 120s
  pod_name=$(kubectl get pods -l job-name=spring-petclinic-build -o json | jq -r '.items[0].metadata.name')
  kubectl logs "$pod_name" --follow
}

function delete_build_job() {
  kubectl delete job spring-petclinic-build
}

function create_build_cron_job() {
  build_maven_env
  sed -e "s/{tag}/${timestamp}/g" cron-job/config.yaml | kubectl apply -f -
}

function delete_build_cron_job() {
  kubectl delete cronjob spring-petclinic-periodic-build
}

function create_secret_deployment() {
  kubectl create secret generic postgres-credentials \
    --from-literal=USERNAME='demo-user' \
    --from-literal=PASSWORD='aphisoPTiVEnSimP'
  kubectl apply -f secrets/db.yaml
  kubectl apply -f secrets/volume-secret.yaml
  kubectl wait pods --for condition=Ready -l name=postgres --timeout 120s
  kubectl wait pods --for condition=Ready -l name=demo --timeout 120s
}

function delete_secret_deployment() {
  kubectl delete -f secrets/db.yaml
  kubectl delete -f secrets/secret.yaml
}

function connect_secret_deployment_db() {
  ip=$(minikube ip)
  node_port=$(kubectl get service db-service -o json | jq -r '.spec.ports[0].nodePort')
  username=$(kubectl get secret postgres-credentials -o json | jq -r '.data.USERNAME' | base64 -d)
  password=$(kubectl get secret postgres-credentials -o json | jq -r '.data.PASSWORD' | base64 -d)
  PGPASSWORD="$password" psql -h "$ip" -p "$node_port" -U "$username"
}

function get_secret_volume_content() {
  pod_name=$(kubectl get pods -l name=demo -o json | jq -r '.items[0].metadata.name')
  username=$(kubectl exec -it "$pod_name" -- cat /etc/demo/USERNAME)
  password=$(kubectl exec -it "$pod_name" -- cat /etc/demo/PASSWORD)
  echo "username: ${username}, password: ${password}"
}

function sidecar_nginx_proxy() {
  pushd sidecar-nginx-proxy || exit
   kubectl create configmap app-code \
     --from-file=main.py \
     --from-file=requirements.txt \
     --dry-run=client -o yaml | kubectl apply -f -
   kubectl create configmap nginx-conf \
     --from-file=nginx.conf \
     --dry-run=client -o yaml | kubectl apply -f -
   kubectl create configmap generate-cert \
     --from-file=cert.sh \
     --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f main.yaml
  minikube service sidecar --url
  popd || exit
}

function sidecar_nginx_proxy_delete() {
  pushd sidecar-nginx-proxy || exit
  kubectl delete -f main.yaml
  kubectl delete configmap generate-cert
  kubectl delete configmap nginx-conf
  kubectl delete configmap app-code
  popd || exit
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
  "run-ingress") run_ingress ;;
  "delete-ingress") delete_ingress ;;
  "create-namespaces") create_namespaces ;;
  "list-first-namespace") list_first_namespace ;;
  "list-second-namespace") list_second_namespace ;;
  "delete-namespaces") delete_namespaces ;;
  "deploy-init-container") deploy_init_container ;;
  "delete-init-container") delete_init_container ;;
  "deploy-multi-container-pod") deploy_multi_container_pod ;;
  "delete-multi-container-pod") delete_multi_container_pod ;;
  "get-fluent-bit-logs") get_fluent_bit_logs ;;
  "deploy-static-pod") deploy_static_pod ;;
  "deploy-startup-probe") deploy_startup_probe ;;
  "delete-startup-probe") delete_startup_probe ;;
  "deploy-rolling-deployment") deploy_rolling_deployment ;;
  "rolling-deployment-rollback") rolling_deployment_rollback ;;
  "deploy-recreate-deployment") deploy_recreate_deployment ;;
  "recreate-deployment-rollback") recreate_deployment_rollback ;;
  "create-build-job") create_build_job ;;
  "delete-build-job") delete_build_job ;;
  "create-build-cron-job") create_build_cron_job ;;
  "delete-build-cron-job") delete_build_cron_job ;;
  "create-secret-deployment") create_secret_deployment ;;
  "delete-secret-deployment") delete_secret_deployment ;;
  "connect-secret-deployment-db") connect_secret_deployment_db ;;
  "get-secret-volume-content") get_secret_volume_content ;;
  "sidecar-nginx-proxy") sidecar_nginx_proxy ;;
  "sidecar-nginx-proxy-delete") sidecar_nginx_proxy_delete ;;
esac
