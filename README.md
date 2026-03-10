# nix infra

NixOS-based k3s cluster running on Proxmox, managed as a Nix flake.

## Hosts

| Host | Role | Network |
|------|------|---------|
| `nix-k3s-01` | k3s server | VLAN 2 (backend), VLAN 3 (vpn1), VLAN 4 (vpn2) |
| `nix-k3s-02-gpu` | k3s agent (Intel Arc GPU) | VLAN 2 (backend) |

## Structure

```
flake.nix
.sops.yaml                    # sops age key config
secrets/
  secrets.yaml                # encrypted secrets (sops)
nix/
  hosts/
    nix-k3s-01/
      configuration.nix       # host-specific config
      hardware-configuration.nix
    nix-k3s-02-gpu/
      configuration.nix
      hardware-configuration.nix
  modules/
    caddy.nix     # reverse proxy
    common.nix    # shared config for all hosts
    forgejo.nix   # git and container reg
    k3s.nix       # k3s
    nfs.nix       # NFS client mounts
    sops.nix      # secrets (sops-nix)
    vlans.nix     # VLAN
```

## Deploying a host

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Setting up a new VM

### 1. Create the VM in Proxmox

- Download the [NixOS minimal ISO](https://nixos.org/download/) (x86_64-linux)
- Create a VM in Proxmox with **q35 machine type** and **UEFI (OVMF)** BIOS, add a TPM
- Attach the ISO and boot it

### 2. Install NixOS

Boot into the ISO. Partition, format, and install:

```bash
# GPT + UEFI: ESP + root partition
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB  # /dev/sda1 - EFI System Partition
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary 512MiB 100%     # /dev/sda2 - root

# Format partitions
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

# Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Generate config
nixos-generate-config --root /mnt
```

Edit `/mnt/etc/nixos/configuration.nix` to allow SSH access temporarily:

```nix
services.openssh.enable = true;
users.users.root.initialPassword = "nixos";
networking.interfaces.ens18.useDHCP = true;
```

Install and reboot:

```bash
nixos-install
reboot
```

### 3. Get the hardware config

After rebooting into the installed system, run:

```bash
nixos-generate-config --show-hardware-config
```

Copy the output into `nix/hosts/<hostname>/hardware-configuration.nix`, commit, and push.

### 4. Generate the flake.lock (first time only)

If there is no `flake.lock` in the repo yet, generate one on the VM:

```bash
nix-shell -p git --run "
  git clone https://github.com/stolpela/infra &&
  cd infra &&
  nix --extra-experimental-features 'nix-command flakes' flake update &&
  git add flake.lock &&
  git -c user.email='you@example.com' -c user.name='lars' commit -m 'add flake.lock' &&
  git push
"
```

### 5. Deploy

```bash
cd /tmp && sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

### 6. Set up secrets (sops-nix)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). Each host decrypts secrets at activation using its SSH host key (converted to age automatically).

**Prerequisites:** `sops` and `age` installed on your local machine. `ssh-to-age` available via `nix-shell -p ssh-to-age`.

#### Generate your admin age key (once)

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Note the public key (`age1...`) from the output.

#### Get each host's age public key

From your local machine:

```bash
ssh-keyscan nix-k3s-01 2>/dev/null | ssh-to-age
ssh-keyscan nix-k3s-02-gpu 2>/dev/null | ssh-to-age
```

Or on the VM itself:

```bash
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

#### Update `.sops.yaml`

Replace the placeholder `age1xxx...` keys with the real keys:

```yaml
keys:
  - &admin age1<your-admin-public-key>
  - &nix-k3s-01 age1<from-ssh-to-age>
  - &nix-k3s-02-gpu age1<from-ssh-to-age>

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *admin
          - *nix-k3s-01
          - *nix-k3s-02-gpu
```

#### Encrypt the secrets file

Fill in the real values, then encrypt in-place:

```bash
sops -e -i secrets/secrets.yaml
```

The encrypted file is safe to commit. To edit later:

```bash
sops secrets/secrets.yaml
```

This decrypts to your editor and re-encrypts on save.

### 7. Verify

```bash
sudo kubectl get nodes
```

All nodes should appear as `Ready`.

## Adding a service module

### 1. Create the module

Add a new file in `nix/modules/`, e.g. `nix/modules/myservice.nix`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.myservice;
in
{
  options.myservice = {
    enable = lib.mkEnableOption "my service";

    # Add any options your module needs
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for the service";
    };
  };

  config = lib.mkIf cfg.enable {
    # Set NixOS options here — this only applies when enable = true
    services.someService.enable = true;

    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}
```

Key pieces:
- **`options`** declares configurable knobs with types and defaults
- **`config`** wraps the actual system configuration in `lib.mkIf cfg.enable` so it only applies when the module is turned on
- Inside `config`, you set upstream NixOS options (browse available options at [search.nixos.org/options](https://search.nixos.org/options))

### 2. Register the module in flake.nix

Add the module to the host's `modules` list:

```nix
nix-k3s-01 = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./nix/hosts/nix-k3s-01/configuration.nix
    ./nix/modules/common.nix
    ./nix/modules/k3s.nix
    ./nix/modules/vlans.nix
    ./nix/modules/myservice.nix  # add here
  ];
};
```

### 3. Enable it in the host config

In `nix/hosts/<hostname>/configuration.nix`, set the options you defined:

```nix
myservice = {
  enable = true;
  domain = "myservice.example.com";
};
```

### 4. Expose it through Caddy

If the service has a web interface, add a virtual host in the host config:

```nix
caddy = {
  enable = true;
  virtualHosts = {
    "myservice.example.com" = {
      reverseProxy = "localhost:8080";
    };
  };
};
```

Caddy merges virtual hosts from all modules, so you can add entries alongside existing ones. Make sure DNS for the domain points to the host.

### 5. Deploy

```bash
cd /tmp && sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Adding an NFS mount

### 1. Register the NFS module

Make sure `./nix/modules/nfs.nix` is in the host's `modules` list in `flake.nix` (already done for `nix-k3s-01`).

### 2. Add the mount in the host config

In `nix/hosts/<hostname>/configuration.nix`:

```nix
nfs = {
  enable = true;
  mounts."/mnt/s1/media" = {
    device = "nas.9rv.org:/mnt/s1/data/media";
    # options default to [ "nfsvers=4" "soft" "timeo=15" ]
  };
};
```

To add more mounts, add more entries under `mounts`:

```nix
nfs = {
  enable = true;
  mounts."/mnt/s1/media" = {
    device = "nas.9rv.org:/mnt/s1/data/media";
  };
  mounts."/mnt/s1/backups" = {
    device = "nas.9rv.org:/mnt/s1/data/backups";
    options = [ "nfsvers=4" "soft" "timeo=15" "ro" ];  # read-only example
  };
};
```

### 3. Deploy

```bash
cd /tmp && sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

Permissions are managed server-side via NFS exports and group membership.

## Updating the flake lock

To update nixpkgs to the latest commit on `nixos-24.11`:

```bash
nix flake update
git add flake.lock && git commit -m "flake: update nixpkgs" && git push
```

Then redeploy each host.

## Notes

- SSH user is `admin` (root login is disabled)
- SSH key authentication only (password auth disabled)
- Secrets (k3s token, Cloudflare API token) are managed with sops-nix
- traefik and servicelb are disabled; using caddy and metallb
