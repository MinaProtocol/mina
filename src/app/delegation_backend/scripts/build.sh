#!/usr/bin/env bash

set -e

if [[ "$OUT" == "" ]]; then
  OUT="$PWD/result"
fi

ref_signer="$PWD/../../external/c-reference-signer"

GCR=gcr.io/o1labs-192920/delegation-backend-production

mkdir -p "$OUT"/{headers,bin}
rm -f "$OUT"/libmina_signer.so # Otherwise re-building without clean causes permissions issue
if [[ "$LIB_MINA_SIGNER" == "" ]]; then
  # No nix
  cp -R "$ref_signer" "$OUT"
  make -C "$OUT/c-reference-signer" clean libmina_signer.so
  cp "$OUT/c-reference-signer/libmina_signer.so" "$OUT"
else
  cp "$LIB_MINA_SIGNER" "$OUT"/libmina_signer.so
fi
cp "$ref_signer"/*.h "$OUT/headers"

docker_build() {
  tag=delegation-backend-production
  if [[ "$TAG" != "" ]]; then
    tag="$tag:$TAG"
  fi
  docker build -t "$tag" -f Dockerfile.production .
}

case "$1" in
  test)
    cd src
    LD_LIBRARY_PATH="$OUT" $GO test
    ;;
  docker)
    docker_build
    docker save delegation-backend-production \
      | gzip > result/delegation_backend.tar.gz
    ;;
  docker-upload)
    if [[ "$TAG" == "" ]]; then
      echo "Specify TAG env variable"
    else
      docker_build
      docker tag delegation-backend-production:"$TAG" "$GCR":"$TAG"
      docker push "$GCR":"$TAG"
    fi
    ;;
  docker-run)
    if [[ "$GOOGLE_APPLICATION_CREDENTIALS" == "" ]]; then
      echo "Specify path to credentials JSON file in env variable GOOGLE_APPLICATION_CREDENTIALS"
      exit 1
    else
      docker_build
      docker run -p 8080:8080 -v "$GOOGLE_APPLICATION_CREDENTIALS":/creds.json -e GOOGLE_APPLICATION_CREDENTIALS=/creds.json delegation-backend-production
    fi
    ;;
  "")
    cd src/delegation_backend
    $GO build -o "$OUT/bin/delegation_backend"
    echo "to run use cmd: LD_LIBRARY_PATH=result ./result/bin/delegation_backend"
    ;;
  *)
    echo "unknown command $1"
    exit 2
    ;;
esac
