#!/bin/bash
set -euo pipefail

DISK=/dev/sda
PART_BOOT="${DISK}1"
PART_SWAP="${DISK}2"
PART_ROOT="${DISK}3"

echo "=== Partitioning ${DISK} ==="
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart primary 1MiB 512MiB
parted -s "${DISK}" mkpart primary 512MiB 2560MiB
parted -s "${DISK}" mkpart primary 2560MiB 100%
parted -s "${DISK}" set 1 boot on

echo "=== Formatting ==="
mkfs.ext4 -L nixos "${PART_ROOT}"
mkswap -L swap "${PART_SWAP}"
mkfs.fat -F 32 -n boot "${PART_BOOT}"

echo "=== Mounting ==="
mount "${PART_ROOT}" /mnt
mkdir -p /mnt/boot
mount "${PART_BOOT}" /mnt/boot
swapon "${PART_SWAP}"

echo "=== Generating hardware config ==="
nixos-generate-config --root /mnt

echo "=== Copying custom configuration ==="
cp /tmp/configuration.nix /mnt/etc/nixos/configuration.nix

echo "=== Installing NixOS ==="
export NIX_PATH="nixpkgs=https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-24.11/nixexprs.tar.xz"
nixos-install --root /mnt --no-root-passwd -I "nixpkgs=https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-24.11/nixexprs.tar.xz"

echo "=== Rebooting ==="
reboot
