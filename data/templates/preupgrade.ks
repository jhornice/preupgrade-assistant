#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'

# Halt after installation
halt
# System timezone
timezone Etc/UTC
# System language
lang en_US
# System authorization information
auth  --useshadow  --passalgo=sha512
# enable firstboot
firstboot --enable
# SELinux configuration
selinux --enforcing

# configure your networking properly
network --onboot yes --device eth0 --bootproto dhcp

# set root's password
rootpw changethis

# configure firewall
firewall --service=ssh

# System bootloader configuration
bootloader --location=mbr --driveorder=sda --append="rhgb quiet"
# I am deleting the old partitions with this
clearpart --all --drives=sda
# partition storage automatically
autopart

%post
%end

%packages
%end

