#
# Executes commands at login pre-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

#
# Browser
#

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

#
# Editors
#

export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the the list of directories that cd searches.
# cdpath=(
#   $cdpath
# )

# Add Sublime Text's "subl" command to $path
for directory ({,$HOME}/Applications/Sublime\ Text.app/Contents/SharedSupport/bin); do
  if [[ -d "$directory" ]]; then
    path=(
      $directory
      $path
    )
  fi
done

# Add Karabiner's command-line interface to $path
for directory ({,$HOME}/Applications/Karabiner.app/Contents/Library/bin); do
  if [[ -d "$directory" ]]; then
    path=(
      $directory
      $path
    )
  fi
done

# Add Heroku toolbelt to $path
if [[ -d /usr/local/heroku/bin ]]; then
  path=(
    /usr/local/heroku/bin
    $path
  )
fi

# Add Homebrew's binary directories to $path
if which brew > /dev/null 2>&1; then
  export BREW_PREFIX="$(brew --prefix)"
  path=(
    $BREW_PREFIX/{bin,sbin}
    $path
  )

  # Add Homebrew's Zsh completions to $fpath
  if [[ -d "$BREW_PREFIX/share/zsh/site-functions" ]]; then
    fpath=(
      $fpath
      "$BREW_PREFIX/share/zsh/site-functions"
    )
  fi

  # Node version manager
  if [[ -d "$HOME/.nvm" && -e "$BREW_PREFIX/opt/nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
    nvm() {
      source "$BREW_PREFIX/opt/nvm/nvm.sh"
      nvm "$@"
    }
  fi
fi

# Set up Go if present
if which go > /dev/null 2>&1; then
  if [[ -z "$GOROOT" ]]; then
    export GOROOT="$(go env GOROOT)"
  fi

  if [[ -z "$GOPATH" ]]; then
    export GOPATH="$HOME/Projects/go"
  fi

  # Add GOROOT-based install location to $path
  path=(
    $GOROOT/bin
    $GOPATH/bin
    $path
  )
fi

# Set the list of directories that Zsh searches for programs.
path=(
  $HOME/.bin
  $path
  /usr/sbin
  /sbin
  ./node_modules/.bin
)

#
# Less
#

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -M -R -S -X -z-4'

# Set the Less input preprocessor.
if (( $+commands[lesspipe.sh] )); then
  export LESSOPEN='| /usr/bin/env lesspipe.sh %s 2>&-'
fi

#
# Temporary Files
#

if [[ ! -d "$TMPDIR" ]]; then
  export TMPDIR="/tmp/$USER"
  mkdir -p -m 700 "$TMPDIR"
fi

TMPPREFIX="${TMPDIR%/}/zsh"
if [[ ! -d "$TMPPREFIX" ]]; then
  mkdir -p "$TMPPREFIX"
fi

#
# Getflix DNS check
#
getflix_check() {
  dscacheutil -flushcache
  if curl --silent https://check.getflix.com.au | grep --quiet 'if (0) {'; then
    echo "Getflix DNS test failed!"
    return 1
  else
    echo "Getflix DNS test succeeded"
  fi
}
