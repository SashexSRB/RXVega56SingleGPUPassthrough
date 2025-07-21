#!/bin/bash
set -x  # Print each command for debug
exec >> /var/log/libvirt/qemu/hook-start.log 2>&1  # Log to file

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

echo "[INFO] ===== Starting VM hook: $(date) ====="

# Stop the display manager
echo "[INFO] Stopping display manager..."
systemctl stop sddm.service || echo "[WARN] Failed to stop sddm."

# Unbind VT consoles
for vt in /sys/class/vtconsole/vtcon*; do
    echo 0 > "$vt/bind" 2>/dev/null || echo "[WARN] Could not unbind $vt"
done

# Unbind EFI framebuffer
if [[ -e /sys/bus/platform/drivers/efi-framebuffer/unbind ]]; then
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind || echo "[WARN] Failed to unbind EFI framebuffer"
else
    echo "[INFO] No EFI framebuffer found, skipping unbind"
fi

# Optional delay to avoid race conditions
echo "[INFO] Sleeping to avoid race conditions..."
sleep 10

# Check if amdgpu is still used
if lsof /dev/dri/* | grep -q amdgpu; then
    echo "[ERROR] amdgpu is still in use! Aborting unload."
    lsof /dev/dri/* | grep amdgpu
    exit 1
fi

# Unload AMD GPU drivers
echo "[INFO] Unloading amdgpu and audio modules..."
modprobe -r amdgpu || echo "[WARN] Failed to unload amdgpu"
modprobe -r snd_hda_intel || echo "[WARN] Failed to unload snd_hda_intel"

# Detach GPU devices
echo "[INFO] Detaching GPU devices via virsh..."
virsh nodedev-detach "$VIRSH_GPU_VIDEO" || echo "[ERROR] Failed to detach GPU video"
virsh nodedev-detach "$VIRSH_GPU_AUDIO" || echo "[ERROR] Failed to detach GPU audio"

# Wait 10 more seconds
sleep 10

# Load VFIO modules
echo "[INFO] Loading VFIO kernel modules..."
modprobe vfio || echo "[ERROR] Failed to load vfio"
modprobe vfio-pci || echo "[ERROR] Failed to load vfio-pci"
modprobe vfio_iommu_type1 || echo "[ERROR] Failed to load vfio_iommu_type1"

echo "[INFO] ===== Hook complete ====="

