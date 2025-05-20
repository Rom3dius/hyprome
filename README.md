# Hyprome

Custom Fedora atomic operating system for my personal usage.
Any PRs, suggestions etc. are welcome.
Uses hyprland, shell drops you into a distrobox container by default.

## Notes

On first start it clones some dots, which breaks hyprland. Wait a few seconds, reboot and you'll be good to go.

To use nvidia drivers:

```bash
rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia
rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia-cuda
rpm-ostree kargs --append=rd.driver.blacklist=nouveau --append=modprobe.blacklist=nouveau --append=nvidia-drm.modeset=1
```

Might need to add fusion repos.

```bash
rpm-ostree install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

Goal is to add this as a separate image (hyprome-nvidia) to rebase off of, but haven't gotten it working yet.
