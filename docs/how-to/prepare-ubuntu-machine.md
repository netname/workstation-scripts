# Prepare an Ubuntu Machine

Use this guide before running the workstation bootstrap on a new physical machine, VM, or cloud host.

The bootstrap expects an Ubuntu user account with sudo, outbound network access, SSH access to GitHub, and enough base packages to download and run shell scripts.

## Supported Starting Point

Use Ubuntu Server 24.04 LTS when possible. Ubuntu Desktop also works, but the main bootstrap is intentionally headless. Install the optional desktop layer later with [Add Graphical Desktop](add-graphical-desktop.md).

Minimum starting assumptions:

- You can log in as the target Linux user.
- The user can run `sudo`.
- The machine can reach GitHub, the Ubuntu package repositories, the Nix installer, and Docker package repositories.
- The system clock is correct enough for TLS and GitHub authentication.

## Prepare Any Ubuntu Machine

Update the base system:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git openssh-client openssh-server ca-certificates gnupg lsb-release
```

Enable SSH if this is a remote or VM-based workstation:

```bash
sudo systemctl enable --now ssh
systemctl status ssh --no-pager
```

Verify network and DNS:

```bash
ping -c 3 github.com
curl -I https://github.com
```

## Prepare SSH for GitHub

Create an SSH key if the machine does not already have one:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub, then verify:

```bash
ssh -T git@github.com
```

GitHub normally exits with status `1` because it does not provide shell access. The success signal is a message that authenticates your GitHub username.

## VMware Workstation Path

For VMware Workstation, use bridged networking when the workstation should be reachable from the host LAN and from other devices. NAT is acceptable for isolated testing, but bridged mode makes SSH and XRDP simpler to reason about.

VM setup checklist:

1. Create a VM with Ubuntu Server 24.04 LTS.
2. Assign enough disk for Nix and Docker images. Start with at least 60 GB for a comfortable development box.
3. Use bridged networking unless there is a reason to isolate the guest.
4. Install OpenSSH Server during Ubuntu installation.
5. After first boot, install VMware guest tools:

```bash
sudo apt update
sudo apt install -y open-vm-tools
sudo systemctl enable --now vmtoolsd
```

Verify the network address:

```bash
ip addr
hostname -I
```

From the host, verify SSH:

```bash
ssh your-linux-user@vm-ip-address
```

## Snapshot Before Bootstrap

On VMs, take a snapshot after the base OS, SSH, and GitHub access are working but before running the bootstrap. Name it something like `ubuntu-base-before-workstation-bootstrap`.

This gives you a fast retry point if you are testing script changes or validating a new template.

## Get the Bootstrap Onto the Machine

If the public scripts repository is already available on GitHub, download the script directly:

```bash
wget -qO bootstrap.sh https://raw.githubusercontent.com/YOUR_GITHUB_USER/workstation-scripts/main/scripts/bootstrap.sh
chmod +x bootstrap.sh
```

Run it with explicit inputs:

```bash
bash bootstrap.sh \
  --github-user YOUR_GITHUB_USER \
  --dotfiles-repo git@github.com:YOUR_GITHUB_USER/dotfiles.git
```

For the complete first-machine path, continue with [First Workstation](../tutorials/first-workstation.md).

## Verification

Before the bootstrap, these checks should pass:

```bash
whoami
sudo -v
git --version
curl --version
ssh -T git@github.com
```

After the bootstrap, use [First Workstation](../tutorials/first-workstation.md#7-verify-the-workstation) for the final workstation verification.
