# RHEL 9.8 GUI, TigerVNC, Linux User & SFTP Configuration Guide

## 1. Overview, Architecture, and Placeholders

This guide documents the complete, sequential configuration of a Red Hat Enterprise Linux 9.8 (RHEL 9.8) server providing multi-user GNOME desktops via TigerVNC and group-based chrooted SFTP file transfer.

### 1.1 Implemented Architecture vs. Alternative Approaches Discussed

During our implementation sessions, two access architectures were discussed:
1. **Primary Implemented Architecture (Documented as the Main Procedure in Steps 1–20):**
   * **Direct TigerVNC Access:** TigerVNC listens on `0.0.0.0:5901` through `0.0.0.0:5904` (with `localhost` omitted from `/etc/tigervnc/vncserver-config-mandatory`). Users connect directly from TigerVNC Viewer to `<SERVER_IP>:5901`–`5904` without launching an SSH tunnel.
   * **Synchronized 8-Character Passwords:** Because TigerVNC's `vncauth` truncates passwords at 8 characters, PAM `pwquality` is configured to allow 8-character Linux passwords (`minlen = 8`), and each user's Linux password and VNC password are set to the same 8-character value.
   * **Explicit Two-Group SFTP Control (`sftp-allowed` and `sftp-denied`):** Users in `sftp-allowed` (`GID 1001`) are chrooted to `/srv/sftp/%u` with a writable `files/` subdirectory using `ForceCommand internal-sftp`. Users in `sftp-denied` (`GID 1002`) are blocked from SFTP/SSH while retaining full access to their direct TigerVNC desktop sessions.
2. **Alternative / Optional Architectures Discussed (Documented in Step 17 and Section 8):**
   * **Granular SFTP Denial Without Blocking SSH Shell/Tunnels (Step 17A):** Denying SFTP for specific users/groups while keeping interactive SSH shell or port forwarding active.
   * **SSH Loopback Tunnel-Only VNC (Step 17B):** Binding TigerVNC strictly to `127.0.0.1` via `localhost` in `/etc/tigervnc/vncserver-config-mandatory` and requiring `ssh -N -L 590N:127.0.0.1:590N`.
   * **Cross-Server Calculator Connector (Step 21):** Privilege-isolated `sudoers` rule (`/etc/sudoers.d/calc-connector`) and wrapper script (`/opt/calc-connector/run_calc.sh`) to run a remote Python/Tkinter app on a secondary server (`<SERVER2_IP>`).

### 1.2 Standard Placeholders Used in This Guide

Replace these placeholders with your environment's values when executing commands:

| Placeholder | Description | Example / Implemented Pattern |
| :--- | :--- | :--- |
| `<SERVER_IP>` | Private or public IPv4 address of the RHEL 9.8 VNC/SFTP server | `10.0.1.213` |
| `<SERVER_HOSTNAME>` | Hostname of the RHEL 9.8 server | `vnc-rhel9-srv01` |
| `<SERVER2_IP>` | IPv4 address of the optional secondary backend server | `10.0.1.185` |
| `<ADMIN_USER>` | Primary administrative SSH user with `wheel`/`sudo` access | `ec2-user` |
| `<USER_1>` | VNC User 1 (Display `:1`, Port `5901`, `sftp-allowed`) | `vncuser1` |
| `<USER_2>` | VNC User 2 (Display `:2`, Port `5902`, `sftp-allowed`) | `vncuser2` |
| `<USER_3>` | VNC User 3 (Display `:3`, Port `5903`, `sftp-denied`) | `vncuser3` |
| `<USER_4>` | VNC User 4 (Display `:4`, Port `5904`, `sftp-denied`) | `vncuser4` |
| `<NEW_USER>` | Placeholder for onboarding/modifying an additional employee | `vncuser5` |
| `<USER_PASSWORD_8CHAR>` | Interactive 8-character password (must not contain username) | Entered interactively (never hardcoded) |

### 1.3 Implemented Display, Port, and Group Mapping Matrix

| Linux User | VNC Display | VNC TCP Port | Linux Group (`GID`) | Direct VNC Access | SFTP Access | Chroot Writable Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `<USER_1>` | `:1` | `5901` | `sftp-allowed` (`1001`) | `<SERVER_IP>:5901` | **Allowed** | `/srv/sftp/<USER_1>/files` |
| `<USER_2>` | `:2` | `5902` | `sftp-allowed` (`1001`) | `<SERVER_IP>:5902` | **Allowed** | `/srv/sftp/<USER_2>/files` |
| `<USER_3>` | `:3` | `5903` | `sftp-denied` (`1002`) | `<SERVER_IP>:5903` | **Denied** | None |
| `<USER_4>` | `:4` | `5904` | `sftp-denied` (`1002`) | `<SERVER_IP>:5904` | **Denied** | None |

---

## 2. Complete RHEL 9.8 Server Preparation

### Step 1: Verify RHEL 9.8 OS Release, Kernel, and Repositories
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/os-release`

**Commands:**
```bash
cat /etc/os-release
uname -r
subscription-manager status || true
dnf repolist
```

**Configuration:**
```ini
# Expected values present inside /etc/os-release:
PLATFORM_ID="platform:el9"
VERSION_ID="9.8"
```

**Validation:**
```bash
grep -E '^(NAME|VERSION_ID|PLATFORM_ID)=' /etc/os-release
dnf repolist --enabled
```

**Expected result:**
Confirms the host is running Red Hat Enterprise Linux `9.8` (`platform:el9`) and has active `BaseOS` and `AppStream` repositories enabled. (Do not use RHEL 10 on the VNC server, as `tigervnc-server` and `gnome-terminal` are removed in RHEL 10).

---

### Step 2: Configure Hostname and Verify Network Identity
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/hostname`

**Commands:**
```bash
hostnamectl set-hostname <SERVER_HOSTNAME>
hostname -I
ip -br addr show
```

**Configuration:**
```text
<SERVER_HOSTNAME>
```

**Validation:**
```bash
hostnamectl status
hostname -I
```

**Expected result:**
`hostnamectl status` displays `Static hostname: <SERVER_HOSTNAME>`, and `hostname -I` outputs the exact IP address (`<SERVER_IP>`) that clients will use to connect via TigerVNC Viewer and SFTP. Record this exact IP so client connections do not target the wrong instance.

---

### Step 3: Update System Packages and Install Base Administration Dependencies
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`None (System Package Management)`

**Commands:**
```bash
dnf clean all
dnf makecache
dnf upgrade -y
dnf install -y openssh-server openssh-clients policycoreutils-python-utils setroubleshoot-server firewalld
```

**Configuration:**
```text
# Installed base packages:
# - openssh-server / openssh-clients: SSH daemon, sftp subsystem, ssh/scp tools
# - policycoreutils-python-utils: provides 'semanage' for SELinux fcontext rules
# - setroubleshoot-server / audit: provides 'ausearch' for SELinux diagnostics
# - firewalld: host firewall daemon
```

**Validation:**
```bash
rpm -q openssh-server openssh-clients policycoreutils-python-utils firewalld
```

**Expected result:**
All four core packages return their installed `.el9` version strings with zero missing package errors.

---

