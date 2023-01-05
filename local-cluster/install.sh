#!/bin/bash

yes | pacman -Syu
yes | pacman -S socat
yes | pacman -S ethtool
yes | pacman -S make
yes | pacman -S gcc
yes | pacman -S conntrack-tools
yes | pacman -S bridge-utils
yes | pacman -S kubectl

echo "Disable SWAP"

sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
swapoff -a

echo "Install ebtables"

wget -O ebtables.tar.gz "https://www.netfilter.org/pub/ebtables/ebtables-v2.0.10-4.tar.gz"
mkdir -p ebtables
tar -xf ebtables.tar.gz --strip-components 1 -C ebtables

pushd ebtables || exit
make CFLAGS='-Wunused -Wall -Werror -Wno-error=unused-but-set-variable'
make install \
    LIBDIR=/usr/lib \
    MANDIR=/usr/share/man \
    BINDIR=/usr/bin \
    INITDIR=/etc/rc.d \
    SYSCONFIGDIR=/etc
popd || exit

echo "br_netfilter" >> /etc/modules-load.d/br_netfilter.conf
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf <<-EOM
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOM

sysctl --system

echo "Install containerd"

CONTAINERD_VERSION="$1"
CONTAINERD_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
wget -nv -O containerd.tar.gz "$CONTAINERD_URL"
tar Cxzvf /usr/local containerd.tar.gz
mkdir -p /usr/local/lib/systemd/system
wget -nv -O /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

RUNC_VERSION="$2"
wget -nv -O runc.amd64 "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
install -m 755 runc.amd64 /usr/local/sbin/runc

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd.service
systemctl start containerd.service

echo "Install CNI plugins"

CNI_PLUGINS_VERSION="$3"
ARCH="amd64"
DEST="/opt/cni/bin"
mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz" | tar -C "$DEST" -xz


DOWNLOAD_DIR="/usr/local/bin"
mkdir -p "$DOWNLOAD_DIR"

echo "Download dir: ${DOWNLOAD_DIR}"

echo "Install CRICTL"

CRICTL_VERSION="$4"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | tar -C "$DOWNLOAD_DIR" -xz

echo "Install kubelet"

RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
ARCH="amd64"
cd "$DOWNLOAD_DIR"
curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
chmod +x {kubeadm,kubelet}

RELEASE_VERSION="$5"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable kubelet
systemctl start kubelet