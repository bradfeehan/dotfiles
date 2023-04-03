# Only sourced by interactive shells

# TODO
#  - setting terminal window/tab title
#  - dircolors(1) / LSCOLOR

# Do not overwrite existing files with > and >>. Use >! and >>! to bypass.
unsetopt CLOBBER

# Exclude commands from history by prepending a space
setopt HIST_IGNORE_SPACE

# Use colour
export CLICOLOR=1

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


#
# Load plugins and scripts
#

source_compiled() {
  local file="${1%.zwc}"

  # If there is no *.zsh.zwc or it's older than *.zsh, compile *.zsh into *.zsh.zwc.
  if [[ ! "${file}".zwc -nt "${file}" ]]; then
    : zcompile "${file}"
  fi

  source "${file}"
}

# Load plugins from submodules
zshrc_path="$(readlink "${HOME}/.zshrc")"
repo_root="$(cd "${zshrc_path%/*}/.." > /dev/null 2>&1 && pwd -P)"

source_compiled "${repo_root}/submodules/romkatv/powerlevel10k/powerlevel10k.zsh-theme"
source_compiled "${repo_root}/submodules/zsh-users/zsh-completions/zsh-completions.plugin.zsh"
autoload compinit
compinit
source_compiled "${repo_root}/submodules/Aloxaf/fzf-tab/fzf-tab.plugin.zsh" # after compinit; before f-sy-h + autosuggestions
source_compiled "${repo_root}/submodules/zdharma/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" # after compinit
source_compiled "${repo_root}/submodules/zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh" # after compinit

# Load files within zshrc.d
if [[ -d "${ZDOTDIR:-${HOME}}/.zshrc.d" ]]; then
  for file in "${ZDOTDIR:-${HOME}}/.zshrc.d"/*; do
    source_compiled "${file}"
  done
fi

unset repo_root zshrc_path

# dev will add these lines, but they're already taken care of in faster ways
if false; then
  [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
fi

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
