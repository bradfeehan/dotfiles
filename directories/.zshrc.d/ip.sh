# Shows the device's IP address
#
#   ip public -- public IP on the internet
#   ip local  -- local IP on the local network
#
# Running with no argument defaults to `ip public`.
ip() {
  local mode="${1:-}"

  if [[ -z "${mode}" ]]; then
    mode='public'
  fi

  case "${mode}" in
    local)
      {
        ifconfig \
        | grep -E '^(e|[[:space:]]*(media|inet ))' \
        | grep -vE '(127\.0\.0\.1|media: (none|autoselect$|<unknown type>))' \
        ; \
        echo; \
      } \
      | sed -En 'N; s/^[[:space:]]*inet ([0-9\.]*).*\n([[:space:]]*media(: .*)|.*)/\1\3/p'
      ;;
    public)
      curl --silent http://whatismyip.akamai.com ; \
      echo ; \
      ;;
    *)
      printf '%s\n' >&2 \
        "Usage: $0 <local|public>"
      return 1
      ;;
  esac
}
