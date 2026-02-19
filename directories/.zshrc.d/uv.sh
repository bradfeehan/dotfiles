if (( ${+commands[uv]} )); then
  eval "$(uv generate-shell-completion bash)"
fi
