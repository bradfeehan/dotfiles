if ! (( ${+functions[z]} )); then
  if (( ${+commands[zoxide]} )); then
    eval "$(zoxide init zsh)"
  fi
fi
if ! (( ${+functions[j]} )); then
  alias j=z
fi
