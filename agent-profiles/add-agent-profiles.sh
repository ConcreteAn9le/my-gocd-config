#!/usr/bin/env bash

set -eu

# Get script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Setting variables
GOCD_DOMAIN=$1
GOCD_ACCESS_TOKEN=$2
export ELASTIC_AGENT_ROLE_ARN=$3
TAG=3

# Check scripts variables exists
if [[ -z $GOCD_DOMAIN ]]; then
 echo "Please supply the GoCD domain"
 exit 1
fi

if [[ -z $GOCD_ACCESS_TOKEN ]]; then
 echo "Please supply your GoCD personal access token"
 exit 1
fi

if [[ -z $ELASTIC_AGENT_ROLE_ARN ]]; then
 echo "Please supply the Elastic Agent Role Arn domain"
 exit 1
fi

# Get gocd server exists elastic profiles
CLUSTER_IDS=$(curl --insecure --silent "http://${GOCD_DOMAIN}/go/api/elastic/profiles" \
                                  -H "Authorization: Bearer $GOCD_ACCESS_TOKEN" \
                                  -H 'Accept: application/vnd.go.cd.v2+json' | jq '._embedded .profiles [] .id')

# Get current directory's exists sub-directories as profile id
cd $(dirname "$0")
PROFILES=$(find * -maxdepth 0 -type d)


# Introduction:
## local_profile: current directory's sub-directory names
## gocd_profile: gocd server's profile name

for local_profile in $PROFILES
do
  for gocd_profile in ${CLUSTER_IDS[@]}
  do
    if [[ \""$local_profile"\" == "${gocd_profile}" ]]
    then
      echo "local:$local_profile ｜ gocd_server:$gocd_profile"
      TAG=1
      break 1
    else
      echo "local:$local_profile ｜ gocd_server:$gocd_profile"
      TAG=0
    fi
  done

  if [[ "$TAG" -eq 0 ]]
  then
    echo "need to add elastic profile: ${local_profile}"
    ./add-single-agent-profile.sh $GOCD_DOMAIN $GOCD_ACCESS_TOKEN "${local_profile}" false $ELASTIC_AGENT_ROLE_ARN
  elif [[ "$TAG" -eq 1 ]]
  then
    echo "need to update elastic profile: ${local_profile}"
    ./add-single-agent-profile.sh $GOCD_DOMAIN $GOCD_ACCESS_TOKEN "${local_profile}" true $ELASTIC_AGENT_ROLE_ARN
  else
    echo "Please check code logic!"
  fi

done
