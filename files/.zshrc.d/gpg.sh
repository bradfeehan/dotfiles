# Set GNUPGHOME to its default value now to standardise its use in this script
GNUPGHOME="${HOME}/.gnupg"

# Determine directories
__DOTFILES_GPG_SOURCE="$0"
while [[ -h "${__DOTFILES_GPG_SOURCE}" ]]; do
  __DOTFILES_ZSHRC_DIR="$(cd -P -- "$(dirname "${__DOTFILES_GPG_SOURCE}")" > /dev/null 2>&1 && pwd -P)"
  __DOTFILES_GPG_SOURCE="$(readlink "${__DOTFILES_GPG_SOURCE}")"
  [[ $__DOTFILES_GPG_SOURCE != /* ]] && __DOTFILES_GPG_SOURCE="${__DOTFILES_ZSHRC_DIR}/${__DOTFILES_GPG_SOURCE}"
done
__DOTFILES_ZSHRC_DIR="$(cd -P -- "$(dirname "${__DOTFILES_GPG_SOURCE}")" > /dev/null 2>&1 && pwd -P)"
unset -v __DOTFILES_GPG_SOURCE

# Use the GPG configuration provided by these dotfiles as a defaults
export __DOTFILES_DIR="$(cd -- "${__DOTFILES_ZSHRC_DIR}/../.." > /dev/null 2>&1; pwd -P)"
export __DOTFILES_GPG_CONFIG="${__DOTFILES_DIR}/files/.gnupg/gpg.defaults.conf"

if [[ -e "${__DOTFILES_GPG_CONFIG}" ]]; then
  # The main config to use: the user/machine's local configuration
  __GPG_CONFIG_LOCAL="${GNUPGHOME}/gpg.conf"
  [[ -e "${__GPG_CONFIG_LOCAL}" ]] || touch "${__GPG_CONFIG_LOCAL}"
  alias gpg="gpg --options '${__DOTFILES_GPG_CONFIG}' --options '${__GPG_CONFIG_LOCAL}'"
fi

unset -v __DOTFILES_ZSHRC_DIR
unset -v __DOTFILES_DIR
unset -v __DOTFILES_GPG_CONFIG
unset -v __GPG_CONFIG_LOCAL
