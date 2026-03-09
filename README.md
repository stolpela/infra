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
    vlans.nix     # VLAN
```

## Deploying a host

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Setting up a new VM

### 1. Create the VM in Proxmox

- Download the [NixOS minimal ISO](https://nixos.org/download/) (x86_64-linux)
- Create a VM in Proxmox, attach the ISO, and boot it

### 2. Install NixOS

Boot into the ISO. Partition, format, and install:

```bash
# GPT + SeaBIOS requires a small BIOS boot partition for GRUB
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart BIOS 1MiB 2MiB       # /dev/sda1 - GRUB BIOS boot
parted /dev/sda -- set 1 bios_grub on
parted /dev/sda -- mkpart primary 2MiB 100%     # /dev/sda2 - root

# Format root partition
mkfs.ext4 -L nixos /dev/sda2

# Mount
mount /dev/disk/by-label/nixos /mnt

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

### 6. Set up the k3s token

The token must be placed manually at `/etc/k3s/token` on each node. All nodes must share the same token.

**On the server (nix-k3s-01) — first time only:**

```bash
sudo mkdir -p /etc/k3s
head -c 32 /dev/urandom | base64 | sudo tee /etc/k3s/token
sudo chmod 600 /etc/k3s/token
sudo systemctl restart k3s
```

Save the token value:

```bash
sudo cat /etc/k3s/token
```

**On each agent — copy the token from the server:**

```bash
sudo mkdir -p /etc/k3s
echo "<token-from-server>" | sudo tee /etc/k3s/token
sudo chmod 600 /etc/k3s/token
sudo systemctl restart k3s
```

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
- k3s token is managed manually (for now at least)
- traefik and servicelb are disabled; using caddy and metallb
