if (( ! ${+commands[playwright-cli]} )); then
  if (( ${+commands[pnpm]} )); then
    alias playwright-cli='pnpm dlx --package @playwright/cli@latest -- playwright-cli'
  elif (( ${+commands[npm]} )); then
    alias playwright-cli='npm exec --package=@playwright/cli@latest -- playwright-cli'
  fi
fi
