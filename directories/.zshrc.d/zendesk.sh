##########
## ZDI  ##
##########

# BEGIN ZDI
export DOCKER_FOR_MAC_ENABLED=true
if [[ -e "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh" ]]; then
  source "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh"
fi
# END ZDI


################
## Kubernetes ##
################

# source "${HOME}/Code/zendesk/kubectl_config/dotfiles/kubectl_stuff.bash"
if [[ -z "${KUBECONFIG}" ]] ; then
  export KUBECONFIG="${HOME}/.kube/config"
fi

function add_to_kubeconfig() {
  file="$1"
  if [[ -f "${file}" ]] && [[ "${KUBECONFIG}" != *"${file}"* ]]; then
    export KUBECONFIG="${KUBECONFIG}:${file}"
  fi
}
add_to_kubeconfig "${HOME}/.kube/kubeconfig_zendesk.yaml"

# Aliases
kcsudo() {
  user=${KCSUDO_USER:-admin}
  group=${KCSUDO_GROUP:-system:masters}

  kubectl_alias --as "${user}" --as-group "${group}" "$@"
}

alias kcx='kubectl_alias --context'
alias kcsudox='kcsudo --context'

for pod in 15 17 18 19 20 21 23 25 26 27 28 29 998 999; do
  eval "alias kc${pod}='kcx pod${pod}'"
  eval "alias kc${pod}ns='kcx pod${pod} --namespace'"
  eval "alias kc${pod}gpns='kcx pod${pod} get pods --namespace'"
  eval "alias kc${pod}dpns='kcx pod${pod} describe pods --namespace'"
  eval "alias kc${pod}gdns='kcx pod${pod} get deployment --namespace'"
  eval "alias kc${pod}ddns='kcx pod${pod} describe deployment --namespace'"
  eval "alias kc${pod}gsns='kcx pod${pod} get deployment --namespace'"
  eval "alias kc${pod}dsns='kcx pod${pod} describe deployment --namespace'"

  eval "alias kcsudo${pod}='kcsudox pod${pod}'"
done

##########
## RIC  ##
##########
ric() {
  command chruby-exec ruby -- command ric "$@"
}
