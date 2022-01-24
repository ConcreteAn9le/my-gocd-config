#!/usr/bin/env bash
set -eu

GOCD_DOMAIN=$1
GOCD_ACCESS_TOKEN=$2
PROFILE=$3
UPDATE_EXISTING=$4
export ELASTIC_AGENT_ROLE_ARN=$5
CLUSTER_PROFILE_ID="k8-cluster-profile"

PROFILE_DATA_TEMPLATE=$(cat ./$PROFILE/gocd-agent-template.yaml)

POD_CONFIG=$(cat ./$PROFILE/gocd-agent-pod-spec.yaml)

PROFILE_DATA=$(echo "$PROFILE_DATA_TEMPLATE" | jq -r --arg POD_CONFIG "${POD_CONFIG}" '.properties = [.properties[] | select(.key == "PodConfiguration").value = $POD_CONFIG]' | jq -r --arg PROFILE "${PROFILE}" '.id = $PROFILE' | jq -r --arg CLUSTER_PROFILE_ID "${CLUSTER_PROFILE_ID}" '.cluster_profile_id = $CLUSTER_PROFILE_ID' )

if [[ "$UPDATE_EXISTING" = "false" ]]; then
  curl --insecure "http://${GOCD_DOMAIN}/go/api/elastic/profiles" \
        -H "Authorization: Bearer $GOCD_ACCESS_TOKEN" \
        -H 'Accept: application/vnd.go.cd.v2+json' \
        -H 'Content-Type: application/json' \
        -X POST -d "${PROFILE_DATA}"

elif [[ "$UPDATE_EXISTING" = "true" ]]; then
  curl --insecure --silent "http://${GOCD_DOMAIN}/go/api/elastic/profiles/${PROFILE}" \
      -H "Authorization: Bearer $GOCD_ACCESS_TOKEN" \
      -H 'Accept: application/vnd.go.cd.v2+json' --dump-header tmp-headers >/dev/null 2>&1
  etag=$(cat tmp-headers | grep -oE "ETag: \".*\"" | grep -oE "\".*\"" | grep -oE "[^\"]+")
  echo $etag
  curl --insecure -w "%{http_code}" -v "http://${GOCD_DOMAIN}/go/api/elastic/profiles/${PROFILE}" \
      -H "Authorization: Bearer $GOCD_ACCESS_TOKEN" \
      -H 'Accept: application/vnd.go.cd.v2+json' \
      -H 'Content-Type: application/json' \
      -H "If-Match: \"${etag}\"" \
      -X PUT -d "${PROFILE_DATA}"
else
  echo -e "\033[31mInvalid value for UPDATE_EXISTING provided (please supply either 'true' or 'false'\033[0m"
fi

