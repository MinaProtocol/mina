#!/usr/bin/env bash

set -e

out="$PWD/result"

ref_signer="$PWD/../../external/c-reference-signer"

mkdir -p "$out"/{headers,bin}
rm -f "$out"/libmina_signer.so # Otherwise re-building without clean causes permissions issue
if [[ "$LIB_MINA_SIGNER" == "" ]]; then
  # No nix
  make -C "$ref_signer" clean libmina_signer.so
  cp "$ref_signer/libmina_signer.so" "$out"
else
  cp "$LIB_MINA_SIGNER" "$out"/libmina_signer.so
fi
cp "$ref_signer"/*.h "$out/headers"

docker_build() {
  tag=delegation-backend-production
  if [[ "$TAG" != "" ]]; then
    tag="$tag:$TAG"
  fi
  docker build -t "$tag" -f Dockerfile.production .
}

if [[ "$1" == "test" ]]; then
  cd src
  LD_LIBRARY_PATH="$out" $GO test
elif [[ "$1" == "docker" ]]; then
  docker_build
  docker save delegation-backend-production | gzip > result/delegation_backend.tar.gz
elif [[ "$1" == "docker-upload" ]]; then
  if [[ "$TAG" == "" ]]; then
    echo "Specify TAG env variable"
  else
    docker_build
    docker tag delegation-backend-production:"$TAG" gcr.io/o1labs-192920/delegation-backend-production:"$TAG"
    docker push gcr.io/o1labs-192920/delegation-backend-production:"$TAG"
  fi
elif [[ "$1" == "docker-run" ]]; then
  if [[ "$GOOGLE_APPLICATION_CREDENTIALS" == "" ]]; then
    echo "Specify path to credentials JSON file in env variable GOOGLE_APPLICATION_CREDENTIALS"
  else
    docker_build
    docker run -p 8080:8080 -v "$GOOGLE_APPLICATION_CREDENTIALS":/creds.json -e GOOGLE_APPLICATION_CREDENTIALS=/creds.json delegation-backend-production
  fi
else
  cd src/delegation_backend
  $GO build -o "$out/bin/delegation_backend"
  echo "to run use cmd: LD_LIBRARY_PATH=result ./result/bin/delegation_backend"
fi

