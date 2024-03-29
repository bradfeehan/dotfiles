if (( ${+commands[fasd]} )); then
  # function to execute built-in cd
  fasd_cd() {
    if [ $# -le 1 ]; then
      fasd "$@"
    else
      local _fasd_ret="$(fasd -e 'printf %s' "$@")"
      [ -z "$_fasd_ret" ] && return
      [ -d "$_fasd_ret" ] && cd "$_fasd_ret" || printf %s\n "$_fasd_ret"
    fi
  }
  alias j='fasd_cd -d -i'
  _fasd_preexec() {
    { eval "fasd --proc $(fasd --sanitize $2)"; } >> "/dev/null" 2>&1
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _fasd_preexec
fi