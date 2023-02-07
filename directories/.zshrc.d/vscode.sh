if ! (( ${+commands[code]} )); then
  if [[ -x '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code' ]]; then
    alias code="'/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'"
  fi
fi
