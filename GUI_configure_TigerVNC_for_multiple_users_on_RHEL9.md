# RHEL 9 on AWS EC2 — GNOME GUI, TigerVNC, EPEL Repository, and htop Installation

**Platform:** Red Hat Enterprise Linux 9  
**Environment:** AWS EC2  
**Purpose:** Configure a graphical desktop, separate VNC sessions for two EDA users, and EPEL so that `htop` can be installed and maintained.

---

## 1. Prerequisites and repository validation

Connect to the EC2 instance using SSH as `ec2-user`.

Check the operating system:

```bash
cat /etc/redhat-release
cat /etc/os-release
```

Check the available repositories:

```bash
sudo dnf repolist --all
ls -l /etc/yum.repos.d/
```

### 1.1 Repair AWS RHUI repository access if necessary

If this is an AWS RHEL 9 instance and the BaseOS/AppStream repositories are missing, check whether the AWS RHUI recovery command is available:

```bash
command -v rhui-reenable
```

If available, run:

```bash
sudo rhui-reenable
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

AWS RHEL images can have RHUI repository configuration issues, particularly when Red Hat subscription registration fails. Use this recovery method only when appropriate for the instance. See [Red Hat's AWS RHUI guidance](https://access.redhat.com/solutions/7134382).

**Validation requirement:** Confirm that the required BaseOS and AppStream repositories are enabled and metadata can be downloaded before proceeding.

If they remain unavailable, investigate the AMI, RHUI configuration, network access, and any proxy restrictions. Do not blindly register the instance or replace its repository files.

## 2. Configure EPEL and install htop

EPEL (Extra Packages for Enterprise Linux) provides additional packages for RHEL, including `htop`.

### 2.1 Install the EPEL release package

After the RHEL repositories are functioning, run:

```bash
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
```

This installs the EPEL repository configuration. It does not replace or repair the underlying RHEL BaseOS/AppStream repositories.

Official reference: [AWS — Activate EPEL on EC2](https://repost.aws/knowledge-center/ec2-enable-epel).

### 2.2 Enable CRB if required

Some EPEL packages require dependencies from the CodeReady Linux Builder (CRB) repository. Check whether CRB is available:

```bash
sudo dnf repolist --all | grep -i crb
```

If the system exposes a CRB repository, enable it:

```bash
sudo dnf config-manager --set-enabled crb
```

If `config-manager` is unavailable, install its supporting package if the enabled repositories provide it:

```bash
sudo dnf install -y dnf-plugins-core
```

Do not assume that a repository named `crb` exists on every AWS RHEL image. Resolve missing base repositories first.

### 2.3 Refresh metadata and install htop

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
sudo dnf install -y htop
```

Verify:

```bash
htop --version
htop
```

If installation fails, check the repository state:

```bash
sudo dnf repolist --enabled
sudo dnf list --available htop
sudo dnf info epel-release
```

The expected outcome is that `htop` is installed and launches successfully.

---

## 3. Install GNOME GUI and TigerVNC

Perform this step after repository access is working.

### 3.1 Update the system

```bash
sudo dnf update -y
```

For production EDA servers, schedule kernel updates and reboots according to the maintenance window.

### 3.2 Install the desktop environment

```bash
sudo dnf groupinstall -y "Server with GUI"
```

Install TigerVNC:

```bash
sudo dnf install -y tigervnc-server
```

Verify the installation:

```bash
rpm -q tigervnc-server
vncserver --version
```

Set the default boot target to graphical mode if the server should start in graphical mode after reboot:

```bash
sudo systemctl set-default graphical.target
```

This changes the default boot target. It does not require an immediate reboot.

**Note:** A VNC desktop session can run independently of the local graphical login screen. Changing the default boot target is optional when only virtual VNC desktops are needed.

---

## 4. Create separate EDA user accounts

Create two dedicated, non-root users:

```bash
sudo useradd -m vnc-user1
sudo passwd vnc-user1

sudo useradd -m vnc-user2
sudo passwd vnc-user2
```

If the accounts already exist, skip `useradd` and reset passwords only when necessary.

Verify:

```bash
id vnc-user1
id vnc-user2
```

Keep these accounts unprivileged unless a documented operational requirement justifies additional permissions. Do not grant unrestricted `sudo` access merely to run EDA applications.

---

## 5. Configure VNC passwords and desktop sessions

Each user requires a separate VNC authentication password. This password is different from the Linux login password.

### 5.1 Configure vnc-user1

```bash
sudo su - vnc-user1
vncpasswd
mkdir -p ~/.vnc
exit
```

### 5.2 Configure vnc-user2

```bash
sudo su - vnc-user2
vncpasswd
mkdir -p ~/.vnc
exit
```

Enter the VNC password interactively. Do not put passwords in shell scripts or command-line arguments.

### 5.3 Configure the GNOME session

For the standard RHEL 9 TigerVNC setup, configure the server defaults:

```bash
sudo install -d -m 755 /etc/tigervnc

sudo tee /etc/tigervnc/vncserver-config-defaults >/dev/null <<'EOF'
session=gnome
geometry=1920x1080
securitytypes=vncauth
EOF
```

These defaults configure the GNOME session, resolution, and VNC password authentication.

Do not add `localhost=no` when using SSH tunneling. Restricting VNC to loopback is preferable when supported by the installed configuration.

TigerVNC configuration paths can vary by version. In RHEL 9, check the installed manual and configuration files before adding per-user options:

