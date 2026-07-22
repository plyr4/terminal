#!/usr/bin/env bash
# replay the most recent vela webhook delivery from github.com against a local server.
# requires GHEC_TOKEN in the environment.
# usage: post_ghec_webhook.sh <org> <repo> [delivery-index]

function post_webhook() {
  local ORG=$1
  local REPO=$2
  local HOOK=""
  HOOKNUM=$3

  if [ -z "$HOOKNUM" ]; then
    HOOKNUM=0
  fi

  local VELA_HOOK=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GHEC_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$ORG/$REPO/hooks | jq -c '.[]')
  

  while read i; do
    if [[ "$(echo $i | jq -r '.config.url')" == "https://api.target.com/webhooks/v1/ci-server-prod-1db7ef1ba046a1f226384c6419148956" ]]; then
      HOOK=$(echo $i | jq '.id')
    fi

    # prefer the dev hook if both exist
    if [[ "$(echo $i | jq -r '.config.url')" == "https://stage-api.target.com/webhooks/v1/ci-server-dev-1d8b88c14bf67310124878d16a019782" ]]; then
      HOOK=$(echo $i | jq '.id')
      break
    fi
  done <<< "$VELA_HOOK"

  echo "Hook ID: $HOOK"

  echo "Fetching most recent delivery_id at https://api.github.com/repos/$ORG/$REPO/hooks/$HOOK/deliveries ..."
  local DELIVERY_ID=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GHEC_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$ORG/$REPO/hooks/$HOOK/deliveries | jq ".[$HOOKNUM].id")

  echo "Delivery ID: $DELIVERY_ID"
  

  echo "Fetching payload from delivery at https://api.github.com/repos/$ORG/$REPO/hooks/$HOOK/deliveries/$DELIVERY_ID ..."
  
  
  local DELIVERY=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GHEC_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$ORG/$REPO/hooks/$HOOK/deliveries/$DELIVERY_ID)
  

  local DELIVERY_GUID=$(echo $DELIVERY | jq '.request.headers."X-GitHub-Delivery"')
  local EVENT=$(echo $DELIVERY | jq '.request.headers."X-GitHub-Event"' | sed 's/"//g')

  echo "GUID: $DELIVERY_GUID, Event: $EVENT"
  
  
  local PAYLOAD=$(echo $DELIVERY | jq '.request.payload')

  curl -L \
    -X POST \
    -H "Accept:*/*" \
    -H "content-type:application/json" \
    -H "X-GitHub-Delivery:$DELIVERY_GUID" \
    -H "X-GitHub-Event:$EVENT" \
    -H "X-GitHub-Hook-ID:$HOOK" \
    -d "$PAYLOAD" \
    "http://localhost:8080/webhook" | jq
}

function main() {
  local ORG=$1
  local REPO=$2
  local HOOKNUM=$3

  post_webhook "$ORG" "$REPO" "$HOOKNUM"
}

main "$@"
