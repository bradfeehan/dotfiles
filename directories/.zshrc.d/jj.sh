if (( ${+commands[jj]} )); then
    #compdef jj
    function _clap_dynamic_completer_jj() {
        local _CLAP_COMPLETE_INDEX=$(expr $CURRENT - 1)
        local _CLAP_IFS=$'\n'

        local completions=("${(@f)$( \
            _CLAP_IFS="$_CLAP_IFS" \
            _CLAP_COMPLETE_INDEX="$_CLAP_COMPLETE_INDEX" \
            COMPLETE="zsh" \
            jj -- "${words[@]}" 2>/dev/null \
        )}")

        if [[ -n $completions ]]; then
            _describe 'values' completions
        fi
    }

    compdef _clap_dynamic_completer_jj jj

    # Aliases
    alias jjst='jj status-log'
    alias jjl='jj log'
    alias jjla="jj log -r 'all()'"
    alias jjid='jj diff'
    alias jjd='jj diff'
    alias jjcm='jj commit -m'

    # single-j convenience aliases
    alias jst='jjst'
    alias jl='jjl'
    alias jla='jjla'
    alias jid='jjid'
    alias jd='jjd'
    alias jcm='jjcm'
fi
