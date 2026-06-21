# 🚀 Create Virtual Machines with Vagrant + KVM/libvirt on Ubuntu

> **A clean, eye‑catchy, production‑ready guide** to running local VMs using **Vagrant** backed by **KVM/libvirt**.
> This document is based on real hands‑on steps executed on a local Ubuntu system, structured to avoid confusion and guesswork.

---

## 🧭 Architecture at a Glance

```
Vagrant CLI
   │
   ▼
vagrant-libvirt provider
   │
   ▼
libvirt (libvirtd)
   │
   ▼
KVM / QEMU  →  Virtual Machine (Ubuntu 24.04)
```

---

## 🎯 What You’ll Achieve

By the end of this guide, you will have:

- ✅ Hardware‑accelerated virtualization (KVM) enabled
- ✅ libvirt configured and accessible without root
- ✅ Vagrant installed from the official HashiCorp repo
- ✅ `vagrant-libvirt` provider working
- ✅ A reproducible **Ubuntu 24.04 VM**
- ✅ Private networking with a static IP

> ⚡ **In a hurry?** The two things that trip everyone up are (1) the `qemu-kvm` package name → see [Step 6](#6️⃣-install-kvm--libvirt-stack) (`#install-kvm--libvirt-stack`), and (2) the `libvirt-sock: Permission denied` error → see [Step 7](#7️⃣-fix-permissions-critical-step) (`#fix-permissions-critical-step`) and [Troubleshooting](#-troubleshooting). Read those two and you’re 90% there.

---

## 📚 Useful Resources (bookmark these)

- 🔗 Vagrant official site:
  https://www.vagrantup.com/

- 🔗 Vagrant box discovery (official):
  https://portal.cloud.hashicorp.com/vagrant/discover/

- 🔗 Bento Ubuntu boxes:
  https://portal.cloud.hashicorp.com/vagrant/discover/bento

- 🔗 libvirt docs:
  https://libvirt.org/

- 🔗 vagrant-libvirt plugin:
  https://github.com/vagrant-libvirt/vagrant-libvirt

---

## 🧱 Prerequisites

| Requirement | Notes |
|------------|------|
| OS | Ubuntu **24.04 LTS** (also works on 24.10 / 25.04 / 25.10 — see package note in Step 6) |
| Access | `sudo` privileges |
| CPU | Intel VT‑x or AMD‑V |
| BIOS | Virtualization **enabled** |

---

## 1️⃣ System Preparation (Clean Baseline)

Update the system to a known‑good state:

```bash
sudo apt update -y
```
---

## 2️⃣ Reboot Safety Check

```bash
test -f /var/run/reboot-required && echo "🚨 Reboot required" || echo "✅ No reboot required"
```

If required:
```bash
sudo reboot now
```

---

## 3️⃣ Verify User Context

```bash
whoami
```

### ✅ Example
```text
jakir
```

---

## 4️⃣ Install & Enable SSH (Recommended)

SSH makes VM and host access predictable and script‑friendly.

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

### ✅ Expected state
```text
Active: active (running)
```

---

## 5️⃣ Host Capability Checks (CPU + Virtualization)

```bash
timedatectl
lscpu
```

Check virtualization flags (count of CPU threads that expose `vmx` (Intel) or `svm` (AMD)):

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

### ✅ Example
```text
16
```

> Any number **greater than 0** means virtualization is supported. `0` means VT‑x/AMD‑V is disabled in BIOS/UEFI — enable it before continuing.

Confirm the OS sees virtualization:

```bash
lscpu | grep Virtualization
```

### ✅ Example
```text
Virtualization: VT-x
```

---

## 6️⃣ Install KVM + libvirt Stack

> ### ⚠️ Heads‑up: there is **no** `qemu-kvm` package on modern Ubuntu
>
> On Ubuntu 24.04 and newer, `qemu-kvm` is only a **virtual (transitional) package** — it has no real installation candidate, so this fails:
>
> ```text
> $ sudo apt install -y qemu-kvm
> Package qemu-kvm is a virtual package provided by:
>   qemu-system-x86-hwe ...
>   qemu-system-x86 ...
> You should explicitly select one to install.
> Error: Package 'qemu-kvm' has no installation candidate
> ```
>
> ✅ **The fix:** install the real package, **`qemu-system-x86`**, instead of `qemu-kvm`.

Install the full stack with the correct package name:

```bash
sudo apt install -y \
  qemu-system-x86 \
  libvirt-daemon-system \
  libvirt-clients \
  virt-manager \
  bridge-utils
```

> 💡 You may also see a `qemu-system-x86-hwe` package in the provider list (the user’s machine above lists **both**). That’s an **optional Hardware‑Enablement variant** that ships a *newer* QEMU and **coexists** with `qemu-system-x86` on the same release — it is **not** a replacement for a missing base package. Most users want the standard `qemu-system-x86`. Only choose the `-hwe` variant if you specifically need the newer virtualization stack:
> ```bash
> sudo apt install -y qemu-system-x86-hwe libvirt-daemon-system libvirt-clients virt-manager bridge-utils
> ```

Enable and start libvirt (the `--now` flag enables **and** starts in one shot):

```bash
sudo systemctl enable --now libvirtd
systemctl status libvirtd
```

### ✅ Expected
```text
Active: active (running)
```

> ℹ️ **Newer Ubuntu releases (24.10+):** libvirt is moving to *modular daemons* (`virtqemud`, `virtnetworkd`, …) where `libvirtd` is a socket‑activated compatibility shim. You don’t need to change anything — the permission fix in Step 7 is identical. If `systemctl status libvirtd` shows it as inactive but `virsh` still works after Step 7, that’s expected on those releases.

Reboot if prompted (`/var/run/reboot-required`).

---

## 7️⃣ Fix Permissions (Critical Step ⚠️)

Without this, Vagrant **will fail** with:

```text
Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
```

That error simply means **your user is not yet an effective member of the `libvirt` group** in the current login session.

### Step 7.1 — Add your user to the `libvirt` and `kvm` groups

```bash
sudo usermod -aG libvirt,kvm $USER
```

### Step 7.2 — ⚠️ Start a **new login session** (this is the part people miss)

Group changes from `usermod` **do not apply to sessions that are already open** — including your current terminal *and* every other terminal tab/window opened from the same desktop login. The reliable way to pick them up is a full **log out / log back in**, or simply:

```bash
sudo reboot
```

> 🧪 **Just want to test in this one terminal without rebooting?**
> ```bash
> newgrp libvirt
> ```
> ⚠️ `newgrp` only affects **the single shell you run it in** — it spawns a nested subshell. Do **not** chain `newgrp libvirt` then `newgrp kvm`; the second just nests again and the effect doesn’t carry over to Vagrant, your editor, or new tabs. Treat `newgrp` as a quick smoke‑test only. **Log out/in or reboot is the real fix.**

### Step 7.3 — Validate (after re‑login / reboot)

```bash
groups
ls -l /dev/kvm
ls -l /var/run/libvirt/libvirt-sock
virsh list --all
```

### ✅ What “good” looks like

`groups` includes both `libvirt` and `kvm`:
```text
jakir adm sudo libvirt kvm ...
```

`/dev/kvm` is group‑owned by `kvm`:
```text
crw-rw----+ 1 root kvm ... /dev/kvm
```

The libvirt socket is group‑owned by `libvirt` with group read/write:
```text
srwxrwx--- 1 root libvirt 0 ... /var/run/libvirt/libvirt-sock
```

And `virsh` connects **without `sudo`**:
```text
$ virsh list --all
 Id   Name   State
--------------------
```
(An empty list is success — it means you connected and there are simply no VMs yet.)

---

## 8️⃣ Install Vagrant (Official HashiCorp Repo)

```bash
sudo apt install -y curl gnupg software-properties-common
```

Add HashiCorp GPG key:
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

Add repo and install:
```bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y vagrant
```

Verify:
```bash
vagrant version
```

---

## 9️⃣ Install `vagrant-libvirt` Provider

```bash
sudo apt install -y libvirt-dev ruby-dev make gcc
vagrant plugin install vagrant-libvirt
vagrant plugin list
```

### ✅ Expected
```text
vagrant-libvirt (x.x.x, global)
```

---

## 🔟 Verify KVM Acceleration (Optional but Recommended)

```bash
sudo apt install -y cpu-checker
kvm-ok
```

### ✅ Expected
```text
INFO: /dev/kvm exists
KVM acceleration can be used
```

---

## 1️⃣1️⃣ Create Project & Initialize Box

```bash
mkdir -p ~/vagrant/ubuntu-24.04
cd ~/vagrant/ubuntu-24.04
vagrant init bento/ubuntu-24.04
```

---

## 1️⃣2️⃣ Recommended `Vagrantfile`

```ruby
Vagrant.configure("2") do |config|
  vm_ip = "192.168.169.100"

  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "ubuntu24-vagrant"
  config.vm.network "private_network", ip: vm_ip

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.memory = 2048
    libvirt.cpus = 2
    libvirt.nested = true
  end
end
```

---

## 1️⃣3️⃣ VM Lifecycle Commands

### ▶️ Start
```bash
vagrant up --provider=libvirt
```

### 📊 Status
```bash
vagrant status
```

### 🔐 SSH
```bash
vagrant ssh
```

### 🔄 Reload
```bash
vagrant reload
```

### 💥 Destroy
```bash
vagrant destroy -f
```

---

## 1️⃣4️⃣ Global Cleanup & Control

```bash
vagrant global-status
vagrant destroy <id>
rm -rf .vagrant
```

---

## 🛠 Troubleshooting

### ❌ `Package 'qemu-kvm' has no installation candidate`

```text
Package qemu-kvm is a virtual package provided by:
  qemu-system-x86-hwe ...
  qemu-system-x86 ...
Error: Package 'qemu-kvm' has no installation candidate
```

**Cause:** `qemu-kvm` is a transitional/virtual package on modern Ubuntu and can’t be installed directly.
**Fix:** install `qemu-system-x86` (the `qemu-system-x86-hwe` package you may see listed is an optional newer variant, **not** required):

```bash
sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients virt-manager bridge-utils
```

---

### ❌ `Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied`

Seen as either:
```text
error: failed to connect to the hypervisor
error: Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
```
or, from Vagrant:
```text
Error while connecting to Libvirt: Call to virConnectOpen failed:
Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
```

**Cause:** your shell/session isn’t an effective member of the `libvirt` group yet — almost always because the session was opened *before* `usermod`, or hasn’t been refreshed since.

**Fix (in order):**

1. Confirm membership exists on the account:
   ```bash
   groups $USER          # should list: libvirt kvm
   ```
   If they’re missing, add them:
   ```bash
   sudo usermod -aG libvirt,kvm $USER
   ```
2. **Apply it to a real session — log out/in or reboot** (most reliable):
   ```bash
   sudo reboot
   ```
   `newgrp libvirt` works only for one throwaway shell; it will *not* fix Vagrant or new terminals.
3. Make sure the daemon is actually running (a stopped daemon shows the same socket error):
   ```bash
   sudo systemctl enable --now libvirtd
   sudo systemctl status libvirtd          # expect: active (running)
   ```
4. Sanity‑check the socket ownership:
   ```bash
   ls -l /var/run/libvirt/libvirt-sock     # expect group 'libvirt', perms srwxrwx---
   ```
   If ownership looks wrong, restart the daemon:
   ```bash
   sudo systemctl restart libvirtd
   ```
5. Re‑test **without sudo**, then retry Vagrant:
   ```bash
   groups | grep -o libvirt      # libvirt should be present in the CURRENT shell now
   virsh list --all              # must succeed without sudo
   vagrant up --provider=libvirt
   ```

---

### ⚠️ `[fog][WARNING] Unrecognized arguments: libvirt_ip_command`

```text
[fog][WARNING] Unrecognized arguments: libvirt_ip_command
```

**This is harmless.** It’s a benign version‑mismatch warning between the `vagrant-libvirt` plugin and its `fog-libvirt` dependency. It does **not** block the connection or the VM. Ignore it — if `vagrant up` still fails, the real cause is the permission error above, not this warning.

---

### ❌ `KVM acceleration cannot be used` (from `kvm-ok`)

- Re‑check BIOS/UEFI: VT‑x (Intel) or AMD‑V (SVM) must be **enabled**.
- Confirm flags are visible to the OS:
  ```bash
  egrep -c '(vmx|svm)' /proc/cpuinfo   # must be > 0
  ```
- Ensure `/dev/kvm` exists and you’re in the `kvm` group (see Step 7).

---

## 🏁 Final Check

If this works:

```bash
vagrant status
vagrant ssh
```

