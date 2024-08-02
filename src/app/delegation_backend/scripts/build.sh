#!/usr/bin/env bash

set -e

if [[ "$OUT" == "" ]]; then
  OUT="$PWD/result"
fi


mkdir -p "$OUT"/bin
rm -Rf "$OUT/c-reference-signer" "$OUT/headers" "$OUT"/libmina_signer.so # Otherwise re-building without clean causes permissions issue
if [[ "$PKG_MINA_SIGNER" == "" ]]; then
  # No nix

  # Hack to avoid one extra submodule
  git clone -b v1.0.0 --depth 1 https://github.com/MinaProtocol/c-reference-signer.git "$OUT/c-reference-signer"
  make -C "$OUT/c-reference-signer" clean libmina_signer.so
  cp "$OUT/c-reference-signer/libmina_signer.so" "$OUT"
  mkdir -p "$OUT/headers"
  cp "$ref_signer"/*.h "$OUT/headers"
else
  ln -s "$PKG_MINA_SIGNER"/lib/libmina_signer.so "$OUT"/libmina_signer.so
  ln -s "$PKG_MINA_SIGNER"/headers "$OUT"/headers
fi

case "$1" in
  test)
    cd src/delegation_backend
    LD_LIBRARY_PATH="$OUT" $GO test
    ;;
  docker-run)
    if [[ "$GOOGLE_APPLICATION_CREDENTIALS" == "" ]]; then
      echo "Specify path to credentials JSON file in env variable GOOGLE_APPLICATION_CREDENTIALS"
      exit 1
    fi
    tag=delegation-backend-test
    docker build -t "$tag" -f ../../../dockerfiles/Dockerfile-delegation-backend .
    docker run -p 8080:8080 -v "$GOOGLE_APPLICATION_CREDENTIALS":/creds.json -e GOOGLE_APPLICATION_CREDENTIALS=/creds.json "$tag"
    ;;
  docker-toolchain | docker)
    if [[ "$VERSION" == "" ]]; then
      echo "Specify VERSION"
      exit 1
    fi
    cd ../../..
    scripts/release-docker.sh -s delegation-backend${1:6} -v "$VERSION"
    ;;
  "")
    cd src/cmd/delegation_backend
    $GO build -o "$OUT/bin/delegation_backend"
    echo "to run use cmd: LD_LIBRARY_PATH=result ./result/bin/delegation_backend"
    ;;
  *)
    echo "unknown command $1"
    exit 2
    ;;
esac