```bash
man Xvnc
rpm -ql tigervnc-server | grep -E 'vncserver-config|vncserver.users'
```

For TigerVNC 1.14 and newer, user configuration may use `$HOME/.config/tigervnc`; older configurations commonly use `$HOME/.vnc/config`. Avoid maintaining conflicting settings in multiple locations.

---

## 6. Map VNC display numbers to users

Edit the user mapping file:

```bash
sudo vi /etc/tigervnc/vncserver.users
```

Add these entries:

```text
:1=vnc-user1
:2=vnc-user2
```

Save and exit.

Display and TCP port mappings are:

| User | Display | TCP port |
|---|---:|---:|
| vnc-user1 | :1 | 5901 |
| vnc-user2 | :2 | 5902 |

The display number determines the port: TCP port = 5900 + display number.

Official reference: [Red Hat — Remotely accessing the desktop as multiple users](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/getting_started_with_the_gnome_desktop_environment/remotely-accessing-an-individual-application-wayland_getting-started-with-the-gnome-desktop-environment).

---

## 7. Start and enable TigerVNC services

Enable and start both sessions:

```bash
sudo systemctl enable --now vncserver@:1.service
sudo systemctl enable --now vncserver@:2.service
```

Check service status:

```bash
sudo systemctl status vncserver@:1.service
sudo systemctl status vncserver@:2.service
```

Check listening ports:

```bash
sudo ss -lntp | grep -E '5901|5902'
```

If either service fails, inspect its logs:

```bash
sudo journalctl -u vncserver@:1.service -b --no-pager -n 100
sudo journalctl -u vncserver@:2.service -b --no-pager -n 100
```

If the service reports that the session cannot start, verify the GNOME session files:

```bash
ls /usr/share/xsessions/
ls /usr/share/wayland-sessions/
```

Confirm that the selected session is installed and compatible with TigerVNC. Do not assume every GNOME Wayland session can be launched through a virtual Xvnc desktop.

---

## 8. Firewall and AWS Security Group configuration

### 8.1 Local firewalld

For SSH-tunnel-only access, do not open VNC ports to the network unnecessarily.

Check the firewall:

```bash
sudo systemctl is-active firewalld
sudo firewall-cmd --get-active-zones
```

If direct VNC access is explicitly required, restrict the allowed source IPs in both the host firewall and the AWS Security Group. Avoid opening VNC to `0.0.0.0/0`.

### 8.2 AWS Security Group

For the recommended SSH-tunnel setup, the inbound rules should allow:

- TCP 22 (SSH) from your trusted public IP address or approved corporate network.
- No public inbound rules for TCP 5901 or TCP 5902.

Ensure your SSH key, user account, and network access are configured correctly.

---

## 9. Connect from Windows using SSH tunneling

Install a compatible TigerVNC Viewer on your Windows machine.

Open PowerShell and create the tunnels:

```powershell
ssh -i "C:\path\to\your-key.pem" -N -L 5901:127.0.0.1:5901 -L 5902:127.0.0.1:5902 ec2-user@YOUR_EC2_PUBLIC_IP
```

Replace the key path and EC2 address with your actual values. Keep this PowerShell window open while using VNC.

In TigerVNC Viewer, connect to:

```text
127.0.0.1:5901
```

for `vnc-user1`, or:

```text
127.0.0.1:5902
```

for `vnc-user2`.

Enter the relevant user's VNC password.

The SSH tunnel encrypts the network connection between Windows and EC2, so the VNC ports do not need to be exposed publicly.

---

## 10. Troubleshooting checklist

### EPEL or htop installation fails

```bash
cat /etc/redhat-release
sudo dnf repolist --all
sudo dnf makecache
sudo dnf list --available htop
```

Confirm that BaseOS/AppStream work before troubleshooting EPEL further.

### VNC service fails

```bash
sudo systemctl status vncserver@:1.service
sudo journalctl -u vncserver@:1.service -b --no-pager -n 100
```

Check the same commands for display `:2`. Review the user's VNC logs under `~/.local/state/tigervnc/` on recent TigerVNC releases.

### SSH tunnel works, but the viewer cannot connect

```bash
sudo ss -lntp | grep -E '5901|5902'
```

Verify that the VNC service is listening and that the tunnel is active. If TigerVNC listens only on loopback, the SSH forwarding target should normally be `127.0.0.1`.

### GNOME desktop does not start

Verify that GNOME is installed and the selected session exists. Review the TigerVNC journal and per-user logs before changing the display manager or disabling Wayland globally.

---

## 11. Final verification

Run these commands to confirm the main components:

```bash
cat /etc/redhat-release
sudo dnf repolist --enabled
rpm -q tigervnc-server htop
sudo systemctl is-enabled vncserver@:1.service
sudo systemctl is-enabled vncserver@:2.service
sudo systemctl is-active vncserver@:1.service
sudo systemctl is-active vncserver@:2.service
```

**Completion criteria:**

- RHEL repositories and EPEL metadata are accessible.
- `htop` installs and runs.
- GNOME and TigerVNC are installed.
- Both dedicated users have VNC passwords and separate display mappings.
- Both services start successfully and survive reboots.
- Remote access works through SSH tunneling without exposing VNC ports publicly.

**Maintenance recommendation:** Document package sources, retain SSH-only administrative access, review user privileges periodically, and test VNC services after major GNOME or TigerVNC updates.
