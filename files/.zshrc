#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -e "${ZDOTDIR:-$HOME}/.p10k.zsh" ]]; then
  source ~/.p10k.zsh
fi

# Source Prezto
#
# https://github.com/sorin-ionescu/prezto
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Use Dash for viewing man pages if present
if [[ -x '/Applications/Dash.app/Contents/MacOS/Dash' ]]; then
  man() {
    open "dash://man:$*"
  }
fi

# RubyMine
if [[ -x '/Applications/RubyMine.app/Contents/MacOS/rubymine' ]]; then
  alias mine='/Applications/RubyMine.app/Contents/MacOS/rubymine'
fi

# Kubernetes aliases
if [[ -x '/usr/local/bin/kubectl' && -f "${HOME}/.kubectl_aliases" ]]; then
  source "${HOME}/.kubectl_aliases"

  # Print expanded command before running it
  function kubectl() {
    printf '=> kubectl'
    [[ $# -gt 0 ]] && printf ' %q' "$@"
    printf '\n'
    command kubectl "$@"
  }

  # Extra aliases
  alias kgp=kgpo
fi

#
# Set up Hub alias ("git" runs "hub")
#
if [[ -x '/usr/local/bin/hub' ]]; then
  function git {
    /usr/local/bin/hub "$@"
  }
fi

# Shortcut for "git push --set-upstream origin CURRENT_BRANCH_NAME"
function gpu {
    local current_branch="$(git symbolic-ref --quiet --short HEAD)"

    if [[ -z $current_branch ]]; then
        echo "Can't determine current branch name (are you on a branch?)"
        return 1
    else
        git push "$@" --set-upstream origin "$current_branch"
    fi
}

# Shortcut for "git pull-request"
alias gpr='git pull-request'

# Git Branch Clean -- deletes branches that have been merged to master
alias gbC='git branch --merged master | grep -v "[* ] master" | xargs -n 1 git branch -d'

# Git Fetch Rebase + Clean -- fetches with rebase, then cleans branches
alias gfrC='gfr -p && gbC'

# Git Log Graph -- shows a nice overview of history for the repository
if [ -n "${_git_log_oneline_format}" ]; then
  alias glg='git log --first-parent --topo-order --glob=heads --graph --pretty=format:${_git_log_oneline_format}'
  alias glga='glg --all'
  alias glgb='git log --first-parent --topo-order --graph --pretty=format:${_git_log_oneline_format} origin/HEAD..HEAD'
  alias glgd='glg --date-order'
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

# GPG agent
export GPG_TTY="$(tty)"
