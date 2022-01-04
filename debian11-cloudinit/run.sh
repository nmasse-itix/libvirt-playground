#!/bin/bash

set -Eeuo pipefail

VM="${VM:-debian}"
BASEIMAGE="${BASEIMAGE:-https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2}"
BACKINGSTORE="${BACKINGSTORE:-debian-11-genericcloud-amd64.qcow2}"
OSINFO="debian11"

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

# Pre-requisites: dnf install mtools cloud-utils
echo "Generating cloud-init.iso..."

# Note: the Debian "genericcloud" image is smaller but does not include any driver for physical hardware.
# So we cannot use the default format (iso) since it is emulated as SATA by KVM.
# Therefore, we generate a VFAT image that will be mounted with virtio.
cloud-localds -f vfat "/var/lib/libvirt/images/$VM-cloud-init.img" user-data.yaml

# Also, the debian image requires to explicitely set the cloud datasource.
# For KVM, this is set via the SMBIOS "serial number" property. Hence, the --sysinfo below...
# See https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html
virt-install --name "$VM" --autostart --noautoconsole --import \
	     --cpu host-passthrough --vcpus 2 --ram 2048 \
	     --os-variant "$OSINFO" \
	     --disk "path=/var/lib/libvirt/images/$VM.qcow2,backing_store=/var/lib/libvirt/images/$BACKINGSTORE,size=10" \
	     --disk "path=/var/lib/libvirt/images/$VM-cloud-init.img,readonly=on" \
	     --network default \
	     --console pty,target.type=virtio --serial pty \
	     --sysinfo 'system.serial=ds=nocloud'
sleep 1
virsh console "$VM"

