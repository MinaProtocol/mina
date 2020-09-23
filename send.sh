#!/bin/bash

CODA_PRIVKEY_PASS="naughty blue worm" _build/default/src/app/cli/src/coda.exe account import -config-directory /tmp/codaB/config -rest-server "http://127.0.0.1:4001/graphql" -privkey-path /tmp/codaB/wallet2/key

#CODA_PRIVKEY_PASS="naughty blue worm" _build/default/src/app/cli/src/coda.exe account list -rest-server "http://127.0.0.1:4001/graphql"

CODA_PRIVKEY_PASS="naughty blue worm" _build/default/src/app/cli/src/coda.exe account unlock -rest-server "http://127.0.0.1:4001/graphql" -public-key B62qj5WTeeEWCUdk2iEdE6JWJbHZjV6PDbVCrePjLgeN28QW1x2thUD

CODA_PRIVKEY_PASS="naughty blue worm" _build/default/src/app/cli/src/coda.exe client send-payment -rest-server "http://127.0.0.1:4001/graphql" -amount 1 -receiver B62qoRVqrgnYkzJdZkkGKqU4MxScBH3wGHGMYQnTYrEsLD2dcKoJtP8 -sender B62qj5WTeeEWCUdk2iEdE6JWJbHZjV6PDbVCrePjLgeN28QW1x2thUD
