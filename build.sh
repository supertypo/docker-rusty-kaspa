#!/bin/sh

REPO_URL_MAIN="https://github.com/kaspanet/rusty-kaspa"
DOCKER_REPO_PREFIX="supertypo/rusty"
ARTIFACTS="kaspad rothschild kaspa-wallet"
ARCHES="linux/amd64 linux/arm64"

BUILD_DIR="$(dirname $0)"
PUSH=$1
VERSIONS=$2
TAG=${3:-master}
REPO_URL=${4:-$REPO_URL_MAIN}
REPO_DIR="$BUILD_DIR/work/$(echo $REPO_URL | sed -E 's/[^a-zA-Z0-9]+/_/g')"

if [ -z "$PUSH" ] || [ -z "$VERSIONS" ]; then
  echo "Usage: $0 push|nopush \"multiple versions\" [tag] [git-repo]"
  exit 1
fi

set -e

if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  echo $(cd "$REPO_DIR" && git reset --hard HEAD~1)
fi

echo "===================================================="
echo " Pulling $REPO_URL"
echo "===================================================="
(cd "$REPO_DIR" && git fetch && git checkout $TAG && (git pull 2>/dev/null | true))

tag=$(cd "$REPO_DIR" && git log -n1 --format="%cs.%h")

docker=docker
id -nG $USER | grep -qw docker || docker="sudo $docker"

plain_build() {
  echo
  echo "===================================================="
  echo " Running current arch build for $1"
  echo "===================================================="
  dockerRepo="${DOCKER_REPO_PREFIX}-$1"

  $docker build --pull \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg ARTIFACTS="$ARTIFACTS" \
    --build-arg REPO_URL=$REPO_URL \
    --build-arg RUSTY_VERSION="$tag" \
    --target $1 \
    --tag $dockerRepo:$tag "$BUILD_DIR"

  for version in $VERSIONS; do
    $docker tag $dockerRepo:$tag $dockerRepo:$version
    echo Tagged $dockerRepo:$version
  done

  if [ "$PUSH" = "push" ]; then
    $docker push $dockerRepo:$tag
    for version in $VERSIONS; do
      $docker push $dockerRepo:$version
    done
  fi
  echo "===================================================="
  echo " Completed current arch build for $1"
  echo "===================================================="
}

multi_arch_build() {
  echo
  echo "===================================================="
  echo " Running build for $1"
  echo "===================================================="
  dockerRepo="${DOCKER_REPO_PREFIX}-$1"
  dockerRepoArgs=

  if [ "$PUSH" = "push" ]; then
    dockerRepoArgs="$dockerRepoArgs --push"
  fi

  for version in $VERSIONS; do
    dockerRepoArgs="$dockerRepoArgs --tag $dockerRepo:$version"
  done

  $docker buildx build --pull --platform=$(echo $ARCHES | sed 's/ /,/g') $dockerRepoArgs \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg ARTIFACTS="$ARTIFACTS" \
    --build-arg REPO_URL=$REPO_URL \
    --build-arg RUSTY_VERSION="$tag" \
    --target $1 \
    --tag $dockerRepo:$tag "$BUILD_DIR"
  echo "===================================================="
  echo " Completed build for $1"
  echo "===================================================="
}

if [ "$PUSH" = "push" ]; then
  echo
  echo "===================================================="
  echo " Setup multi arch build ($ARCHES)"
  echo "===================================================="
  if $docker buildx create --name=mybuilder --append --node=mybuilder0 --platform=$(echo $ARCHES | sed 's/ /,/g') --bootstrap --use 1>/dev/null 2>&1; then
    echo "SUCCESS - doing multi arch build"
    for artifact in $ARTIFACTS; do
      multi_arch_build $artifact
    done
  else
    echo "FAILED - building on current arch"
    for artifact in $ARTIFACTS; do
      plain_build $artifact
    done
  fi
else
  for artifact in $ARTIFACTS; do
    plain_build $artifact
  done
fi
