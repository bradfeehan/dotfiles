if (( ${+commands[cursor]} )); then
  alias code=cursor
elif ! (( ${+commands[code]} )) && [[ -x '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code' ]]; then
  alias code="'/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'"
fi
