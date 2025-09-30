# Set of aliases/helpers for SYSTEMCTL(1).

if (( ${+commands[systemctl]} )); then
    alias sc='sudo systemctl'
    alias jc='sudo journalctl'

    _systemctl_fzf_list() {
        local mode="$1"
        local states="${2:-}"

        if ! ((${+commands[systemctl]})); then
            printf '%s\n' 'myservice'
            return 1
        fi

        cat \
            <(echo 'UNIT/FILE LOAD/STATE ACTIVE/PRESET SUB DESCRIPTION') \
            <(systemctl "${mode}" list-units --legend=false ${states}) \
            <(systemctl "${mode}" list-unit-files --legend=false ${states}) \
        | sed 's/●/ /' \
        | grep . \
        | column --table --table-columns-limit=5 \
        | fzf --header-lines=1 \
            --accept-nth=1 \
            --no-hscroll \
            --preview="SYSTEMD_COLORS=1 systemctl '${mode}' status {1}" \
            --preview-window=down
    }

    # Aliases for unit selector.
    alias scls='_systemctl_fzf_list --system'
    alias jcf='sudo journalctl --unit "$(scls)" --all --follow'

    _systemctl_exec() {
        local args=("$@")
        local service_name="${args[-1]}"
        local cmd="sudo systemctl ${args[*]} && sc status '${service_name}' || jc -xeu '${service_name}'"
        print -S "${cmd}"

        eval "${cmd}"

        printf '%s ' '>' >&2
        printf '"%s" ' >&2 ${cmd}
    }

    alias sstart='_systemctl_exec --system start "$(scls static,disabled,failed)"'
    alias sstop='_systemctl_exec --system stop "$(scls running,failed)"'
    alias srestart='_systemctl_exec --system restart "$(scls)"'
    alias sre='srestart'
fi
