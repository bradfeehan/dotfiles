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

#
# Set up Hub alias ("git" runs "hub")
#
if [[ -x '/usr/local/bin/hub' ]]; then
  eval "$(/usr/local/bin/hub alias -s)"
fi

# Sets up environment variables to use 99designs AWS credentials
function aws-99 {
  export AWS_CREDENTIAL_FILE="$HOME/.aws-credentials-99designs"
  export AWS_PRIVATE_KEY_NAME="bradfeehan"
  export AWS_PRIVATE_KEY="$HOME/.ssh/bradfeehan-99designs-ec2.pem"
}

# Sets up environment variables to use 99designs Logo Store AWS credentials
function aws-logo {
  export AWS_CREDENTIAL_FILE="$HOME/.aws-credentials-logo_store"
  export AWS_PRIVATE_KEY_NAME="bradfeehan"
  export AWS_PRIVATE_KEY="$HOME/.ssh/bradfeehan-99designs-ec2.pem"
}

# Shortcut for "git push --set-upstream origin CURRENT_BRANCH_NAME"
function gpu {
    local current_branch="$(git symbolic-ref --quiet --short HEAD)"

    if [[ -z $current_branch ]]; then
        echo "Can't determine current branch name (are you on a branch?)"
        return 1
    else
        git push --set-upstream origin "$current_branch"
    fi
}

# Git Branch Clean -- deletes branches that have been merged to master
alias gbC='git branch --merged master | grep -v "\* master" | xargs -n 1 git branch -d'

# added by travis gem
[ -f /Users/brad/.travis/travis.sh ] && source /Users/brad/.travis/travis.sh

# Short alias for `bundle exec`
alias be='bundle exec'
source ~/.common_env