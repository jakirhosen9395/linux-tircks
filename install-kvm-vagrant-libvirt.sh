#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install-kvm-vagrant-libvirt.sh
# Purpose: Install KVM/QEMU + libvirt + Vagrant (HashiCorp repo) + vagrant-libvirt
# Behavior: No mid-script reboot. If reboot is required, it offers to reboot ONLY
#          at the end.
# Tested intent: Ubuntu 24.04 LTS
# -----------------------------------------------------------------------------

log()  { echo -e "🛠️  $*"; }
ok()   { echo -e "✅ $*"; }
warn() { echo -e "⚠️  $*"; }
die()  { echo -e "❌ $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

have_reboot_required() {
  [[ -f /var/run/reboot-required ]]
}

is_ubuntu() {
  [[ -r /etc/os-release ]] && . /etc/os-release && [[ "${ID:-}" == "ubuntu" ]]
}

require_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    SUDO=""
  else
    need_cmd sudo
    sudo -v || die "sudo auth failed"
    SUDO="sudo"
  fi
}

check_virtualization() {
  log "Checking CPU virtualization flags (vmx/svm)…"
  local count
  count="$(egrep -c '(vmx|svm)' /proc/cpuinfo || true)"
  if [[ "$count" -gt 0 ]]; then
    ok "Virtualization flags detected (count=$count)."
  else
    warn "No vmx/svm flags detected. Virtualization may be disabled in BIOS/UEFI."
    warn "KVM can still install, but VM performance/creation may fail."
  fi

  if command -v lscpu >/dev/null 2>&1; then
    log "OS virtualization line:"
    lscpu | grep -i "Virtualization" || true
  fi
}

apt_update_upgrade() {
  log "Updating packages (apt update/upgrade/dist-upgrade)…"
  $SUDO apt-get update -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
  $SUDO apt-get autoremove -y
  $SUDO apt-get clean
  ok "System update completed."
}

install_ssh() {
  log "Installing OpenSSH server…"
  $SUDO apt-get install -y openssh-server
  $SUDO systemctl enable --now ssh
  ok "SSH is enabled and started."
  log "SSH status (first lines):"
  $SUDO systemctl status ssh --no-pager | sed -n '1,12p' || true
}

install_kvm_libvirt() {
  log "Installing KVM/QEMU + libvirt packages…"
  $SUDO apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils
  $SUDO systemctl enable --now libvirtd
  ok "libvirtd enabled and started."
  log "libvirtd status (first lines):"
  $SUDO systemctl status libvirtd --no-pager | sed -n '1,12p' || true
}

configure_user_groups() {
  local user="${SUDO_USER:-$USER}"

  log "Adding user '$user' to libvirt/kvm groups…"
  $SUDO usermod -aG libvirt "$user" || true
  # Some distros use libvirt-kvm; Ubuntu commonly uses kvm.
  $SUDO groupadd -f libvirt-kvm || true
  $SUDO usermod -aG libvirt-kvm "$user" || true
  $SUDO usermod -aG kvm "$user" || true

  ok "Group updates applied."
  warn "Group membership changes require a new login session."
  warn "Best: log out/in (or reboot)."
}

install_vagrant_hashicorp_repo() {
  need_cmd curl
  need_cmd gpg
  need_cmd lsb_release

  log "Installing prerequisites for HashiCorp APT repo…"
  $SUDO apt-get install -y curl gnupg software-properties-common

  log "Adding HashiCorp GPG key…"
  $SUDO mkdir -p /usr/share/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

  local codename
  codename="$(lsb_release -cs)"
  log "Adding HashiCorp APT repo for '${codename}'…"
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${codename} main" \
    | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  $SUDO apt-get update -y

  log "Installing Vagrant…"
  $SUDO apt-get install -y vagrant

  ok "Vagrant installed."
  vagrant version || true
}

install_vagrant_libvirt_plugin() {
  log "Installing build dependencies for vagrant-libvirt…"
  $SUDO apt-get install -y libvirt-dev ruby-dev make gcc

  log "Installing Vagrant plugin: vagrant-libvirt…"
  # This installs to the current user's Vagrant plugin directory.
  vagrant plugin install vagrant-libvirt
  ok "vagrant-libvirt plugin installed."

  log "Installed plugins:"
  vagrant plugin list || true
}

post_checks() {
  log "Post-checks…"

  log "KVM device permissions:"
  ls -l /dev/kvm || true

  log "virsh connectivity (may require relog/reboot after group change):"
  virsh list --all || true

  ok "Post-checks done."
}

maybe_reboot_at_end() {
  if have_reboot_required; then
    warn "Reboot is required (found /var/run/reboot-required)."
    echo -n "🔥 Reboot now? (y/N): "
    read -r ans
    if [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
      log "Rebooting now…"
      $SUDO reboot
    else
      warn "Skipped reboot. Please reboot later to apply kernel/group changes."
    fi
  else
    ok "No reboot required."
  fi
}

main() {
  is_ubuntu || warn "This script is designed for Ubuntu. Proceeding anyway…"

  require_sudo
  need_cmd apt-get
  need_cmd systemctl
  need_cmd egrep

  log "Starting install: KVM/libvirt + Vagrant + vagrant-libvirt 🚀"
  log "User: ${SUDO_USER:-$USER}"
  log "Host: $(hostname)"
  log "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | head -n 1)"

  check_virtualization
  apt_update_upgrade

  # Optional but recommended:
  install_ssh

  install_kvm_libvirt
  configure_user_groups

  install_vagrant_hashicorp_repo
  install_vagrant_libvirt_plugin

  post_checks

  echo
  ok "All done. Your host is ready for: vagrant up --provider=libvirt 🎉"
  warn "If 'virsh list --all' fails due to permissions, reboot/relogin fixes it."

  maybe_reboot_at_end
}

main "$@"
