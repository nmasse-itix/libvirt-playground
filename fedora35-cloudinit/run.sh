#!/bin/bash

set -Eeuo pipefail

VM="${VM:-fedora}"
BASEIMAGE="${BASEIMAGE:-https://download.fedoraproject.org/pub/fedora/linux/releases/35/Cloud/x86_64/images/Fedora-Cloud-Base-35-1.2.x86_64.qcow2}"
BACKINGSTORE="${BACKINGSTORE:-Fedora-Cloud-Base-35-1.2.x86_64.qcow2}"
OSINFO="fedora-35"

if [ "$UID" != "0" ]; then
  echo "Usage: sudo $0 [cleanup]"
  exit 1
fi

if virsh list --all --name | grep -xqF "$VM"; then
  echo "Cleaning up..."
  virsh destroy "$VM" || true
  virsh undefine "$VM" || true
  rm -f "/var/lib/libvirt/images/$VM.qcow2"
  sleep 1
fi

if [ "${1:-}" == "cleanup" ]; then
  exit 0
fi

if [ ! -f "/var/lib/libvirt/images/$BACKINGSTORE" ]; then
  echo "Downloading base image..."
  curl -Lo "/var/lib/libvirt/images/$BACKINGSTORE" "$BASEIMAGE"
fi

echo "Generating cloud-init.iso..."
cloud-localds "/var/lib/libvirt/images/$VM-cloud-init.iso" user-data.yaml

virt-install --name "$VM" --autostart --import --noautoconsole \
	     --cpu host-passthrough --vcpus 2 --ram 2048 \
	     --os-variant "$OSINFO" \
	     --disk "path=/var/lib/libvirt/images/$VM.qcow2,backing_store=/var/lib/libvirt/images/$BACKINGSTORE,size=10" \
	     --disk "path=/var/lib/libvirt/images/$VM-cloud-init.iso,readonly=on,device=cdrom" \
	     --network default \
	     --graphics none --console pty,target.type=virtio --serial pty
sleep 1
virsh console "$VM"
