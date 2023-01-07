#!/bin/bash

if [ -z "$NODES" ]; then
    NODES=1
fi

function start_cluster() {
    pushd local-cluster || exit
    NODES="$NODES" vagrant up
    popd || exit
}

function delete_cluster() {
    pushd local-cluster || exit
    vagrant destroy -f
    popd || exit
}

function create_daemonset() {
  kubectl apply -f daemon-set/daemonset.yaml
}

function delete_daemonset() {
  kubectl delete -f daemon-set/daemonset.yaml
}

case "$1" in
    "start-cluster") start_cluster ;;
    "delete-cluster") delete_cluster ;;
    "create-daemonset") create_daemonset ;;
    "delete-daemonset") delete_daemonset ;;
esac
