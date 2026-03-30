# nix infra

NixOS-based k3s cluster running on Proxmox, managed as a Nix flake.

## Hosts

| Host | Role | Network |
|------|------|---------|
| `nix-pi-01` | main services, HA | VLAN 2 (backend) | # planned
| `nix-pi-02` | main services, HA | VLAN 2 (backend) | # planned
| `nix-k3s-01` | k3s server | VLAN 2 (backend), VLAN 3 (vpn1), VLAN 4 (vpn2) |
| `nix-k3s-02-gpu` | k3s agent (Intel Arc GPU) | VLAN 2 (backend) |

## Structure

```
flake.nix
secrets/
  secrets.local
nix/
  hosts/
    nix-k3s-01/
      configuration.nix       # specific config
      hardware-configuration.nix
    nix-k3s-02-gpu/
      configuration.nix
      hardware-configuration.nix
  modules/
    caddy.nix
    common.nix    # shared config
    forgejo.nix
    k3s.nix
    nfs.nix
    vlans.nix
```

## Deploying a host

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Setting up a new VM

### 1. Create the VM in Proxmox

- NixOS minimal ISO
- **q35 machine type** and **UEFI (OVMF)** BIOS + TPM

### 2. Install NixOS

```bash
# format

parted /dev/sda -- mklabel gpt \
&& parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB \
&& parted /dev/sda -- set 1 esp on \
&& parted /dev/sda -- mkpart primary 512MiB 100% \
&& mkfs.fat -F 32 -n boot /dev/sda1 \
&& mkfs.ext4 -L nixos /dev/sda2

# mount

mount /dev/disk/by-label/nixos /mnt \
&& mkdir -p /mnt/boot \
&& mount /dev/disk/by-label/boot /mnt/boot

# generate config

nixos-generate-config --root /mnt

# add ssh

nano /mnt/etc/nixos/configuration.nix
```

```

users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" ];
};

```

```bash
# reload config

sudo nixos-rebuild switch

# change password

passwrd admin

# install

nixos-install
reboot
```

### 3. copy hardware config


```bash
nixos-generate-config --show-hardware-config
```

put into `nix/hosts/<hostname>/hardware-configuration.nix`.


### 4. Set up secrets

#### mkdir

```bash
sudo mkdir -p /etc/secrets
sudo chmod 700 /etc/secrets
```

#### one for each

```bash
echo -n "<secret>" | sudo tee /etc/secrets/[secret] > /dev/null
sudo chmod 600 /etc/secrets/*
```
\<secret> = secret value

\[secret] = secret name

### 5. Deploy

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Adding a service module

### 1. Create the module

new file in `nix/modules/`

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.myservice;
in
{
  options.myservice = {
    enable = lib.mkEnableOption "my service";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for the service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.someService.enable = true;

    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}
```

- **`options`** declares configurable knobs with types and defaults and whatnot
- **`config`** wraps the actual system configuration in `lib.mkIf cfg.enable` so it only applies when the module is turned on
- inside `config` set upstream NixOS options 
- everything else: [search.nixos.org/options](https://search.nixos.org/options))

### 2. Register module

Add the module to `modules` list:

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
- only foir the host where its needed

### 3. Enable it in the host config

In `nix/hosts/<hostname>/configuration.nix`, set the options you defined:

```nix
myservice = {
  enable = true;
  domain = "myservice.example.com";
};
```

### 4. Expose it through Caddy

only if web interface

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

### 5. Deploy

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

## Adding an NFS mount

### 1. Register

`./nix/modules/nfs.nix` needs to be in the specific `modules` list in `flake.nix`

### 2. mount in host config

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

for more mounts, add more entries under `mounts` like thsi:

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

### 3. Deploy again

```bash
sudo nixos-rebuild switch --flake github:stolpela/infra#<hostname> --no-write-lock-file
```

permissions are managed server side, make sure to add the groups to whatever user

## Updating the flake lock

updated flake.lock

```bash
nix flake update
```
- only on mac
- whenever something changes, sometimes it doesn't change, better safe than sorry

## Todo

- more nfs mounts
- secrets (sops and agenix were a PITA)
- k3s stuff (different repo?)
- pi for services
