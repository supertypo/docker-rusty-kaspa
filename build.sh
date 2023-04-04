#!/bin/sh

# Arguments: [push|nopush] [git-repo]

REPO_URL_MAIN="https://github.com/kaspanet/rusty-kaspa"
DOCKER_REPO_PREFIX="supertypo/rusty"
ARTIFACTS="kaspad kaspa-wrpc-proxy"

BUILD_DIR="$(dirname $0)"
PUSH=$1
REPO_URL=${2:-$REPO_URL_MAIN}
REPO_DIR="$BUILD_DIR/work/$(echo $REPO_URL | sed -E 's/[^a-zA-Z0-9]+/_/g')"

set -e

if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  echo $(cd "$REPO_DIR" && git reset --hard HEAD~1)
fi

(cd "$REPO_DIR" && git pull)
tag=$(cd "$REPO_DIR" && git log -n1 --format="%cs.%h")

for artifact in $ARTIFACTS; do
  dockerRepo="${DOCKER_REPO_PREFIX}-$artifact"

  docker build --pull \
    --build-arg REPO_URL=${REPO_URL} \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg RUSTY_VERSION="$tag" \
    --target $artifact \
    --tag $dockerRepo:$tag "$BUILD_DIR"

  docker tag $dockerRepo:$tag $dockerRepo:latest
  echo Tagged $dockerRepo:latest

  if [ "$PUSH" = "push" ]; then
    docker push $dockerRepo:$tag
    if [ "$REPO_URL" = "$REPO_URL_MAIN" ]; then
      docker push $dockerRepo:latest
    fi
  fi
done

