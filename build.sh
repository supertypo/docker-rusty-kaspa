#!/bin/sh

# Arguments: [push|nopush] [version] [git-repo]

REPO_URL_MAIN="https://github.com/kaspanet/rusty-kaspa"
DOCKER_REPO_PREFIX="supertypo/rusty"
ARTIFACTS="builder kaspad kaspa-wrpc-proxy"
ARCHES="linux/amd64 linux/arm64"

BUILD_DIR="$(dirname $0)"
PUSH=$1
VERSION=$2
TAG=$3
REPO_URL=${4:-$REPO_URL_MAIN}
REPO_DIR="$BUILD_DIR/work/$(echo $REPO_URL | sed -E 's/[^a-zA-Z0-9]+/_/g')"

set -e

if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  echo $(cd "$REPO_DIR" && git reset --hard HEAD~1)
fi

echo "===================================================="
echo " Pulling $REPO_URL"
echo "===================================================="
(cd "$REPO_DIR" && git pull)
if [ -n "$TAG" ]; then
  (cd "$REPO_DIR" && git checkout $TAG)
fi
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
    --build-arg REPO_URL=$REPO_URL \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg RUSTY_VERSION="$tag" \
    --target $1 \
    --tag $dockerRepo:$tag "$BUILD_DIR"

  $docker tag $dockerRepo:$tag $dockerRepo:nightly
  echo Tagged $dockerRepo:nightly

  if [ -n "$VERSION" ]; then
     $docker tag $dockerRepo:$tag $dockerRepo:$VERSION
     echo Tagged $dockerRepo:$VERSION
     if [ "$REPO_URL" = "$REPO_URL_MAIN" ]; then
       $docker tag $dockerRepo:$tag $dockerRepo:latest
       echo Tagged $dockerRepo:latest
     fi
  fi

  if [ "$PUSH" = "push" ]; then
    $docker push $dockerRepo:$tag
    if [ -n "$VERSION" ]; then
      $docker push $dockerRepo:$VERSION
    fi
    if [ "$REPO_URL" = "$REPO_URL_MAIN" ]; then
      $docker push $dockerRepo:nightly
      if [ -n "$VERSION" ]; then
        $docker push $dockerRepo:latest
      fi
    fi
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
  if [ -n "$VERSION" ]; then
    dockerRepoArgs="$dockerRepoArgs --tag $dockerRepo:$VERSION"
  fi
  if [ "$REPO_URL" = "$REPO_URL_MAIN" ]; then
    dockerRepoArgs="$dockerRepoArgs --tag $dockerRepo:nightly"
    if [ -n "$VERSION" ]; then
      dockerRepoArgs="$dockerRepoArgs --tag $dockerRepo:latest"
    fi 
  fi
  $docker buildx build --pull --platform=$(echo $ARCHES | sed 's/ /,/g') $dockerRepoArgs \
    --build-arg REPO_URL=$REPO_URL \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg RUSTY_VERSION="$tag" \
    --target $1 \
    --tag $dockerRepo:$tag "$BUILD_DIR"    
  echo "===================================================="
  echo " Completed build for $1"
  echo "===================================================="
}

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

