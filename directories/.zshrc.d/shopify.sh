if [[ -f '/opt/dev/sh/chruby/chruby.sh' ]]; then
  if ! type chruby > /dev/null 2>&1; then
    chruby () {
      source /opt/dev/sh/chruby/chruby.sh
      chruby "$@"
    }
  fi
fi

if [[ -f '/opt/dev/dev.sh' ]]; then
  source /opt/dev/dev.sh
fi
