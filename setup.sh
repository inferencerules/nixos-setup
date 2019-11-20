#!/bin/bash

################################################################################
#           This script performs a full setup of NixOS on a                    #
#           6th-generation (2018) Lenovo ThinkPad X1 Carbon                    #
#                                                                              #
#                   Run this as root, or using sudo                            #
################################################################################

################################################################################
# Connect to wifi
################################################################################

# Print out a list of the network interfaces
ip a 

# Query user for wifi use
read -p "Enter the name of the wireless interface: " interface

# Kill any wpa_supplicant currently running
pkill -9 wpa_supplicant

# Get the wireless SSID and password
read -p "Enter the wireless SSID: " ssid
read -p "Enter the wireless password: " pass

# Connect to wifi
wpa_supplicant -B -i $interface -c <(wpa_passphrase $ssid $pass)



################################################################################
# Install git and grab the required config files
################################################################################

# Install git
nix-env -i git

# Clone the nixos-setup repository
git clone https://github.com/inferencerules/nixos-setup


# Clone the nixos-configs repository
git clone https://github.com/inferencerules/nixos-configs



################################################################################
# Format the disk
################################################################################

# Wipe the partition table information on the disk
sgdisk --clear /dev/nvme0n1

# Create the EFI system partition
sgdisk --new=0:0:+1G /dev/nvme0n1

# Create the root partition
sgdisk --new=0:0:0 /dev/nvme0n1



################################################################################
# Encrypt and unlock the root physical partition
################################################################################

# Set up encryption
cryptsetup luksFormat /dev/nvme0n1p2 # this will ask for a password

# Open the partition
cryptsetup luksOpen /dev/nvme0n1p2 enc-pv # mounts to /dev/mapper/enc-pv



################################################################################
# Set up LVM
################################################################################

# Create the physical volume
pvcreate /dev/mapper/enc-pv

# Create a volume group
vgcreate vg /dev/mapper/enc-pv

# Create the swap and root logical volumes
lvcreate -n swap vg -L 16G # 16GB for swap to match the RAM available
lvcreate -n root vg -l 100%FREE # use the rest of the disk for the logical root


################################################################################
# Set up filesystems
################################################################################

# Format the EFI system partition
mkfs.vfat -F32 /dev/nvme0n1p1

# Format root partition EXT4
mkfs.ext4 /dev/mapper/vg-root

# Format swap
mkswap /dev/mapper/vg-swap

# Turn swap on
swapon /dev/mapper/vg-swap



################################################################################
# Mount the filesystems
################################################################################

# Mount the logical root to /mnt
mount /dev/mapper/vg-root /mnt

# Make a mount point for the ESP
mkdir /mnt/boot

# Mount the ESP
mount /dev/nvme0n1p1 /mnt/boot



################################################################################
# Generate the default NixOS and hardware configs
################################################################################

nixos-generate-config --root /mnt



################################################################################
# Move the personal configs into the appropriate directory
################################################################################

# Copy everything in the nixos-configs directory to /mnt/etc/nixos
cp nixos-configs/* /mnt/etc/nixos



################################################################################
# Finally, install NixOS using the preferred configurations
################################################################################

nixos-install
