#!/bin/bash

# Instance profile role is required that has atleast iam permission of ec2:Describe*

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay && sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
apt-get update && sudo apt-get install -y containerd
mkdir -p /etc/containerd && sudo containerd config default | sudo tee /etc/containerd/config.toml

systemctl restart containerd
systemctl status containerd

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubectl=1.21.0-00 kubeadm=1.21.0-00 kubelet=1.21.0-00
apt-mark hold kubelet kubectl kubeadm

HOSTNAME="$(hostname -f 2>/dev/null || curl http://169.254.169.254/latest/meta-data/local-hostname)"


# Setting --hostname-override is a workaround for https://github.com/kubernetes/kubeadm/issues/653
# Setting --cloud-provider is a workaround for https://github.com/kubernetes/kubeadm/issues/620
# Setting --authentication-token-webhook allows authenticated Prometheus access to the Kubelet metrics endpoint
# (see https://github.com/coreos/prometheus-operator/blob/master/contrib/kube-prometheus/docs/kube-prometheus-on-kubeadm.md)
/bin/cat > /etc/systemd/system/kubelet.service.d/10-hostname.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS= --hostname-override=${HOSTNAME} --cloud-provider=aws --authentication-token-webhook=true"
EOF

kubeadm join 172.31.5.61:6443 --token gora21.cxmfb878wqhddry0 --discovery-token-unsafe-skip-ca-verification
