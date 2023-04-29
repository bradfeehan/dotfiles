# Use Dash for viewing man pages if present
if [[ -x '/Applications/Dash.app/Contents/MacOS/Dash' ]]; then
  function man() {
    local query="$*" python='' uri=''

    # Find python if present
    if (( $+commands[python3] )); then
      python='python3'
    elif (( $+commands[python2] )); then
      python='python2'
    elif (( $+commands[python] )); then
      python='python'
    fi

    # Create url-quoted string to pass to Dash
    if [[ "${python}" == 'python3' ]]; then
      uri="dash://man%3A$("${python}" -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${query}")"
    elif [[ "${python}" ]]; then
      uri="dash://man%3A$("${python}" -c "import urllib, sys; print urllib.quote(sys.argv[1])" "${query}")"
    fi

    # Open dash if the URI was generated
    if [[ "${uri}" ]]; then
      open "${uri}"
    else
      command man "${query}"
    fi
  }
fi