### Step 4: Verify Firewalld and SELinux Status
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/selinux/config`

**Commands:**
```bash
systemctl enable --now firewalld
systemctl is-active firewalld
getenforce
sestatus
```

**Configuration:**
```ini
# /etc/selinux/config
SELINUX=enforcing
SELINUXTYPE=targeted
```

**Validation:**
```bash
systemctl is-active firewalld && getenforce
```

**Expected result:**
Outputs `active` for `firewalld` and `Enforcing` for SELinux. Never disable `firewalld` or set SELinux to `Permissive`/`Disabled`.

---

## 3. GUI / Desktop Environment Installation

### Step 5: Install GNOME Desktop Environment (`Server with GUI`) and X11 Dependencies
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`None (DNF Group Installation)`

**Commands:**
```bash
dnf group install -y "Server with GUI"
dnf install -y gnome-terminal xorg-x11-xauth dejavu-sans-fonts
```

**Configuration:**
```text
# Key components installed by "Server with GUI" and explicit packages:
# - gnome-shell / gnome-session: GNOME desktop environment
# - gdm: GNOME Display Manager
# - gnome-terminal: Terminal emulator inside VNC desktop
# - xorg-x11-xauth: X11 authentication cookie manager (.Xauthority)
```

**Validation:**
```bash
rpm -q gnome-shell gnome-session gdm gnome-terminal xorg-x11-xauth
```

**Expected result:**
Outputs the installed `.el9_8` package versions for `gnome-shell`, `gnome-session`, `gdm`, `gnome-terminal`, and `xorg-x11-xauth`.

---

### Step 6: Configure Display Manager and Switch to `graphical.target`
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/systemd/system/default.target`

**Commands:**
```bash
systemctl enable gdm.service
systemctl set-default graphical.target
systemctl isolate graphical.target
```

**Configuration:**
```text
# Symlink created by systemd:
/etc/systemd/system/default.target -> /usr/lib/systemd/system/graphical.target
```

**Validation:**
```bash
systemctl get-default
systemctl is-active gdm.service
```

**Expected result:**
`systemctl get-default` outputs `graphical.target` and `gdm.service` reports `active`.

*(Reference: To switch back to headless console mode temporarily, run `systemctl isolate multi-user.target`; to change the permanent boot default to console mode, run `systemctl set-default multi-user.target`.)*

---

## 4. Linux User and Group Management

### 4.1 User Role and Permission Architecture

| Account Category | Primary Purpose | UID/GID Range | Group Memberships | Shell / SSH Access | VNC Desktop | SFTP Access |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Linux System Users** | Run OS daemons (`sshd`, `gdm`, `dbus`) | UID `< 1000` | System groups | `/sbin/nologin` | No | No |
| **Administrative Users** | Full server administration (`<ADMIN_USER>`) | UID `>= 1000` | `wheel` | `/bin/bash` (SSH key) | Optional | Full (`scp`/`sftp`) |
| **Normal Linux Users** | Standard interactive local/SSH users | UID `>= 1000` | User private group | `/bin/bash` | No (unless mapped) | Default |
| **VNC + SFTP Allowed Users** | Remote GUI desktop + file upload/download (`<USER_1>`, `<USER_2>`) | UID `>= 1000` | `sftp-allowed` (`1001`) | `/bin/bash` (local VNC terminal); SSH forced to `internal-sftp` | Yes (`:1`, `:2`) | **Yes** (Chrooted to `/srv/sftp/%u`) |
| **VNC + SFTP Denied Users** | Remote GUI desktop only; no file transfer (`<USER_3>`, `<USER_4>`) | UID `>= 1000` | `sftp-denied` (`1002`) | `/bin/bash` (local VNC terminal); SSH/SFTP blocked via `DenyGroups` | Yes (`:3`, `:4`) | **No** (Blocked at `sshd`) |

---

### Step 7: Configure PAM `pwquality` to Allow 8-Character Passwords
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/security/pwquality.conf`

**Commands:**
```bash
sed -i 's/^#\?\s*minlen\s*=.*/minlen = 8/' /etc/security/pwquality.conf
grep -q '^minlen' /etc/security/pwquality.conf || echo "minlen = 8" >> /etc/security/pwquality.conf
```

**Configuration:**
```ini
# Active rule in /etc/security/pwquality.conf:
minlen = 8
```

**Validation:**
```bash
grep -E '^(minlen|usercheck|dictcheck)' /etc/security/pwquality.conf || grep '^minlen' /etc/security/pwquality.conf
```

**Expected result:**
Displays `minlen = 8`. Note that `usercheck = 1` and `dictcheck = 1` remain active by default, meaning passwords should not contain the username (e.g., avoid `<USER_1>123` to prevent `BAD PASSWORD: The password contains the user name in some form`).

---

### Step 8: Create SFTP Access Groups (`sftp-allowed` and `sftp-denied`)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/group`

**Commands:**
```bash
getent group sftp-allowed || groupadd -g 1001 sftp-allowed
getent group sftp-denied || groupadd -g 1002 sftp-denied
```

**Configuration:**
```text
# Entries created in /etc/group:
sftp-allowed:x:1001:
sftp-denied:x:1002:
```

**Validation:**
```bash
getent group sftp-allowed sftp-denied
```

