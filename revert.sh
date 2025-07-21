#!/bin/bash
set -x  # Print each command for debug
exec >> /var/log/libvirt/qemu/hook-release.log 2>&1  # Log to file

echo "[INFO] ===== Revert VM hook: $(date) ====="

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Stop display manager before releasing GPU
echo "[INFO] Stopping display manager..."
systemctl stop sddm.service || echo "[WARN] Failed to stop sddm."

# Unbind devices from vfio-pci
echo "[INFO] Unbinding GPU from vfio-pci..."
echo -n "$VIRSH_GPU_VIDEO" > /sys/bus/pci/devices/$VIRSH_GPU_VIDEO/driver/unbind || echo "[WARN] Failed to unbind GPU video"
echo -n "$VIRSH_GPU_AUDIO" > /sys/bus/pci/devices/$VIRSH_GPU_AUDIO/driver/unbind || echo "[WARN] Failed to unbind GPU audio"

# Remove vfio modules
echo "[INFO] Removing VFIO kernel modules..."
modprobe -r vfio-pci || echo "[WARN] Failed to remove vfio-pci"
modprobe -r vfio_iommu_type1 || echo "[WARN] Failed to remove vfio_iommu_type1"
modprobe -r vfio || echo "[WARN] Failed to remove vfio"

echo "[INFO] Sleeping for 5 seconds..."
sleep 5

# Reload AMD GPU and sound modules
echo "[INFO] Reloading amdgpu and snd_hda_intel modules..."
modprobe amdgpu || echo "[WARN] Failed to load amdgpu"
modprobe snd_hda_intel || echo "[WARN] Failed to load snd_hda_intel"

# Reattach devices to original drivers
echo "[INFO] Reattaching audio function first..."
virsh nodedev-reattach "$VIRSH_GPU_AUDIO" || echo "[WARN] Failed to reattach GPU audio"

echo "[INFO] Sleeping for 1 second..."
sleep 1

echo "[INFO] Reattaching main GPU..."
virsh nodedev-reattach "$VIRSH_GPU_VIDEO" || echo "[WARN] Failed to reattach GPU video"

# Rebind virtual terminals (console)
echo "[INFO] Rebinding virtual terminals..."
echo 1 > /sys/class/vtconsole/vtcon0/bind || echo "[WARN] Failed to bind vtcon0"
echo 1 > /sys/class/vtconsole/vtcon1/bind || echo "[WARN] Failed to bind vtcon1"

# Rebind framebuffer (if applicable)
if [[ -e /sys/bus/platform/drivers/efi-framebuffer/bind ]]; then
    echo "[INFO] Rebinding EFI framebuffer..."
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind || echo "[WARN] Failed to bind EFI framebuffer"
else
    echo "[INFO] No EFI framebuffer found, skipping bind"
fi

echo "[INFO] Sleeping for 3 seconds..."
sleep 3

# Start display manager
echo "[INFO] Starting display manager..."
systemctl start sddm.service || echo "[WARN] Failed to start sddm."

echo "[INFO] ===== Hook revert complete ====="
