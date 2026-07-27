# private/work zsh drop-in.
# applied to ~/.config/zsh/internal.zsh by the work profile and sourced
# automatically by the base ~/.zshrc.

# proxy used by 'external' Dockerfiles
export ALPINE_PROXY="https://binrepo.target.com/artifactory/alpine-remote/v3.19"

# go proxy and checksum database
export GOPROXY="https://binrepo.target.com/artifactory/golang-remote,https://binrepo.target.com/artifactory/api/go/go-virtual"
export GONOSUMDB="git.target.com,github.com/target-corp"

# ssl certificate bundle
export NODE_EXTRA_CA_CERTS="${HOME}/tgt-ca-bundle.crt"
export SSL_CERT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/target/certs/"
export SSL_CERT_FILE="${SSL_CERT_DIR}tgt-ca-bundle.crt"
export TGT_CA_BUNDLE="${SSL_CERT_FILE}"
export PIP_CERT="${SSL_CERT_FILE}"
export REQUESTS_CA_BUNDLE="${SSL_CERT_FILE}"
alias tgt_cert_refresh="curl http://certs.target.com/pki/tgt-ca-bundle.crt --create-dirs --output \${SSL_CERT_FILE}"

# vault
export VAULT_ADDR=https://prod.vault.target.com:443

# dayton
export PATH="$PATH:$HOME/.local/bin"
export PATH="$HOME/.config/dayton/bin:$PATH"

# directory navigation
alias cdi='cdd; cd git.target.com'
alias cdt='cdd; cd git.target.com'
alias cdj='cdd; cd git.target.com; cd jenkins'
alias cdgv='cde; cd go-vela'
alias cdui='cdgv; cd ui'
alias cdhv='cdi; cd davidvader; cd heyvela;'
alias cdghmui='cdi; cd github; cd migration-ui'
alias cdmtf='cdi; cd davidvader/motif;'

# kubectl
alias kvgp='kubectl -n vela get pods'
alias kvlw='kubectl -n vela logs deployment/worker'
alias kvaw='kubectl -n vela apply -f ./worker/.'

# vl: vault login using ldap, sets VAULT_TOKEN to the result
vl() {
  echo "running vault login --method=ldap and setting output to VAULT_TOKEN"
  export VAULT_TOKEN=""
  export VAULT_TOKEN=$(vault login --method=ldap | grep 'token                  s.' | awk '{ print $2 }')
  if [ "$VAULT_TOKEN" = "" ]; then
    echo "error running vault login. no VAULT_TOKEN set."
    return
  fi
  echo "set VAULT_TOKEN to $VAULT_TOKEN"
}

# vw_metrics: open the worker metrics dashboard for a completed build
# usage: vw_metrics <org> <repo> <build-number>
vw_metrics() {
  dashboard_path="d/JCVjfY1Zz/vela-workers?orgId=5"
  host_key="vela_host"
  version_key="vela_version"
  version_value="0.26-prod"

  org=$1
  repo=$2
  number=$3

  build=$(vela --color false view build --org $org --repo $repo --number $number --output json)
  echo $build
  host_value=$(echo $build | jq -r '.host')
  created=$(echo $build | jq -r '.created')
  finished=$(echo $build | jq -r '.finished')

  from="$(($created-60))000"
  to="$(($finished+60))000"

  url="https://visualize.target.com/$dashboard_path&var-$version_key=$version_value&var-$host_key=$host_value&from=$from&to=$to"

  echo "opening worker metrics ($host_value) for build $number between $created and $finished"
  echo "> open $url"
  echo "..."

  sleep 1
  open $url
}

# post_webhook: replay the most recent github enterprise webhook delivery locally
# usage: post_webhook <org> <repo> <hook-id>
post_webhook() {
  echo "posting webhook for $1 $2 $3"

  local ORG=$1
  local REPO=$2
  local HOOK=$3

  local DELIVERY=$(curl -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://git.target.com/api/v3/repos/$ORG/$REPO/hooks/$HOOK/deliveries)

  local DELIVERY_ID=$(echo $DELIVERY | jq '.[0].id')

  echo $DELIVERY_ID

  DELIVERY=$(curl -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://git.target.com/api/v3/repos/$ORG/$REPO/hooks/$HOOK/deliveries/$DELIVERY_ID)

  local DELIVERY_GUID=$(echo $DELIVERY | jq '.request.headers."X-GitHub-Delivery"')
  local EVENT=$(echo $DELIVERY | jq '.request.headers."X-GitHub-Event"' | sed 's/"//g')

  echo $EVENT

  echo $DELIVERY | jq '.request.payload' > payload.json

  curl -L \
    -X POST \
    -H "Accept:*/*" \
    -H "content-type:application/json" \
    -H "X-GitHub-Delivery:$DELIVERY_GUID" \
    -H "X-GitHub-Event:$EVENT" \
    -H "X-GitHub-Hook-ID:$HOOK" \
    --data-binary @payload.json \
    "http://localhost:8080/webhook" | jq

  rm payload.json
}
