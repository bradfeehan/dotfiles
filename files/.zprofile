##########################################
# Paths
##########################################

# Ensure $TMPDIR exists; if not, create it in the default location
if [[ ! -d "${TMPDIR}" ]]; then
  export TMPDIR="/tmp/${USER}"
  mkdir -p -m 700 "${TMPDIR}"
fi

# Set up $TMPPREFIX, used by Zsh for all temporary files
TMPPREFIX="${TMPDIR%/}/zsh"
if [[ ! -d "${TMPPREFIX}" ]]; then
  mkdir -p "${TMPPREFIX}"
fi

# Eliminate duplicates from path arrays
typeset -gU cdpath fpath mailpath path

# Add paths from desired applications
app_paths=(
  "${HOME}/Applications/Sublime Text.app/Contents/SharedSupport/bin"
  "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
  "${HOME}/Applications/Karabiner.app/Contents/Library/bin"
  "/Applications/Karabiner.app/Contents/Library/bin"
)

for app_path in "${app_paths[@]}"; do
  [[ -d "${app_path}" ]] && path=("${app_path}" "${path[@]}")
done

# Homebrew
if (( $+commands[brew] )); then
  if [[ -z "${BREW_PREFIX:-}" ]]; then
    # Guess BREW_PREFIX based on the default candidate locations
    for candidate in /usr/local /opt/local /home/linuxbrew/.linuxbrew; do
      [[ -d "${candidate}/Cellar" ]] && export BREW_PREFIX="${candidate}"
    done

    # If still unknown, run the slower, more reliable 'brew --prefix'
    [[ -z "${BREW_PREFIX:-}" ]] && export BREW_PREFIX="$(brew --prefix)"
  fi

  if [[ "${BREW_PREFIX:-}" && -d "${BREW_PREFIX:-}" ]]; then
    export path=(
      "${BREW_PREFIX}"/{,s}bin
      "${path[@]}"
    )

    # Add Homebrew's Zsh completions to $fpath
    if [[ -d "$BREW_PREFIX/share/zsh/site-functions" ]]; then
      fpath=(
        $fpath
        "$BREW_PREFIX/share/zsh/site-functions"
      )
    fi
  fi
fi


##########################################
# Configuration
##########################################

# Less
if (( $+commands[less] )); then
  # Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
  # Remove -X and -F (exit if the content fits on one screen) to enable it.
  export LESS='-F -M -R -S -X -z-4'
  export PAGER='less'

  # Set the Less input preprocessor.
  if (( $+commands[lesspipe.sh] )); then
    export LESSOPEN='| /usr/bin/env lesspipe.sh %s 2>&-'
  fi
fi

# Vim
(( $+commands[vim] )) && export EDITOR='vim' VISUAL='vim'

# Language
[[ -z "$LANG" ]] && export LANG='en_US.UTF-8'


##########################################
# Runtimes
##########################################

# Set up Go if present
if which go > /dev/null 2>&1; then
  export GOROOT="$(go env GOROOT)"
fi


##########################################
# OS-specific configuration
##########################################
case "${OSTYPE}" in
  darwin*)
    # Set default browser
    (( $+commands[open] )) && export BROWSER='open'


    ;;
esac
