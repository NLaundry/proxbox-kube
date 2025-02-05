
# ADJUST config kubeadm-config.yaml.j2 to have HA virtual IP endpoint

apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "{{ hostvars[inventory_hostname]['ansible_host'] }}:6443"
networking:
  podSubnet: "10.244.0.0/16"

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: "{{ inventory_hostname }}"
  criSocket: "/run/containerd/containerd.sock"
  kubeletExtraArgs:
    cgroup-driver: systemd

Let's iterate on this config file. Let's assume the IP for this is 192.168.100.100 because this will be the virtual IP assigned in haproxy and keepalived. Is that correct/possible? The name of it given by DNS should be kube-controlPlaneEndpoint


## Setup VIP in router

192.168.100.100 = VIP for control nodes
