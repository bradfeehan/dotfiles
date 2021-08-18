# Only sourced by interactive shells
source "${ZDOTDIR:-${HOME}}/.zinit/bin/zinit.zsh"
source "${ZDOTDIR:-${HOME}}/.zinitrc"

if [[ -d "${ZDOTDIR:-${HOME}}/.aliases.d" ]]; then
  for file in "${ZDOTDIR:-${HOME}}/.aliases.d"/*; do
    source "${file}"
  done
fi

# Do not overwrite existing files with > and >>. Use >! and >>! to bypass.
unsetopt CLOBBER

# Grep colours configuration
export GREP_COLOR=${GREP_COLOR:-'37;45'}            # BSD.
export GREP_COLORS=${GREP_COLORS:-"mt=$GREP_COLOR"} # GNU.

# Use Dash for viewing man pages if present
if [[ -x '/Applications/Dash.app/Contents/MacOS/Dash' ]]; then
  function man() {
    open "dash://man:$*"
  }
fi

# RubyMine
if [[ -x '/Applications/RubyMine.app/Contents/MacOS/rubymine' ]]; then
  alias mine='/Applications/RubyMine.app/Contents/MacOS/rubymine'
fi

# Pyenv
if [[ -x '/usr/local/bin/pyenv' ]]; then
  function pyenv {
    LANG=C /usr/local/bin/pyenv "$@"
  }
fi

# chnode
if [[ -f /usr/local/share/chnode/chnode.sh ]]; then
  source /usr/local/share/chnode/chnode.sh

  if [[ -f /usr/local/share/chnode/auto.sh ]]; then
    source /usr/local/share/chnode/auto.sh
    precmd_functions+=(chnode_auto)
  fi
fi

# node-build
if which node-build > /dev/null 2>&1; then
  node-install() {
    if [[ $# -gt 1 ]]; then
      echo >&2 "Error: node-install requires zero or one arguments"
      return
    elif [[ $# -eq 0 ]]; then
      node-build --definitions
      return
    fi

    local definition="$1"
    node-build "${definition}" "${HOME}/.nodes/${definition}"
  }
fi

# Set up Hub alias ("git" runs "hub")
if [[ -x '/usr/local/bin/hub' ]]; then
  function git {
    /usr/local/bin/hub "$@"
  }
fi

# General-purpose command-line aliases
alias be='bundle exec'
alias fig='docker-compose'
alias tf='terraform'
alias sv='supervisorctl'
alias av='aws-vault-exec-wrapper aws-vault'
alias avws='av aws'
alias avtf='av terraform'
alias ao='aws-vault-exec-wrapper aws-okta'
alias zaws='ao aws'
alias zsm='ao "bundle exec stack_master"'

# BEGIN ZDI
export DOCKER_FOR_MAC_ENABLED=true
if [[ -s "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh" ]]; then
  source "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh"
fi
# END ZDI
