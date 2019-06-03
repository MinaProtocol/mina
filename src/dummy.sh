#!/usr/bin/env bash

while true; do
  sleep 0.3
  echo "127.0.0.1:3001 key on"
  echo "127.0.0.1:3002 key on"
  sleep 0.2
  echo "127.0.0.1:3003 key on"
  echo "127.0.0.1:3002 key off"
done

