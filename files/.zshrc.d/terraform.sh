alias tf='terraform'

# Load chtf if present
if [[ "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -f "${HOMEBREW_PREFIX}/share/chtf/chtf.sh" ]]; then
    source "${HOMEBREW_PREFIX}/share/chtf/chtf.sh"
  fi
fi
