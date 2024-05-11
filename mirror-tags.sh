#!/bin/bash
REMOTE_REPO="https://github.com/kaspanet/rusty-kaspa.git"
LOCAL_REPO="$(dirname "$0")"
IGNORE_TAGS=(
"kos-20230708-083300"
"kos-20230708-084900"
"v0.1.0"
"v0.1.1"
"v0.1.1-patch-1"
"v0.1.1-patch-2"
"v0.1.2"
"v0.1.7"
"v0.1.7-deploy-fix"
"v0.13.0"
"v0.13.2"
"v0.13.3"
"v0.13.4"
"v0.13.6"
)

remote_tags=$(git ls-remote --tags $REMOTE_REPO | awk -F'/' '{print $3}')

cd $LOCAL_REPO
existing_tags=$(git tag -l)

for tag in $remote_tags; do
    if [[ ! " ${existing_tags} " =~ " ${tag} " ]] && [[ ! " ${IGNORE_TAGS[*]} " =~ " ${tag} " ]]; then
        git tag "$tag"
        git push origin "$tag"
    fi
done
