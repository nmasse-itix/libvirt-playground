#!/bin/bash

set -Eeuo pipefail

VM="${VM:-fcos}"
BASEIMAGE="${BASEIMAGE:-https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20211203.3.0/x86_64/fedora-coreos-35.20211203.3.0-qemu.x86_64.qcow2.xz}"
BACKINGSTORE="${BACKINGSTORE:-fedora-coreos-35-qemu.x86_64.qcow2}"
OSINFO="fedora-coreos-stable"

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
  curl -L "$BASEIMAGE" | xz -dc > "/var/lib/libvirt/images/$BACKINGSTORE"
fi

# Pre-requisites: dnf install butane
echo "Generating ignition file..."
butane --pretty --strict < "$PWD/fcos.yaml" > "/var/lib/libvirt/images/$VM.ign"

virt-install --name "$VM" --autostart --import --noautoconsole \
	     --cpu host-passthrough --vcpus 2 --ram 3074 \
	     --os-variant "$OSINFO" \
	     --disk "path=/var/lib/libvirt/images/$VM.qcow2,backing_store=/var/lib/libvirt/images/$BACKINGSTORE,size=10" \
	     --disk "path=/var/lib/libvirt/images/$VM-var.qcow2,size=10" \
	     --network default \
       --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/var/lib/libvirt/images/$VM.ign" \
	     --graphics none --console pty,target.type=virtio --serial pty
sleep 1
virsh console "$VM"

