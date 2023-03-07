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

# added to ~/.zshrc by `dev up` in Shopify/cloudplatform
if [[ -e "${HOME}/.kube/config.shopify.cloudplatform" ]]; then
  export KUBECONFIG="${KUBECONFIG:+$KUBECONFIG:}${HOME}/.kube/config:${HOME}/.kube/config.shopify.cloudplatform"
fi

if [[ -d "${HOME}/src/github.com/Shopify/cloudplatform/workflow-utils" ]]; then
  for file in "${HOME}/src/github.com/Shopify/cloudplatform/workflow-utils"/*.bash; do
    source "${file}"
  done

  kubectl-short-aliases
fi
