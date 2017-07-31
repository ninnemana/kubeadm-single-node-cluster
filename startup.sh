#! /bin/bash

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo mv kubernetes.list /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y apt-transport-https
sudo apt-get install -y docker.io
sudo apt-get install -y kubelet kubeadm 

sudo systemctl enable docker.service

cat <<EOF > 20-cloud-provider.conf
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=gce"
EOF

sudo mv 20-cloud-provider.conf /etc/systemd/system/kubelet.service.d/
systemctl daemon-reload
systemctl restart kubelet

EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
KUBERNETES_VERSION=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/kubernetes-version)

cat <<EOF > kubeadm.conf
kind: MasterConfiguration
apiVersion: v1
kubernetesVersion: ${KUBERNETES_VERSION}
cloudProvider: gce
apiServerCertSANs:
  - 10.96.0.1
  - ${EXTERNAL_IP}
  - ${INTERNAL_IP}
EOF

sudo kubeadm init \
  --config=kubeadm.conf

sudo chmod 644 /etc/kubernetes/admin.conf

kubectl taint nodes --all node-role.kubernetes.io/master- \
  --kubeconfig /etc/kubernetes/admin.conf

kubectl apply \
  -f http://docs.projectcalico.org/v2.3/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml \
  --kubeconfig /etc/kubernetes/admin.conf
