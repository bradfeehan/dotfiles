# Grep
alias grep="${aliases[grep]:-grep} --color=auto"
export GREP_COLOR=${GREP_COLOR:-'37;45'}            # BSD.
export GREP_COLORS=${GREP_COLORS:-"mt=$GREP_COLOR"} # GNU.

# Diff
diff() {
  if (( $+commands[colordiff] )); then
    command diff "$@" | colordiff
  else
    command diff "$@"
  fi
}
