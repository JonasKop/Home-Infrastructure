# Infrastructure

Create custom go container which updates haproxy.cfg config with consul stuff




New

1. Prepare proxmox node with Ansible
   - update node, install cloud-init
   - download ubuntu base cloud image
   - create template from the base image
2. Create proxy LXC container and 3 k8s VMS
   - install docker and create HAProxy container which runs as ordinary user
   - proxy should redirect proxmox.home.jonassjodin.com to 192.168.1.100:8006
   - proxy should lb port 8080 to k8s nodes 30080
   - proxy should lb port 8443 to k8s nodes 30443
   - proxy should redirect vpn on vpn.home.jonassjodin.com to openvpn VM
  
