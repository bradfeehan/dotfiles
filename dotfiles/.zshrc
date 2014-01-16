#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto
#
# https://github.com/sorin-ionescu/prezto
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Source Z
#
# https://github.com/rupa/z
if /usr/bin/which -s brew && [[ -h "$(brew --prefix)/etc/profile.d/z.sh" ]]; then
  source "$(brew --prefix)/etc/profile.d/z.sh"
fi