**Expected result:**
Outputs `sftp-allowed:x:1001:` and `sftp-denied:x:1002:`. (If GID `1001` or `1002` is already occupied by a pre-existing user group on a server, reassign the existing group's GID with `groupmod -g <NEW_GID> <EXISTING_GROUP>` first).

---

### Step 9: Create Linux Users, Assign Groups, Lock Down Home Directories, and Set Passwords
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/passwd`, `/etc/shadow`, `/etc/group`

**Commands:**
```bash
# Create SFTP-allowed VNC users (<USER_1> and <USER_2>)
useradd -m -s /bin/bash -G sftp-allowed <USER_1>
useradd -m -s /bin/bash -G sftp-allowed <USER_2>

# Create SFTP-denied VNC users (<USER_3> and <USER_4>)
useradd -m -s /bin/bash -G sftp-denied <USER_3>
useradd -m -s /bin/bash -G sftp-denied <USER_4>

# Enforce strict 0700 permissions on all user home directories
chmod 700 /home/<USER_1> /home/<USER_2> /home/<USER_3> /home/<USER_4>

# Set an interactive 8-character Linux password for each user
passwd <USER_1>
passwd <USER_2>
passwd <USER_3>
passwd <USER_4>
```

**Configuration:**
```text
# Group memberships in /etc/group:
sftp-allowed:x:1001:<USER_1>,<USER_2>
sftp-denied:x:1002:<USER_3>,<USER_4>
```

**Validation:**
```bash
id <USER_1>
id <USER_2>
id <USER_3>
id <USER_4>
getent group sftp-allowed sftp-denied
ls -ld /home/<USER_1> /home/<USER_2> /home/<USER_3> /home/<USER_4>
passwd -S <USER_1> <USER_2> <USER_3> <USER_4>
```

**Expected result:**
* `<USER_1>` and `<USER_2>` belong to `1001(sftp-allowed)` and **not** `wheel` or `sftp-denied`.
* `<USER_3>` and `<USER_4>` belong to `1002(sftp-denied)` and **not** `wheel` or `sftp-allowed`.
* All four `/home/<USER_N>` directories show `drwx------.` (`0700`) owned by `<USER_N>:<USER_N>`.
* `passwd -S` shows `PS` (password set) for all four accounts.

### 4.2 General Linux User & Group Administration Reference Commands

Execute these commands as `root` when inspecting or modifying users and groups:
* **Check User ID (UID) and Group IDs (GIDs):** `id <USERNAME>`
* **List all local users:** `cut -d: -f1,3,4,6,7 /etc/passwd`
* **List all local groups:** `getent group`
* **Add an existing user to a supplementary group (append):** `usermod -aG <GROUP_NAME> <USERNAME>`
* **Replace a user's supplementary groups completely:** `usermod -G <GROUP_NAME> <USERNAME>`
* **Remove a user from a specific group:** `gpasswd -d <USERNAME> <GROUP_NAME>`
* **Change a user's login shell:** `usermod -s /bin/bash <USERNAME>` (or `/sbin/nologin`)
* **Change directory ownership and permissions:** `chown -R <USERNAME>:<GROUP_NAME> /path/to/dir && chmod 700 /path/to/dir`
* **Temporarily lock/disable a Linux user:** `usermod -L <USERNAME> && chage -E 0 <USERNAME>`
* **Unlock/re-enable a Linux user:** `usermod -U <USERNAME> && chage -E -1 <USERNAME>`
* **Delete a Linux user (preserving files):** `userdel <USERNAME>`
* **Delete a Linux user and home directory:** `userdel -r <USERNAME>`

---

## 5. TigerVNC Installation, Configuration, and VNC User Management

### 5.1 How Multi-User TigerVNC Works on RHEL 9.8
* **Independent Sessions:** TigerVNC uses the systemd template unit `/usr/lib/systemd/system/vncserver@.service`. Each display number (`:1`, `:2`, `:3`, `:4`) launches an isolated `Xvnc` server and `gnome-session` owned by the mapped Linux user in `/etc/tigervnc/vncserver.users`.
* **Display-to-Port Mapping:** Display `:N` listens on TCP port `5900 + N`:
  * `:1` = TCP `5901` (`<USER_1>`)
  * `:2` = TCP `5902` (`<USER_2>`)
  * `:3` = TCP `5903` (`<USER_3>`)
  * `:4` = TCP `5904` (`<USER_4>`)
* **Linux Password vs. VNC Password:**
  * The **Linux password** is stored in `/etc/shadow` and authenticates PAM services (SSH/SFTP logins and GNOME Polkit/screen unlock prompts).
  * The **VNC password** is stored in `/home/<USER>/.config/tigervnc/passwd` (mode `0600`) and authenticates the initial TigerVNC Viewer connection (`vncauth`). Because `vncauth` only evaluates the first 8 characters, setting both passwords to the exact same 8-character string provides a single password experience for end users.

---

### Step 10: Install TigerVNC Server and Configure Session Defaults & Mandatory Policy
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/tigervnc/vncserver-config-defaults`, `/etc/tigervnc/vncserver-config-mandatory`

**Commands:**
```bash
dnf install -y tigervnc-server

cat << 'EOF' > /etc/tigervnc/vncserver-config-defaults
session=gnome
geometry=1920x1080
securitytypes=vncauth,tlsvnc
EOF

cat << 'EOF' > /etc/tigervnc/vncserver-config-mandatory
SendCutText=0
AcceptCutText=0
EOF

chmod 644 /etc/tigervnc/vncserver-config-defaults /etc/tigervnc/vncserver-config-mandatory
```

**Configuration:**
```ini
# /etc/tigervnc/vncserver-config-defaults
session=gnome
geometry=1920x1080
securitytypes=vncauth,tlsvnc

# /etc/tigervnc/vncserver-config-mandatory
SendCutText=0
AcceptCutText=0
```

**Validation:**
```bash
rpm -q tigervnc-server
cat /etc/tigervnc/vncserver-config-defaults
cat /etc/tigervnc/vncserver-config-mandatory
```

**Expected result:**
`tigervnc-server` is installed, default session is set to `gnome` (`1920x1080`, `vncauth,tlsvnc`), clipboard copy/paste is disabled via `SendCutText=0` and `AcceptCutText=0`, and `localhost` is omitted so `Xvnc` listens on `0.0.0.0` for direct VNC connections.

---

### Step 11: Configure VNC User-to-Display Mapping
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/tigervnc/vncserver.users`

**Commands:**
```bash
cat << 'EOF' > /etc/tigervnc/vncserver.users
:1=<USER_1>
:2=<USER_2>
:3=<USER_3>
:4=<USER_4>
EOF

# Strip any accidental trailing spaces at the end of lines
sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users
chmod 644 /etc/tigervnc/vncserver.users
```

**Configuration:**
```ini
:1=<USER_1>
:2=<USER_2>
:3=<USER_3>
:4=<USER_4>
```

**Validation:**
```bash
cat -A /etc/tigervnc/vncserver.users
```

**Expected result:**
Prints `:1=<USER_1>$`, `:2=<USER_2>$`, `:3=<USER_3>$`, `:4=<USER_4>$` with `$` immediately following each username (confirming no trailing spaces exist).

---

### Step 12: Configure VNC Passwords for Each User (`vncpasswd`)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root` (switching to each `<USER_N>` via `su -`)
**Configuration file:**
`/home/<USER_N>/.config/tigervnc/passwd`

**Commands:**
```bash
# Run vncpasswd interactively as each user.
# Enter the exact same 8-character password set in Step 9.
# Answer 'n' to "Would you like to enter a view-only password (y/n)?"
su - <USER_1> -c "vncpasswd"
su - <USER_2> -c "vncpasswd"
su - <USER_3> -c "vncpasswd"
su - <USER_4> -c "vncpasswd"
```

**Configuration:**
```text
# Interactive prompt sequence for each user:
Password: <USER_PASSWORD_8CHAR>
Verify: <USER_PASSWORD_8CHAR>
Would you like to enter a view-only password (y/n)? n
A view-only password is not used
```

**Validation:**
```bash
ls -l /home/<USER_1>/.config/tigervnc/passwd \
      /home/<USER_2>/.config/tigervnc/passwd \
      /home/<USER_3>/.config/tigervnc/passwd \
      /home/<USER_4>/.config/tigervnc/passwd
```

**Expected result:**
All four `/home/<USER_N>/.config/tigervnc/passwd` files exist, are owned by `<USER_N>:<USER_N>`, and have `-rw-------` (`0600`) permissions. *(Note: Never run `su - <USER_1> -c "<PASSWORD>"`, as `-c` expects the executable command `vncpasswd`.)*

---

### Step 13: Enable and Start Systemd TigerVNC Services (`:1` through `:4`)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/usr/lib/systemd/system/vncserver@.service`

**Commands:**
```bash
systemctl daemon-reload
systemctl enable --now vncserver@:1.service vncserver@:2.service vncserver@:3.service vncserver@:4.service
```

**Configuration:**
```ini
# Reference structure of /usr/lib/systemd/system/vncserver@.service provided by tigervnc-server:
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/usr/libexec/vncsession-start %i
PIDFile=/run/vncsession-%i.pid
SELinuxContext=system_u:system_r:unconfined_service_t:s0

[Install]
WantedBy=multi-user.target
```

**Validation:**
```bash
systemctl is-active vncserver@:1.service vncserver@:2.service vncserver@:3.service vncserver@:4.service
ss -lntp | grep 590
ps -u <USER_1> -u <USER_2> -u <USER_3> -u <USER_4> | grep -E 'Xvnc|gnome-session|gnome-shell'
```

**Expected result:**
* `systemctl is-active` returns `active` for all four services.
* `ss -lntp | grep 590` shows `Xvnc` listening on `0.0.0.0:5901`, `0.0.0.0:5902`, `0.0.0.0:5903`, and `0.0.0.0:5904` (as well as `[::]:5901`–`5904`).
* `ps` confirms each user has independent `Xvnc`, `gnome-session`, and `gnome-shell` processes running.

---

## 6. SFTP Access Management and SSH Configuration

### 6.1 Relationship Between SFTP Restrictions, SSH Shell Access, and VNC Access

| Access Type | Service / Daemon | Port | How It Is Controlled | Impact of Denying SFTP |
| :--- | :--- | :--- | :--- | :--- |
| **Direct TigerVNC Desktop** | `vncserver@:N.service` (`Xvnc`) | TCP `5901–5904` | `/etc/tigervnc/vncserver.users` + `~/.config/tigervnc/passwd` | **Zero impact.** Direct VNC does not use `sshd`. Users in `sftp-denied` log directly into GNOME over ports `5901–5904` and can open `gnome-terminal` locally inside their desktop. |
| **SFTP File Transfer** | `sshd` (`internal-sftp`) | TCP `22` | `/etc/ssh/sshd_config.d/40-sftp-access.conf` (`Match Group sftp-allowed` / `sftp-denied`) | Controlled per group (`sftp-allowed` vs `sftp-denied`). |
| **SSH Interactive Shell** | `sshd` (`/bin/bash`) | TCP `22` | `ForceCommand` / `DenyGroups` / `PermitTTY` in `sshd_config` | Can be disabled for SFTP-only users (`ForceCommand internal-sftp`) or kept open for normal SSH users while blocking SFTP (see Step 17A). |

---

### Step 14: Create SFTP Chroot Directory Hierarchy and Permissions (`sftp-allowed`)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/srv/sftp/<USER_N>/files`

**Commands:**
```bash
# Create chroot directories for sftp-allowed users (<USER_1> and <USER_2>)
mkdir -p /srv/sftp/<USER_1>/files /srv/sftp/<USER_2>/files

# CRITICAL: OpenSSH ChrootDirectory requires root:root ownership and 0755 (no group/other write)
# on every directory component leading up to and including the chroot root (/srv/sftp/<USER_N>)
chown root:root /srv /srv/sftp /srv/sftp/<USER_1> /srv/sftp/<USER_2>
chmod 755 /srv /srv/sftp /srv/sftp/<USER_1> /srv/sftp/<USER_2>

# Assign user ownership and 0700 permissions to the inner writable 'files' directory
chown <USER_1>:sftp-allowed /srv/sftp/<USER_1>/files
chown <USER_2>:sftp-allowed /srv/sftp/<USER_2>/files
chmod 700 /srv/sftp/<USER_1>/files /srv/sftp/<USER_2>/files
```

**Configuration:**
```text
# Directory ownership and permission hierarchy:
/srv                        -> root:root             0755 (drwxr-xr-x)
/srv/sftp                   -> root:root             0755 (drwxr-xr-x)
/srv/sftp/<USER_1>          -> root:root             0755 (drwxr-xr-x) [Chroot Root]
/srv/sftp/<USER_1>/files    -> <USER_1>:sftp-allowed 0700 (drwx------) [User Upload/Download Dir]
/srv/sftp/<USER_2>          -> root:root             0755 (drwxr-xr-x) [Chroot Root]
/srv/sftp/<USER_2>/files    -> <USER_2>:sftp-allowed 0700 (drwx------) [User Upload/Download Dir]
```

**Validation:**
```bash
ls -ld /srv /srv/sftp /srv/sftp/<USER_1> /srv/sftp/<USER_1>/files /srv/sftp/<USER_2> /srv/sftp/<USER_2>/files
```

**Expected result:**
`/srv`, `/srv/sftp`, `/srv/sftp/<USER_1>`, and `/srv/sftp/<USER_2>` show `drwxr-xr-x. root root`, while `/srv/sftp/<USER_1>/files` and `/srv/sftp/<USER_2>/files` show `drwx------.` owned by `<USER_1>:sftp-allowed` and `<USER_2>:sftp-allowed`.

---

### Step 15: Enable SSH Password Authentication Across Base and Cloud-Init Configs
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/*.conf`

**Commands:**
```bash
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
for f in /etc/ssh/sshd_config.d/*.conf; do
    [ -e "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
done
```

**Configuration:**
```sshconfig
# Ensures no earlier drop-in (such as 50-cloud-init.conf or 50-redhat.conf)
# overrides PasswordAuthentication with 'no' before Match blocks are evaluated.
PasswordAuthentication yes
```

**Validation:**
```bash
grep -rn "PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/
```

**Expected result:**
No active (uncommented) `PasswordAuthentication no` lines remain in `/etc/ssh/sshd_config` or `/etc/ssh/sshd_config.d/*.conf`.

---

### Step 16: Configure Group-Based SFTP Access Control (`sftp-allowed` vs `sftp-denied`)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/ssh/sshd_config.d/40-sftp-access.conf`

**Commands:**
```bash
cat << 'EOF' > /etc/ssh/sshd_config.d/40-sftp-access.conf
# Enable password-based authentication
PasswordAuthentication yes
KbdInteractiveAuthentication yes

# Block sftp-denied (GID 1002) from all SSH/SFTP logins while preserving direct VNC
DenyGroups sftp-denied

# Allow sftp-allowed (GID 1001) to use chrooted SFTP only (no interactive SSH shell)
Match Group sftp-allowed
    PasswordAuthentication yes
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no

# Explicit fallback block for sftp-denied (GID 1002)
Match Group sftp-denied
    PasswordAuthentication no
    ForceCommand /usr/sbin/nologin
EOF

chmod 600 /etc/ssh/sshd_config.d/40-sftp-access.conf
sshd -t && systemctl reload sshd
```

**Configuration:**
```sshconfig
# /etc/ssh/sshd_config.d/40-sftp-access.conf
PasswordAuthentication yes
KbdInteractiveAuthentication yes
DenyGroups sftp-denied

Match Group sftp-allowed
    PasswordAuthentication yes
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no

Match Group sftp-denied
    PasswordAuthentication no
    ForceCommand /usr/sbin/nologin
```

**Validation:**
```bash
sshd -t
sshd -T -C user=<USER_1>,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand|denygroups)'
sshd -T -C user=<USER_3>,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand|denygroups)'
```

**Expected result:**
* `sshd -t` exits `0` with no syntax warnings.
* For `<USER_1>` (`sftp-allowed`): `passwordauthentication yes`, `forcecommand internal-sftp`, `chrootdirectory /srv/sftp/%u`.
* For `<USER_3>` (`sftp-denied`): `denygroups sftp-denied`, `passwordauthentication no`, `forcecommand /usr/sbin/nologin`.

---

### Step 17: Alternative SSH/SFTP Scenarios (Preserving SSH Shell or Tunneling While Denying SFTP)
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/ssh/sshd_config.d/40-sftp-access.conf` (Reference patterns when SSH access is required alongside SFTP denial)

**Commands:**
```bash
# DO NOT overwrite Step 16 unless you want sftp-denied users to also have SSH shell or tunnel access.
# Validate current effective subsystem setting:
sshd -T | grep -i '^subsystem'
```

**Configuration:**
```sshconfig
# ---------------------------------------------------------------------------
# SCENARIO 17A: Deny SFTP for 'sftp-denied' Users While Preserving Normal SSH Shell Access
# ---------------------------------------------------------------------------
# If a user in 'sftp-denied' needs interactive SSH shell access (/bin/bash) AND VNC,
# but must be blocked from running SFTP:
# 1. Remove 'DenyGroups sftp-denied'
# 2. Force their SSH session to launch interactive bash only (rejecting '-s sftp' subsystem requests):
Match Group sftp-denied
    PasswordAuthentication yes
    PermitTTY yes
    ForceCommand /bin/bash --login

# ---------------------------------------------------------------------------
# SCENARIO 17B: Deny SFTP for 'sftp-denied' While Allowing SSH Local Port Forwarding (-N -L) Only
# ---------------------------------------------------------------------------
# Used when VNC listens on 127.0.0.1 and users tunnel over SSH:
Match Group sftp-allowed
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp

Match Group vncusers
    PasswordAuthentication yes
    AllowTcpForwarding local
    X11Forwarding no
    AllowAgentForwarding no
    PermitTTY no
    ForceCommand /usr/sbin/nologin

Match User <USER_1>
    PermitOpen 127.0.0.1:5901
```

**Validation:**
```bash
sshd -t
```

**Expected result:**
Demonstrates how OpenSSH `Match` blocks separate SFTP access (`ForceCommand internal-sftp`) from interactive SSH shell access (`ForceCommand /bin/bash --login`) and tunnel-only access (`ForceCommand /usr/sbin/nologin` + `AllowTcpForwarding local`).

---

## 7. Firewall, AWS Security Group, and SELinux Configuration

### Step 18: Configure `firewalld` and AWS Security Group Rules for VNC and SSH/SFTP
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/firewalld/zones/public.xml`

**Commands:**
```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=5901-5904/tcp
firewall-cmd --reload
```

**Configuration:**
```text
# Required Inbound Rules in both firewalld AND AWS EC2 Security Group:
# - TCP 22        (SSH / SFTP)       -> Source: Authorized Client Subnet / IPs
# - TCP 5901-5904 (Direct TigerVNC)  -> Source: Authorized Client Subnet / IPs
```

**Validation:**
```bash
firewall-cmd --list-services
firewall-cmd --list-ports
ss -lntp | grep -E ':22|:590[1-4]'
```

**Expected result:**
`firewall-cmd --list-services` includes `ssh`, `firewall-cmd --list-ports` prints `5901-5904/tcp`, and `ss -lntp` confirms `sshd` (`:22`) and `Xvnc` (`:5901`–`:5904`) are listening on `0.0.0.0`. *(Note: On AWS EC2, you must also add Inbound TCP `5901-5904` to the instance's AWS Security Group; otherwise Windows TigerVNC Viewer will fail with socket timeout error `10060`.)*

---

### Step 19: Configure SELinux Contexts and Booleans for Chrooted SFTP Read/Write
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/selinux/targeted/contexts/files/file_contexts.local`

**Commands:**
```bash
semanage fcontext -a -t user_home_t "/srv/sftp/[^/]+/files(/.*)?"
restorecon -Rv /srv/sftp
setsebool -P ssh_chroot_rw_homedirs on
```

**Configuration:**
```text
# SELinux fcontext rule:
/srv/sftp/[^/]+/files(/.*)?    all files    system_u:object_r:user_home_t:s0
# SELinux persistent boolean:
ssh_chroot_rw_homedirs --> on
```

**Validation:**
```bash
getenforce
getsebool ssh_chroot_rw_homedirs
ls -Zd /srv/sftp/<USER_1>/files /srv/sftp/<USER_2>/files
```

**Expected result:**
* `getenforce` outputs `Enforcing`.
* `getsebool ssh_chroot_rw_homedirs` outputs `ssh_chroot_rw_homedirs --> on`.
* `ls -Zd` confirms `/srv/sftp/<USER_1>/files` and `/srv/sftp/<USER_2>/files` have been relabeled from `var_t` to `unconfined_u:object_r:user_home_t:s0`.

---

### Step 20: Verify End-to-End SFTP Upload/Download and VNC Desktop Connections
**Server:** Windows Client Workstation (`PowerShell` / `Command Prompt` / `TigerVNC Viewer`)
**Execution user:** `<USER_1>` (Allowed) and `<USER_3>` (Denied)
**Configuration file:**
`None (Client Verification)`

**Commands:**
```powershell
# 1. Verify TCP reachability to SSH (22) and VNC (5901-5904) from Windows PowerShell
Test-NetConnection -ComputerName <SERVER_IP> -Port 22
Test-NetConnection -ComputerName <SERVER_IP> -Port 5901

# 2. Test SFTP as an ALLOWED user (<USER_1> in sftp-allowed)
echo "sftp-test-payload" > test_upload.txt
sftp <USER_1>@<SERVER_IP>
# Inside sftp> prompt:
# cd files
# put test_upload.txt
# ls -la
# get test_upload.txt test_download.txt
# bye

# 3. Test SFTP as a DENIED user (<USER_3> in sftp-denied)
sftp <USER_3>@<SERVER_IP>
```

**Configuration:**
```text
# TigerVNC Viewer Connection Targets (Direct Connection):
# - <USER_1>: <SERVER_IP>:5901
# - <USER_2>: <SERVER_IP>:5902
# - <USER_3>: <SERVER_IP>:5903
# - <USER_4>: <SERVER_IP>:5904
```

**Validation:**
```bash
# Run on RHEL 9.8 Server as root to verify uploaded file and active VNC connections:
ls -la /srv/sftp/<USER_1>/files/
ss -ntp | grep -E ':22|:590[1-4]'
```

**Expected result:**
* `Test-NetConnection` returns `TcpTestSucceeded : True` for both port `22` and port `5901`.
* `sftp <USER_1>@<SERVER_IP>` logs in, and `put`/`get` inside `files/` succeed.
* `sftp <USER_3>@<SERVER_IP>` is rejected with `Permission denied`.
* All four users (`<USER_1>` through `<USER_4>`) can connect to `<SERVER_IP>:5901`–`5904` in TigerVNC Viewer using their 8-character password.

---

## 8. Cross-Server Calculator Connector & Sudoers Configuration (Optional Module)

If your deployment includes the privilege-isolated cross-server calculator connector from our initial architecture (`Server 1` connecting to `Server 2` at `<SERVER2_IP>`), execute Step 21 on the RHEL 9.8 server.

### Step 21: Configure `/opt/calc-connector` and `/etc/sudoers.d/calc-connector`
**Server:** RHEL 9.8 (`<SERVER_HOSTNAME>`)
**Execution user:** `root`
**Configuration file:**
`/etc/sudoers.d/calc-connector`, `/opt/calc-connector/.env`, `/opt/calc-connector/run_calc.sh`

**Commands:**
```bash
# 1. Create functional groups and add the four VNC users
getent group vncusers || groupadd vncusers
getent group calcreaders || groupadd calcreaders
for u in <USER_1> <USER_2> <USER_3> <USER_4>; do
    usermod -aG vncusers,calcreaders "$u"
done

# 2. Create connector directories and set permissions
mkdir -p /opt/calc-connector/results
chown root:root /opt/calc-connector
chmod 755 /opt/calc-connector
chown root:calcreaders /opt/calc-connector/results
chmod 750 /opt/calc-connector/results

# 3. Install PEM key (assuming uploaded to /tmp/server2.pem)
if [ -f /tmp/server2.pem ]; then
    mv /tmp/server2.pem /opt/calc-connector/server2.pem
    chown root:root /opt/calc-connector/server2.pem
    chmod 600 /opt/calc-connector/server2.pem
fi

# 4. Write /opt/calc-connector/.env
cat << 'EOF' > /opt/calc-connector/.env
SERVER2_IP=<SERVER2_IP>
SERVER2_USER=<ADMIN_USER>
PEM_KEY_PATH=/opt/calc-connector/server2.pem
REMOTE_APP_PATH=/opt/calculator/calc_main.py
REMOTE_RESULT_PATH=/opt/calculator/results/result.txt
LOCAL_SAVE_PATH=/opt/calc-connector/results/result.txt
EOF
chown root:root /opt/calc-connector/.env
chmod 600 /opt/calc-connector/.env

# 5. Write /opt/calc-connector/run_calc.sh
cat << 'EOF' > /opt/calc-connector/run_calc.sh
#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
    exec sudo /opt/calc-connector/run_calc.sh "$@"
fi
set -uo pipefail
export XAUTHORITY="${XAUTHORITY:-/home/${SUDO_USER:-<USER_1>}/.Xauthority}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found" >&2
    exit 1
fi
set -a
source "$ENV_FILE"
set +a
SSH_OPTS=(-i "$PEM_KEY_PATH" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=10)
TARGET="${SERVER2_USER}@${SERVER2_IP}"
if [[ "${1:-}" == "--cli" ]]; then
    REMOTE_CMD="python3 $(printf '%q' "$REMOTE_APP_PATH") --cli=$(printf '%q' "$2")"
    ssh "${SSH_OPTS[@]}" "$TARGET" "$REMOTE_CMD"
    SSH_RC=$?
elif [[ $# -eq 0 ]]; then
    ssh -X "${SSH_OPTS[@]}" "$TARGET" "python3 $(printf '%q' "$REMOTE_APP_PATH")"
    SSH_RC=$?
else
    echo 'Usage: run_calc [--cli "EXPRESSION"]' >&2
    exit 1
fi
mkdir -p "$(dirname "$LOCAL_SAVE_PATH")"
if scp -q "${SSH_OPTS[@]}" "${TARGET}:${REMOTE_RESULT_PATH}" "$LOCAL_SAVE_PATH"; then
    chown root:calcreaders "$LOCAL_SAVE_PATH" && chmod 640 "$LOCAL_SAVE_PATH"
    echo ">> Result saved to $LOCAL_SAVE_PATH"
else
    echo "ERROR: could not fetch ${REMOTE_RESULT_PATH}" >&2
    exit 2
fi
exit $SSH_RC
EOF
chown root:root /opt/calc-connector/run_calc.sh
chmod 755 /opt/calc-connector/run_calc.sh
ln -sf /opt/calc-connector/run_calc.sh /usr/local/bin/run_calc

# 6. Configure sudoers rule allowing only run_calc.sh
cat << 'EOF' > /etc/sudoers.d/calc-connector
Defaults!/opt/calc-connector/run_calc.sh env_keep += "DISPLAY XAUTHORITY"
%vncusers ALL=(root) NOPASSWD: /opt/calc-connector/run_calc.sh
EOF
chown root:root /etc/sudoers.d/calc-connector
chmod 440 /etc/sudoers.d/calc-connector
```

**Configuration:**
```sudoers
# /etc/sudoers.d/calc-connector (mode 0440)
Defaults!/opt/calc-connector/run_calc.sh env_keep += "DISPLAY XAUTHORITY"
%vncusers ALL=(root) NOPASSWD: /opt/calc-connector/run_calc.sh
```

**Validation:**
```bash
visudo -cf /etc/sudoers.d/calc-connector
sudo -l -U <USER_1>
```

**Expected result:**
`visudo -cf` outputs `/etc/sudoers.d/calc-connector: parsed OK`, and `sudo -l -U <USER_1>` lists only `(root) NOPASSWD: /opt/calc-connector/run_calc.sh`.

---

## 9. Service Management and Verification Reference

All service management commands below require `root` privileges (or `sudo`).

| Service / Component | Start | Stop | Restart / Reload | Enable at Boot | Disable at Boot | Check Status & Logs |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TigerVNC Display `:1`** | `systemctl start vncserver@:1.service` | `systemctl stop vncserver@:1.service` | `systemctl restart vncserver@:1.service` | `systemctl enable vncserver@:1.service` | `systemctl disable vncserver@:1.service` | `systemctl status vncserver@:1.service`<br>`journalctl -u vncserver@:1.service -b --no-pager -n 50` |
| **All 4 TigerVNC Displays** | `systemctl start vncserver@:{1..4}.service` | `systemctl stop vncserver@:{1..4}.service` | `systemctl restart vncserver@:{1..4}.service` | `systemctl enable vncserver@:{1..4}.service` | `systemctl disable vncserver@:{1..4}.service` | `systemctl is-active vncserver@:{1..4}.service` |
| **OpenSSH Daemon (`sshd`)** | `systemctl start sshd` | `systemctl stop sshd` | `sshd -t && systemctl reload sshd` | `systemctl enable sshd` | `systemctl disable sshd` | `systemctl status sshd`<br>`journalctl -u sshd -b --no-pager -n 50` |
| **GNOME Display Manager** | `systemctl start gdm` | `systemctl stop gdm` | `systemctl restart gdm` | `systemctl enable gdm` | `systemctl disable gdm` | `systemctl status gdm`<br>`journalctl -u gdm -b --no-pager -n 50` |
| **Firewalld** | `systemctl start firewalld` | `systemctl stop firewalld` | `firewall-cmd --reload` | `systemctl enable firewalld` | `systemctl disable firewalld` | `systemctl status firewalld`<br>`firewall-cmd --list-all` |

### Process and Port Verification Commands (Run as `root`)

```bash
# Inspect all listening VNC and SSH sockets with owning PIDs
ss -lntp | grep -E ':22|:590[1-9]'

# Inspect established client VNC and SFTP connections
ss -ntp | grep -E ':22|:590[1-9]'

# Inspect running Xvnc and GNOME processes per user
ps -ef | grep -E 'Xvnc|gnome-session|gnome-shell' | grep -v grep

# Inspect active systemd user sessions
loginctl list-sessions
loginctl list-users
```

---

## 10. Troubleshooting Guide

### Issue 1: TigerVNC Viewer Fails with Socket Timeout Error `(10060)`
1. **Problem description:** Connecting from Windows TigerVNC Viewer displays `Failed to connect to "<IP>:5901": Unable to connect to socket: A connection attempt failed because the connected party did not properly respond after a period of time... (10060)`.
2. **Diagnostic commands:**
   * On RHEL 9.8 Server (`root`):
     ```bash
     hostname -I
     ss -lntp | grep 590
     firewall-cmd --list-ports
     ```
   * On Windows Client (`PowerShell`):
     ```powershell
     Test-NetConnection -ComputerName <SERVER_IP> -Port 5901
     ```
3. **Possible cause:**
   * The client entered the wrong server IP address (e.g., connecting to `<SERVER2_IP>` instead of `<SERVER_IP>`).
   * The AWS EC2 Security Group does not have an Inbound rule allowing TCP `5901–5904`.
   * `firewalld` is blocking `5901-5904/tcp`, or `localhost` is present in `/etc/tigervnc/vncserver-config-mandatory` forcing `Xvnc` to bind only to `127.0.0.1`.
4. **Corrective commands (Run as `root` on RHEL 9.8):**
   ```bash
   sed -i '/^localhost$/d' /etc/tigervnc/vncserver-config-mandatory /etc/tigervnc/vncserver-config-defaults
   firewall-cmd --permanent --add-port=5901-5904/tcp
   firewall-cmd --reload
   systemctl restart vncserver@:{1..4}.service
   ```
   *(Also open Inbound TCP `5901-5904` in the AWS EC2 Security Group and use the exact IP returned by `hostname -I`.)*
5. **Verification procedure:**
   `ss -lntp | grep 5901` shows `0.0.0.0:5901`, `Test-NetConnection -ComputerName <SERVER_IP> -Port 5901` returns `TcpTestSucceeded : True`, and TigerVNC Viewer prompts for the VNC password.

---

### Issue 2: User Added to Wrong SFTP Group (`sftp-denied` User Can Log Into SFTP)
1. **Problem description:** Users intended to be denied SFTP access (`<USER_3>`, `<USER_4>`) are able to connect via SFTP, and `sshd -T -C user=<USER_3>` shows `forcecommand internal-sftp`.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   id <USER_3>
   id <USER_4>
   getent group sftp-allowed sftp-denied
   ```
3. **Possible cause:** During user creation, `useradd -m -G sftp-allowed <USER_3>` was accidentally executed instead of `-G sftp-denied`, placing `<USER_3>` in `sftp-allowed` (`1001`). Because `Match Group sftp-allowed` is evaluated first in `40-sftp-access.conf`, `<USER_3>` is granted SFTP access.
4. **Corrective commands (Run as `root`):**
   ```bash
   usermod -G sftp-denied <USER_3>
   usermod -G sftp-denied <USER_4>
   loginctl terminate-user <USER_3> 2>/dev/null || true
   loginctl terminate-user <USER_4> 2>/dev/null || true
   systemctl restart vncserver@:3.service vncserver@:4.service
   ```
5. **Verification procedure:**
   `getent group sftp-allowed sftp-denied` shows `<USER_3>,<USER_4>` only under `sftp-denied:x:1002:`, and `sshd -T -C user=<USER_3>,host=localhost,addr=127.0.0.1 | grep passwordauthentication` returns `passwordauthentication no`.

---

### Issue 3: `bash: <PASSWORD>: command not found` When Setting VNC Password
1. **Problem description:** Running `su - <USER_1> -c "<PASSWORD>"` returns `bash: <PASSWORD>: command not found` and does not set the VNC password.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   ls -la /home/<USER_1>/.config/tigervnc/passwd
   ```
3. **Possible cause:** The `-c` flag of `su` takes the command name to execute (`vncpasswd`), not the password string. Also note that on RHEL 9.8, `vncpasswd` stores the file in `~/.config/tigervnc/passwd`, not `~/.vnc/passwd`.
4. **Corrective commands (Run as `root`):**
   ```bash
   su - <USER_1> -c "vncpasswd"
   ```
5. **Verification procedure:**
   `ls -l /home/<USER_1>/.config/tigervnc/passwd` shows `-rw-------. 1 <USER_1> <USER_1>`.

---

### Issue 4: `vncserver@:N.service` Fails to Start (Trailing Spaces or Stale X11 Lock)
1. **Problem description:** `systemctl start vncserver@:1.service` fails with `Job for vncserver@:1.service failed because the control process exited with error code`.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   journalctl -u vncserver@:1.service -b --no-pager -n 50
   cat -A /etc/tigervnc/vncserver.users
   ls -la /tmp/.X1-lock /tmp/.X11-unix/X1
   ```
3. **Possible cause:**
   * Trailing whitespace after the username in `/etc/tigervnc/vncserver.users` (e.g., `:1=<USER_1>   $`).
   * The user has not run `vncpasswd` yet (`/home/<USER_1>/.config/tigervnc/passwd` is missing).
   * A stale X11 lock file (`/tmp/.X1-lock` or `/tmp/.X11-unix/X1`) remains from an unclean shutdown.
4. **Corrective commands (Run as `root`):**
   ```bash
   sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users
   rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
   su - <USER_1> -c "vncpasswd"
   systemctl restart vncserver@:1.service
   ```
5. **Verification procedure:**
   `systemctl is-active vncserver@:1.service` returns `active`.

---

### Issue 5: SFTP Connection Immediately Closes (`Connection closed by remote host`)
1. **Problem description:** `sftp <USER_1>@<SERVER_IP>` accepts the password, then immediately exits with `client_loop: send disconnect: Broken pipe` or `Connection closed by remote host`.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   journalctl -u sshd --no-pager -n 30
   ls -ld /srv /srv/sftp /srv/sftp/<USER_1> /srv/sftp/<USER_1>/files
   ```
3. **Possible cause:** `sshd` logs `fatal: bad ownership or modes for chroot directory`. One of `/srv`, `/srv/sftp`, or `/srv/sftp/<USER_1>` is owned by `<USER_1>` instead of `root:root`, or has permissions wider than `0755` (such as `0775` or `0777`).
4. **Corrective commands (Run as `root`):**
   ```bash
   chown root:root /srv /srv/sftp /srv/sftp/<USER_1>
   chmod 755 /srv /srv/sftp /srv/sftp/<USER_1>
   chown <USER_1>:sftp-allowed /srv/sftp/<USER_1>/files
   chmod 700 /srv/sftp/<USER_1>/files
   ```
5. **Verification procedure:**
   `sftp <USER_1>@<SERVER_IP>` connects and stays at the `sftp>` prompt.

---

### Issue 6: SFTP Login Succeeds, But Uploading Files Fails with `Permission denied`
1. **Problem description:** `<USER_1>` logs into SFTP, runs `cd files` and `put file.txt`, and receives `remote open("/files/file.txt"): Permission denied`.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   ausearch -m avc -ts recent
   getsebool ssh_chroot_rw_homedirs
   ls -Zd /srv/sftp/<USER_1>/files
   ```
3. **Possible cause:**
   * The user tried to run `put` in the chroot root `/` instead of running `cd files` first.
   * SELinux is blocking `chroot_user_t` from writing to `/srv/sftp/<USER_1>/files` because the directory is labeled `var_t` instead of `user_home_t`, or `ssh_chroot_rw_homedirs` is `off`.
4. **Corrective commands (Run as `root`):**
   ```bash
   semanage fcontext -a -t user_home_t "/srv/sftp/[^/]+/files(/.*)?"
   restorecon -Rv /srv/sftp
   setsebool -P ssh_chroot_rw_homedirs on
   chown <USER_1>:sftp-allowed /srv/sftp/<USER_1>/files
   chmod 700 /srv/sftp/<USER_1>/files
   ```
5. **Verification procedure:**
   `ls -Zd /srv/sftp/<USER_1>/files` shows `user_home_t`, and `put` inside `files/` succeeds.

---

### Issue 7: SFTP Rejects Valid Password with `Permission denied (publickey,gssapi-keyex...)`
1. **Problem description:** Connecting via SFTP never prompts for a password and immediately fails with `Permission denied (publickey,gssapi-keyex,gssapi-with-mic)`.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   grep -rn "PasswordAuthentication" /etc/ssh/
   sshd -T -C user=<USER_1>,host=localhost,addr=127.0.0.1 | grep passwordauthentication
   ```
3. **Possible cause:** A drop-in file in `/etc/ssh/sshd_config.d/` with a lower lexical number (or `/etc/ssh/sshd_config`) sets `PasswordAuthentication no`.
4. **Corrective commands (Run as `root`):**
   ```bash
   sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   for f in /etc/ssh/sshd_config.d/*.conf; do
       [ -e "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
   done
   sshd -t && systemctl reload sshd
   ```
5. **Verification procedure:**
   `sshd -T -C user=<USER_1>,host=localhost,addr=127.0.0.1 | grep passwordauthentication` prints `passwordauthentication yes`.

---

### Issue 8: Group Changes Not Taking Effect Inside Running VNC Desktop Sessions
1. **Problem description:** After changing a user's groups with `usermod` or `gpasswd`, processes running inside their GNOME VNC desktop still reflect the old group permissions.
2. **Diagnostic commands (Run as `root`):**
   ```bash
   id <USER_1>
   loginctl list-sessions | grep <USER_1>
   ```
3. **Possible cause:** Linux sessions inherit supplementary group credentials at login time; running `Xvnc` and `gnome-session` processes do not dynamically reload `/etc/group`.
4. **Corrective commands (Run as `root`):**
   ```bash
   loginctl terminate-user <USER_1>
   systemctl restart vncserver@:1.service
   ```
5. **Verification procedure:**
   Open a new terminal in `<USER_1>`'s VNC desktop and run `id`; the output matches `id <USER_1>` from root.

---

### Issue 9: GUI or GNOME Session Fails to Start (`Oh no! Something has gone wrong`)
1. **Problem description:** Connecting to VNC displays a black screen or the GNOME crash screen (`Oh no! Something has gone wrong`).
2. **Diagnostic commands (Run as `root`):**
   ```bash
   rpm -q gnome-shell gnome-session xorg-x11-xauth
   cat /home/<USER_1>/.local/share/xorg/Xorg.*.log 2>/dev/null || journalctl -u vncserver@:1.service -n 50 --no-pager
   ls -ld /home/<USER_1>
   ```
3. **Possible cause:** Missing GNOME packages, corrupted `~/.config` or `~/.cache` ownership (e.g., owned by `root` after an admin ran a GUI command inside the user's home), or another active graphical login already running for the same user on local `gdm`.
4. **Corrective commands (Run as `root`):**
   ```bash
   chown -R <USER_1>:<USER_1> /home/<USER_1>
   chmod 700 /home/<USER_1>
   loginctl terminate-user <USER_1>
   systemctl restart vncserver@:1.service
   ```
5. **Verification procedure:**
   Reconnecting via TigerVNC Viewer loads the full GNOME desktop cleanly.

---

## 11. Employee Access Lifecycle Administration

### 11.1 Onboarding a New Employee (Example: `<NEW_USER>` on Display `:5` / Port `5905`)

Execute the following procedure as `root` on the RHEL 9.8 server:

```bash
# 1. Create Linux user and assign either 'sftp-allowed' OR 'sftp-denied'
# Option A (SFTP Allowed):
useradd -m -s /bin/bash -G sftp-allowed <NEW_USER>
# Option B (SFTP Denied):
# useradd -m -s /bin/bash -G sftp-denied <NEW_USER>

# 2. Set home directory permissions and interactive 8-character Linux password
chmod 700 /home/<NEW_USER>
passwd <NEW_USER>

# 3. Set matching 8-character VNC password interactively
su - <NEW_USER> -c "vncpasswd"

# 4. If SFTP Allowed, create chroot directory and apply SELinux context
mkdir -p /srv/sftp/<NEW_USER>/files
chown root:root /srv /srv/sftp /srv/sftp/<NEW_USER>
chmod 755 /srv /srv/sftp /srv/sftp/<NEW_USER>
chown <NEW_USER>:sftp-allowed /srv/sftp/<NEW_USER>/files
chmod 700 /srv/sftp/<NEW_USER>/files
restorecon -Rv /srv/sftp/<NEW_USER>

# 5. Assign next available VNC display (:5 -> TCP 5905)
echo ":5=<NEW_USER>" >> /etc/tigervnc/vncserver.users
sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users

# 6. Open port 5905 in firewalld (and AWS Security Group) and start service
firewall-cmd --permanent --add-port=5905/tcp
firewall-cmd --reload
systemctl daemon-reload
systemctl enable --now vncserver@:5.service
```

**Verify Onboarding:**
```bash
id <NEW_USER>
systemctl is-active vncserver@:5.service
ss -lntp | grep ':5905'
sshd -T -C user=<NEW_USER>,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand)'
```

---

### 11.2 Modifying an Existing Employee's Access

Execute as `root` on the RHEL 9.8 server:

#### A. Grant SFTP Access to a Previously Denied User (Move from `sftp-denied` to `sftp-allowed`)
```bash
gpasswd -d <USER_3> sftp-denied
usermod -aG sftp-allowed <USER_3>

mkdir -p /srv/sftp/<USER_3>/files
chown root:root /srv /srv/sftp /srv/sftp/<USER_3>
chmod 755 /srv /srv/sftp /srv/sftp/<USER_3>
chown <USER_3>:sftp-allowed /srv/sftp/<USER_3>/files
chmod 700 /srv/sftp/<USER_3>/files
restorecon -Rv /srv/sftp/<USER_3>

# Verify effective SSH/SFTP policy:
id <USER_3>
sshd -T -C user=<USER_3>,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand)'
```

#### B. Revoke SFTP Access from an Allowed User (Move from `sftp-allowed` to `sftp-denied`)
```bash
gpasswd -d <USER_2> sftp-allowed
usermod -aG sftp-denied <USER_2>

# Terminate any active SFTP/SSH processes owned by the user while keeping or restarting VNC:
pkill -u <USER_2> sshd 2>/dev/null || true

# Verify SFTP is now blocked:
id <USER_2>
sshd -T -C user=<USER_2>,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|forcecommand|denygroups)'
```

#### C. Reset an Employee's Linux and VNC Passwords
```bash
passwd <USER_1>
su - <USER_1> -c "vncpasswd"
systemctl restart vncserver@:1.service
systemctl is-active vncserver@:1.service
```

---

### 11.3 Offboarding a Leaving Employee (Preserving All Business Data)

When an employee leaves, **never run `userdel -r` or delete their files automatically**. Follow this sequence as `root` to immediately revoke VNC, SFTP, and Linux access while preserving and auditing their files:

```bash
# 1. Stop and disable the employee's VNC service (example: <USER_2> on display :2)
systemctl disable --now vncserver@:2.service

# 2. Remove the display mapping from /etc/tigervnc/vncserver.users
sed -i '/^:2=<USER_2>$/d' /etc/tigervnc/vncserver.users

# 3. Lock the Linux password, expire the account immediately, and set shell to nologin
usermod -L <USER_2>
chage -E 0 <USER_2>
usermod -s /sbin/nologin <USER_2>

# 4. Revoke SFTP and functional group memberships, and place in sftp-denied
gpasswd -d <USER_2> sftp-allowed 2>/dev/null || true
gpasswd -d <USER_2> vncusers 2>/dev/null || true
gpasswd -d <USER_2> calcreaders 2>/dev/null || true
usermod -aG sftp-denied <USER_2>

# 5. Terminate all remaining processes and active sessions for the user
loginctl terminate-user <USER_2> 2>/dev/null || true
pkill -9 -u <USER_2> 2>/dev/null || true

# 6. Audit and preserve all files owned by the employee in /home and /srv/sftp
mkdir -p /srv/archive/offboarded_<USER_2>_$(date +%F)
chmod 700 /srv/archive/offboarded_<USER_2>_$(date +%F)
find /home/<USER_2> /srv/sftp/<USER_2> -ls > /srv/archive/offboarded_<USER_2>_$(date +%F)/file_inventory.txt 2>/dev/null || true
cp -a /home/<USER_2> /srv/archive/offboarded_<USER_2>_$(date +%F)/home_backup 2>/dev/null || true
cp -a /srv/sftp/<USER_2> /srv/archive/offboarded_<USER_2>_$(date +%F)/sftp_backup 2>/dev/null || true
chown -R root:root /srv/archive/offboarded_<USER_2>_$(date +%F)
```

**Verify Offboarding:**
```bash
passwd -S <USER_2>
chage -l <USER_2>
id <USER_2>
systemctl is-active vncserver@:2.service || true
ss -lntp | grep ':5902' || echo "Port 5902 closed"
ps -u <USER_2> || echo "No active processes"
ls -ld /srv/archive/offboarded_<USER_2>_*
```
* **Expected result:** `passwd -S` shows `LK` (locked), `chage -l` shows `Account expires: Jan 01, 1970`, port `5902` is closed, zero processes are running as `<USER_2>`, and all files in `/home/<USER_2>` and `/srv/sftp/<USER_2>` remain intact and backed up under `/srv/archive/`.

---

## 12. Completed Configurations vs. Recommended Production Improvements

| Area | Completed Configuration (Implemented) | Recommended Production Improvement |
| :--- | :--- | :--- |
| **VNC Network Transport** | Direct TigerVNC on `0.0.0.0:5901–5904` with `securitytypes=vncauth,tlsvnc` and AWS Security Group / `firewalld` rules. | Restrict AWS Security Group Inbound `5901–5904` and `22` strictly to corporate VPN or static `/32` client IPs, never `0.0.0.0/0`. |
| **SSH/SFTP Brute-Force Protection** | Password authentication enabled for `sftp-allowed` (`1001`); `sftp-denied` (`1002`) blocked via `DenyGroups`. | Install and enable `fail2ban` (`sshd` jail) to automatically ban IPs after 5 failed password attempts on TCP port `22`. |
| **GNOME Idle Lock inside VNC** | Standard GNOME session launched per user. | Disable GNOME idle screen lock inside VNC (`gsettings set org.gnome.desktop.screensaver lock-enabled false`) so users only authenticate via `vncauth`. |
| **Audit & SIEM Logging** | Standard `journalctl` and `/var/log/secure` / `/var/log/audit/audit.log` logging. | Change `ForceCommand internal-sftp` to `ForceCommand internal-sftp -l INFO` to log every SFTP file upload, download, and deletion in `/var/log/secure`. |
