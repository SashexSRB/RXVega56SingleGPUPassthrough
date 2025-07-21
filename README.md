# Single GPU Passthrough for RX Vega 56
This is a guide for passing an RX Vega 56 to a Windows 10 Guest VM on ArchLinux.

# Step 1: Enabling IOMMU in UEFI
If you have Intel CPU, enable VT-d and VT-x.
If you have AMD CPU, enable SVM Mode and IOMMU

# Step 2: Editing GRUB Boot Params
Edit `/etc/default/grub` and put following in the line `GRUB_CMDLINE_LINUX_DEFAULT`

For AMD:
``amd_iommu=on iommu=pt iommu=1 video=efifb:off vfio.pci.ids=XXXX:XXXX,XXXX:XXXX`` 
(Replace X's with the PCI Addresses of your GPU Video and Audio, in my case: 1002:687f, 1002:aaf8)

For Intel:
`intel_iommu=on iommu=pt video=efif:off` (Not sure if additional params are needed. I do not use Intel)

Reboot your PC.

# Step 3: Check IOMMU Groups
To check if IOMMU is enabled, enter this command.
``sudo dmesg | grep -i -e DMAR -e IOMMU``
If you get a response, you're good.

# Step 4: Install tools
Enter this command:
``sudo pacman -S virt-manager qemu vde2 ebtables iptables-nft nftables dnsmasq bridge-utils ovmf``

# Step 5: Edit Config
1. Edit this file: `/etc/libvirt/libvirtd.conf`. Uncomment the # off the following lines:
```
unix_sock_group = "libvirt"
unix_sock_rw_perms = "0770"
```
2. Add these lines at the end of the file:
```
log_filters="1:qemu"
log_outputs="1:file:/var/log/libvirt/libvirtd.log"
```
3. Save the file. 
4. Now enter following commands:
  - ``sudo usermod -a -G libvirt $(whoami)``
  - ``sudo systemctl start libvirtd``
  - ``sudo systemctl enable libvirtd``
5. Now edit this file: `/etc/libvirt/qemu.conf`
  - change `#user = "root"`` to ``user = "your username"`
  - and `#group = "root"`` to ``group = "your username"`
6. Now restart libvirt:
  - ``sudo systemctl restart libvirtd``
7. To get networking working enter these commands:
  - ``sudo virsh net-autostart default``
  - ``sudo virsh net-start default``

# Step 6: Configure VM
1. Download Windows 10 ISO.
2. Open virt-manager and create a new VM
3. Leave default VM name.
4. Once you see overview section, select customize before installation
5. Make sure the firmware is Q35 and OVMF.fd (UEFI)
6. Uncheck the copy host CPU config box and set it to host-passthrough
7. Optionally use virtio network type and disk. For that you have to add virtio-win.iso disk into a CD-ROM

# Step 7. Passthrough corresponding GPU vBIOS.
1. Either dump it yourself (amdvbflash or nvflash), GPU-Z using Windows or find one on https://www.techpowerup.com/vgabios/. You need the exact vBIOS for your own Card. Every GPU Vendor has its own vBIOS. So my GPU.rom will not work unless you also have MSI RX Vega 56 AirBoost. 
2. Copy it to the following path and rename it: `/var/lib/libvirt/vbios/GPU.rom`
3. For NVIDIA: You might have to strip it from DRM using a hex editor of some sort before being able to use it.
4. Execute following commands:
  - `chmod -R 660 GPU.rom` and `chown username:username GPU.rom`
5. Copy the contents of addToVmXML.txt into the XML of the VM, near the end of the XML, right before `<memballoon>` tag. Remember to change the PCI ID in it beforehand.
6. Then remove Spice/QXL stuff from the VM

# Step 8: Create needed directories for hook scripts
```
/etc/libvirt/hooks/qemu.d
/etc/libvirt/hooks/qemu.d/win10
/etc/libvirt/hooks/qemu.d/win10/prepare
/etc/libvirt/hooks/qemu.d/win10/prepare/begin
/etc/libvirt/hooks/qemu.d/win10/release
/etc/libvirt/hooks/qemu.d/win10/release/end
```

# Step 9: Copy the hook scripts.
1. Copy start.sh into `/etc/libvirt/hooks/qemu.d/win10/prepare/begin`
2. Copy revert.sh into `/etc/libvirt/hooks/qemu.d/win10/release/end`
3. Copy kvm.conf into `/etc/libvirt/hooks` (Remember to change the variables to fit your GPU ID. Mine are 2f_00_0 and 2f_00_1)

# Step 10: Enjoy your Windows VM with the GPU being fully passed through.