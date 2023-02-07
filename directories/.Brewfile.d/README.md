`.Brewfile.d`
==============

Link a machine-specific configuration into place:

```shell
# On a MacBook:
SERIAL="$( \
    ioreg -c IOPlatformExpertDevice -d 2 \
    | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}' \
)"
ln -sfv \
    "bradfeehan@MacBook.${SERIAL}.Brewfile" \
    "${HOME}/.Brewfile.d/local.Brewfile"

# On a Linux machine:
DISTRO="$(source /etc/os-release; printf '%s' "${ID}")"
ln -sfv \
    "bradfeehan@${DISTRO}.Brewfile" \
    "${HOME}/.Brewfile.d/local.Brewfile"
```
