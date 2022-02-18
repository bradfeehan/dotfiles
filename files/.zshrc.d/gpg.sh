# Set GNUPGHOME to its default value now to standardise its use in this script
GNUPGHOME="${HOME}/.gnupg"

# Use the GPG configuration provided by these dotfiles as a defaults
__DOTFILES_ZSHRC_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
__DOTFILES_DIR="$(cd -- "${__DOTFILES_ZSHRC_DIR}/../.." > /dev/null 2>&1; pwd -P)"
__DOTFILES_GPG_CONFIG="${__DOTFILES_DIR}/files/.gnupg/gpg.defaults.conf"

# The main config to use: the user/machine's local configuration
__GPG_CONFIG_LOCAL="${GNUPGHOME}/gpg.conf"

[[ -e "${__GPG_CONFIG_LOCAL}" ]] || touch "${__GPG_CONFIG_LOCAL}"

alias gpg="gpg --options '${__DOTFILES_GPG_CONFIG}' --options '${__GPG_CONFIG_LOCAL}'"

unset -v __DOTFILES_ZSHRC_DIR
unset -v __DOTFILES_DIR
unset -v __DOTFILES_GPG_CONFIG
unset -v __GPG_CONFIG_LOCAL
