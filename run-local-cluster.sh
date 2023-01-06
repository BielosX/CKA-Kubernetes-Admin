#!/bin/bash

if [ -z "$NODES" ]; then
    NODES=2
fi

function start_cluster() {
    pushd local-cluster || exit
    NODES="$NODES" vagrant up
    config
    popd || exit
}

function delete_cluster() {
    pushd local-cluster || exit
    vagrant destroy -f
    popd || exit
}

case "$1" in
    "start-cluster") start_cluster ;;
    "delete-cluster") delete_cluster ;;
esac