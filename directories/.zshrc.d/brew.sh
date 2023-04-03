brew () {
  local subcommand="$1"
  shift

  case "${subcommand}" in
    find)
      HOMEBREW_NO_COLOR=1 HOMEBREW_COLOR='' command brew search "$@" \
        | sed '/^$/d' \
        | xargs env HOMEBREW_NO_COLOR='' HOMEBREW_COLOR=1 brew desc --eval-all \
        | sed 's/://;s/ / -- /' \
        | fzf --ansi \
                --preview "env HOMEBREW_NO_COLOR='' HOMEBREW_COLOR=1 brew info {1}" \
                --preview-label='brew info' \
        | cut -d' ' -f1 \
        | xargs command brew install
      ;;
    *)
      command brew "${subcommand}" "$@"
      ;;
  esac
}
