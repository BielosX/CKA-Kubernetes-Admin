#!/bin/bash

kubeadm init
export KUBECONFIG=/etc/kubernetes/admin.conf
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

cp /etc/kubernetes/admin.conf "${config_path}/admin.conf"
kubeadm token create --print-join-command > "${config_path}/join.sh"
chmod +x "${config_path}/join.sh"