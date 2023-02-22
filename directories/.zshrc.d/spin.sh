if [[ "${SPIN:-}" ]]; then
  # source '/etc/zsh/zshrc.default.inc.zsh'
  alias sc=systemctl
  alias jc=journalctl
  alias failed="/usr/bin/systemctl list-units --failed"

  # Simplifies tailing multiple services simultaneously
  # `jctail a b c` is the same as running
  # `journalctl --quiet --follow __SYSTEMD_UNIT=a + _SYSTEMD_UNIT=b + _SYSTEMD_UNIT=c`
  jctail() {
    local services=()
    for service in "$@"; do
      if [[ "${services[*]}" ]]; then
        services+=('+')
      fi
      services+=("_SYSTEMD_UNIT=${service}")
    done

    journalctl --quiet --follow "${services[@]}"
  }

  __spin_warned_failures=0
  __spin_warn_failed_first_run=1
  warn_failed_units() {
    if [[ -v SPIN_DISABLE_FAILED_UNITS_WARNING ]]; then
      return
    fi

    nfailed="$(systemctl show | grep -Po "(?<=^NFailedUnits=)(\d+)$")"
    new_failures=$((nfailed - __spin_warned_failures))
    if [[ "${new_failures}" -gt 0 ]]; then
      units=units
      have=have
      if [[ "${new_failures}" -eq 1 ]]; then
        units=unit
        have=has
      fi
      if [[ -v __spin_warn_failed_first_run ]]; then
        >&2 echo "\x1b[1;31m꩜  ${new_failures} ${units} ${have} failed. Run \x1b[1;34mman spin.failed-unit\x1b[1;31m for help.\x1b[0m"
      else
        >&2 echo "\x1b[1;31m꩜  ${new_failures} new failed ${units} (${nfailed} total). Run \x1b[1;34mman spin.failed-unit\x1b[1;31m for help.\x1b[0m"
      fi
    fi
    __spin_warned_failures="${nfailed}"
    unset __spin_warn_failed_first_run
  }

  __spin_previous_state=
  __spin_notify_system_state_first_run=1
  notify_system_state() {
    local state
    state="$(systemctl show -PSystemState)"
    case "${state}" in
      initializing|starting)                 state_color="\033[1;33m" ;;
      degraded|stopping|maintenance|offline) state_color="\033[1;31m" ;;
      running|unknown|*)                     state_color="\033[38;5;33m" ;;
    esac
    if [[ "${state}" != "${__spin_previous_state}" ]]; then
      if [[ -v __spin_notify_system_state_first_run ]]; then
        case "${state}" in
          running) ;;
          # we will have just printed about the failed unit, so
          # it won't surprise anyone to find out that the system
          # is degraded.
          degraded) ;;
          starting)
            >&2 echo "${state_color}꩜  \x1b[0msystem is still ${state_color}initializing\x1b[0m (See \033[1;94msystemctl\x1b[0m)"
            ;;
          *)
            >&2 echo "${state_color}꩜  \x1b[0msystem is in state: ${state_color}${state}\x1b[0m"
            ;;
        esac
      else
        case "${state}" in
          running)
            >&2 echo "${state_color}꩜ \x1b[0m system is up and ${state_color}${state}\x1b[0m"
            ;;
          degraded)
            # TODO: make a `help degraded`
            >&2 echo "${state_color}꩜ \x1b[0m system state changed to ${state_color}${state}\x1b[0m (\x1b[1;94mman spin\x1b[0m for guidance)"
            ;;
          *)
            >&2 echo "${state_color}꩜ \x1b[0m system state changed to ${state_color}${state}\x1b[0m"
            ;;
        esac
      fi
    fi
    __spin_previous_state="${state}"
    unset __spin_notify_system_state_first_run
  }

  precmd_functions+=(warn_failed_units notify_system_state)
fi
