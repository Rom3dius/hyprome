# Hyprome &nbsp; [![hyprome build badge](https://github.com/rom3dius/hyprome/actions/workflows/build.yml/badge.svg)](https://github.com/rom3dius/hyprome/actions/workflows/build.yml)

Custom Fedora atomic operating system for my personal usage.
Any PRs, suggestions etc. are welcome.
Uses hyprland, shell drops you into a distrobox container by default.

## Notes

On first start it clones some dots, which breaks hyprland. Wait a few seconds, reboot and you'll be good to go.

### Local Testing

If you want to build and rebase locally:

```bash
bluebuild build -B podman recipes/recipe.yml
podman save --format oci-archive -o /var/tmp/hyprome.tar localhost/hyprome:latest
sudo rpm-ostree rebase ostree-unverified-image:oci-archive:/var/tmp/hyprome.tar
```

If there's issues, once you're back in the old system:

```bash
rpm-ostree rollback
rpm-ostree cleanup -p
```

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/blue-build/template
```
