# 🐚 Zsh + Oh My Zsh + Powerlevel10k (p10k) Setup on Ubuntu (GNOME) 🚀

> Target OS: **Ubuntu 24.04 LTS (Noble)** (based on your `archive.ubuntu.com/ubuntu noble` output)  
> Goal: Install **zsh**, set it as default shell, install **Oh My Zsh**, apply **Powerlevel10k** theme, configure **MesloLGS NF** font, and enable **zsh-autosuggestions**.

---

## 🔐 Security & Hygiene (Read First)
- Prefer **official repos** for base packages (`apt`).
- Review remote install scripts **before** running them in regulated environments.
- Use least privilege: `sudo` only when required.
- Ensure outbound access to `github.com` is allowed by DNS/proxy/firewall.

---

## ✅ Prerequisites
- Ubuntu with internet access
- A user account with sudo privileges
- `curl` installed (usually preinstalled)
- GNOME desktop (for **Tweaks** step)

---

## 1) Install `zsh` 🧩

### Command
```bash
sudo apt install zsh
```

### Expected output (sample)
```text
The following NEW packages will be installed:
  zsh zsh-common
...
Setting up zsh (5.9-6ubuntu2) ...
```

### Verify current shell
```bash
echo $0
```

### Expected output
```text
bash
```

---

## 2) Set `zsh` as your default login shell 🔁

### Command
```bash
chsh
```

### Expected interaction (sample)
```text
Changing the login shell for jakir
Login Shell [/bin/bash]: /bin/zsh
```

### Reboot (required for login shell change to fully apply)
```bash
sudo reboot now
```

---

## 3) First launch: create `.zshrc` 📝

After reboot:
- Open terminal: **Ctrl + Alt + T**
- You will see **zsh-newuser-install**
- Press **(2)** to populate recommended `.zshrc`

### Expected screen (sample)
```text
This is the Z Shell configuration function for new users,
zsh-newuser-install.

(2)  Populate your ~/.zshrc with the configuration recommended...
--- Type one of the keys in parentheses --- 2
```

### Verify shell is now zsh
```bash
echo $0
```

### Expected output
```text
zsh
```

---

## 4) Install `git` (required by Oh My Zsh) 🧰

If you run Oh My Zsh install and see:
```text
Error: git is not installed
```

Install git:
```bash
sudo apt install git -y
```

### Expected output (sample)
```text
Setting up git (1:2.43.0-1ubuntu7.3) ...
```

---

## 5) Install Oh My Zsh ✨

### Command (as you ran)
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Expected output (sample)
```text
Cloning Oh My Zsh...
Found /home/jakir/.zshrc.
Do you want to overwrite it with the Oh My Zsh template? [Y/n] Y
...
....is now installed!
```

> If prompted, you chose **Y** to overwrite the `.zshrc` with Oh My Zsh template.

---

## 6) Install Powerlevel10k theme 🎨

### Command (Oh My Zsh method)
```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
```

### Possible error you hit (DNS / network)
```text
fatal: unable to access 'https://github.com/romkatv/powerlevel10k.git/': Could not resolve host: github.com
```

### Quick fix checklist (recommended)
```bash
# 1) Confirm DNS works
getent hosts github.com

# 2) Check basic connectivity
ping -c 2 1.1.1.1

# 3) Check if a proxy is required (corporate networks)
env | grep -i proxy || true
```

Re-run the clone after network is healthy:
```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
```

### Expected output (sample)
```text
Cloning into '/home/jakir/.oh-my-zsh/custom/themes/powerlevel10k'...
Receiving objects: 100% (92/92), ...
Resolving deltas: 100% (18/18), done.
```

---

## 7) Set Powerlevel10k as your theme 🧠

Edit `~/.zshrc` and change theme line to:
```text
ZSH_THEME="powerlevel10k/powerlevel10k"
```

### Command (as you did)
```bash
vim ~/.zshrc
```

> Update at/around line 11:  
> `ZSH_THEME="powerlevel10k/powerlevel10k"`

### Apply changes
```bash
source ~/.zshrc
```

---

## 8) Install GNOME Tweaks + Set MesloLGS NF Font 🖋️

### Install Tweaks
```bash
sudo apt install gnome-tweaks
```

### Expected output (sample)
```text
Setting up gnome-tweaks (46.0-2) ...
```

### Set font in UI
1. Open **Tweaks**
2. Go to **Fonts**
3. Set **Monospace Text** (and/or Terminal font depending on your setup) to:  
   ✅ **MesloLGS NF Regular**

> Why: Powerlevel10k needs a Nerd Font to render icons cleanly.

---

## 9) Powerlevel10k configuration wizard 🧪

Open a new terminal (**Ctrl + Alt + T**) and follow the prompts.

### Example prompts you saw
**Diamond test**
```text
Does this look like a diamond (rotated square)?
--->    <---
Choice [ynq]: y
```

**Lock test**
```text
Does this look like a lock?
--->    <---
Choice [ynrq]: y
```

**Arrow test**
```text
Does this look like an upwards arrow?
--->  󰜷  <---
Choice [ynrq]: n
```

Then it retries:
```text
Let's try another one.
--->  ﰵ  <---
Choice [ynrq]: y
```

Eventually you will make style selections, and it writes config files:

### Expected final output
```text
New config: ~/.p10k.zsh.
Backup of ~/.zshrc: /tmp/.zshrc.XXXXXXXXXX.

See ~/.zshrc changes:
  diff /tmp/.zshrc.XXXXXXXXXX ~/.zshrc
```

---

## 10) (Optional but recommended) Clone your Linux setup repo 📦

You ran:
```bash
git clone https://github.com/ibnYusrat/my-linux-setup.git
```

### Expected output (sample)
```text
Cloning into 'my-linux-setup'...
Receiving objects: 100% (...), ...
Resolving deltas: 100% (...), done.
```

---

## 11) Install `zsh-autosuggestions` plugin ⚡

### Clone plugin into Oh My Zsh custom plugins
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### Expected output (sample)
```text
Cloning into '/home/jakir/.oh-my-zsh/custom/plugins/zsh-autosuggestions'...
Receiving objects: 100% (...), done.
```

### Enable it in `~/.zshrc`
Find the `plugins=(...)` line and add `zsh-autosuggestions`.

Example:
```bash
plugins=(
  git
  zsh-autosuggestions
)
```

### Apply
```bash
source ~/.zshrc
```

### Expected behavior
- Start typing a command you used before
- You should see a **faint suggestion** to the right
- Press **→ (Right Arrow)** to accept the suggestion

---

## ✅ Final verification checklist 🧾

Run:
```bash
echo $0
```
Expected:
```text
zsh
```

Run:
```bash
grep -n '^ZSH_THEME=' ~/.zshrc
```
Expected:
```text
...ZSH_THEME="powerlevel10k/powerlevel10k"
```

Confirm plugin is loaded:
```bash
grep -n 'zsh-autosuggestions' ~/.zshrc
```
Expected:
```text
... zsh-autosuggestions ...
```

---

## 🔗 References (Official / Source-of-Truth) 📚
- Oh My Zsh install: https://ohmyz.sh/#install
- Powerlevel10k (Oh My Zsh): https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#oh-my-zsh
- zsh-autosuggestions (Oh My Zsh): https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
- Video walkthroughs you referenced:
  - https://www.youtube.com/watch?v=PZTLIVQxxEY
  - https://www.youtube.com/watch?v=Gj5BuFwGK6o&t=165s
- Your setup repo reference:
  - https://github.com/ibnyusrat/my-linux-setup
