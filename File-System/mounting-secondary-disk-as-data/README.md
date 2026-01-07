# Storage Operations Runbooks (Linux)

This repository contains practical, copy/paste-ready runbooks for common Linux storage operations: extending an LVM-backed root filesystem and mounting a secondary data disk. The documents are written as step-by-step procedures with command examples and sample outputs.

---

## Contents

### 1) `extend-root-lvm-add-disk-ubuntu24.04.md`
**Purpose:** Extend an existing **LVM root filesystem** (`/`) by adding a new disk (for example `/dev/sdb`) into the existing Volume Group and expanding the root Logical Volume.

**Use when:**
- You installed Ubuntu 24.04 with LVM (common default for server installs).
- Root filesystem is running out of space and you attached an additional disk.
- You want to expand `/` online with minimal downtime.

**Key operations covered:**
- Partition new disk for LVM (GPT + LVM flag)
- `pvcreate` → `vgextend` → `lvextend`
- Grow `ext4` online using `resize2fs`
- Post-change validation (`df`, `lvs`, `vgs`, `pvs`)
- Operational caveat: LVM spanning multiple disks has a single-disk-failure risk without redundancy

---

### 2) `mount-secondary-disk-Ubuntu.md`
**Purpose:** Partition, format, and permanently mount a **secondary data disk** (for example `/dev/sdb`) to `/data` on Ubuntu.

**Use when:**
- You want a dedicated data mount such as `/data` for application storage (e.g., logs, artifacts, backups).
- You prefer a stable mount via `/etc/fstab` (typically using UUID).

**Key operations covered:**
- Disk identification (`lsblk`)
- Partition creation (`fdisk` or `parted`, depending on the doc)
- Formatting (`mkfs.ext4`)
- Temporary mount + validation (`mount`, `df`)
- Persistent mount configuration (`/etc/fstab`)

---

### 3) `mount-secondary-disk-almalinux-rockylinux.md`
**Purpose:** Partition, format, and permanently mount a **secondary data disk** to `/data` on AlmaLinux / Rocky Linux (RHEL-family).

**Use when:**
- You are running AlmaLinux or Rocky Linux (or other RHEL-like distributions) and need a persistent data mount.
- You want to follow RHEL-family best practices, including awareness of SELinux behavior.

**Key operations covered:**
- Disk identification and signature check (`lsblk`, `wipefs -n`)
- Partition creation (`fdisk`)
- Formatting (`mkfs.ext4`)
- Persistent mount via UUID in `/etc/fstab` (`blkid`)
- Includes `nofail` guidance for cloud/VM environments
- SELinux note for service-specific contexts

---

## Quick guidance: which doc should I use?

- **Need to increase `/` size and you are using LVM root on Ubuntu 24.04?**  
  Use: `extend-root-lvm-add-disk-ubuntu24.04.md`

- **Need a separate `/data` mount on Ubuntu?**  
  Use: `mount-secondary-disk-Ubuntu.md`

- **Need a separate `/data` mount on AlmaLinux or Rocky Linux?**  
  Use: `mount-secondary-disk-almalinux-rockylinux.md`

---

## Safety notes

- These procedures can destroy data if the wrong disk is selected. Always double-check device names (`/dev/sdb`, `/dev/nvme1n1`, etc.) before running destructive commands.
- For production systems, strongly consider backups, snapshots, and change windows.
- Extending an LVM volume across multiple disks improves capacity but not resilience. If you need resilience, plan for RAID/LVM mirroring or platform-managed redundancy.

---

## Suggested verification commands (common)
Run these before and after changes:
```bash
lsblk
lsblk -f
df -hT
sudo pvs
sudo vgs
sudo lvs
```

---

## Contributing / Updating
- Keep procedures deterministic and safe.
- Include command examples and representative outputs.
- Prefer UUID-based mounts in `/etc/fstab` for stability.
