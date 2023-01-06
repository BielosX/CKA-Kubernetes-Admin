#!/bin/bash

eth1_ip=$(ip -f inet addr show eth1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p' | head -n 1 | xargs)
kubeadm init --apiserver-advertise-address="$eth1_ip" --pod-network-cidr="172.16.0.0/16"
export KUBECONFIG=/etc/kubernetes/admin.conf
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml

config_path="/vagrant/configs"

cp /etc/kubernetes/admin.conf "${config_path}/admin.conf"
join_command="$(kubeadm token create --print-join-command) -v 5"
echo "$join_command" > "${config_path}/join.sh"
chmod +x "${config_path}/join.sh"