# bazzite-htpc-it87

A custom [Bazzite](https://bazzite.gg) HTPC image (`bazzite-deck`, Steam Gaming Mode) with
[frankcrawford's it87 driver](https://github.com/frankcrawford/it87). That driver replaces the
in-kernel `it87`, so fan and sensor support covers more ITE Super I/O chips.

Built from [ublue-os/image-template](https://github.com/ublue-os/image-template). GitHub
Actions rebuilds it every day, so it picks up both Bazzite updates and it87 updates.

## How it works

- A throwaway `it87-builder` stage starts from the same base image. It compiles `it87.ko`
  against the Bazzite `kernel-devel` that matches that exact kernel.
- The module goes in `/usr/lib/modules/<kver>/updates/`, which takes priority over the
  in-tree driver. If the in-tree one would still win, the build fails.
- `/usr/lib/modules-load.d/it87.conf` loads the driver at boot.
- Module options go in `/usr/lib/modprobe.d/it87.conf`. That file has commented examples
  such as `ignore_resource_conflict=1`. To override them on a machine, use
  `/etc/modprobe.d/it87.conf`.

## Changing the base or the driver version

Both are build args in the `Containerfile`:

| Arg          | Default                                | Notes                                                                           |
|--------------|----------------------------------------|---------------------------------------------------------------------------------|
| `BASE_IMAGE` | `ghcr.io/ublue-os/bazzite-deck:stable` | `bazzite-deck-nvidia`, `bazzite-deck-gnome`, `bazzite-deck-nvidia-gnome` also work |
| `IT87_REF`   | `master`                               | Any branch, tag or commit of frankcrawford/it87                                 |

## Secure Boot

With Secure Boot on, the kernel only loads signed modules. Ublue's key does not sign this
module, so you need your own key:

1. `just generate-kmod-key`. This creates `it87-mok.key` (private, git-ignored) and
   `certs/it87-mok.der` (public).
2. Commit `certs/it87-mok.der`.
3. Add the contents of `it87-mok.key` as a repository secret named `KMOD_SIGNING_KEY`.
   Then keep the key file somewhere safe outside the repo.
4. After switching to the image on the target machine, enroll the key. It asks for a
   one-time password, which you confirm in the blue MOK screen on the next reboot:

   ```bash
   sudo mokutil --import /usr/share/bazzite-htpc-it87/it87-mok.der
   ```

If the secret is not set, the build still succeeds but the module is unsigned. That only
works with Secure Boot off.

## Image signing (cosign)

The workflow signs the image with cosign. Follow the template's steps: run
`cosign generate-key-pair`, commit `cosign.pub`, and store `cosign.key` as the
`SIGNING_SECRET` repository secret.

## Switching the HTPC to this image

On the Bazzite machine:

```bash
sudo bootc switch ghcr.io/reckless5040/bazzite-htpc-it87:latest
systemctl reboot
```

## Checking it works

```bash
modinfo -n it87      # should point at .../updates/it87.ko.xz
modinfo it87 | grep -E '^(version|signer)'
sensors
```
