# Use Dash for viewing man pages if present
if [[ -x '/Applications/Dash.app/Contents/MacOS/Dash' ]]; then
  function man() {
    local query="$*"
    query="$(python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "${query}")"
    open "dash://man%3A${query}"
  }
fi
