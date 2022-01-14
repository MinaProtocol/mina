#!/bin/bash

rm -rf /extra.env

if [ "$EXTRA_ENV" != "" ]; then
  echo "$EXTRA_ENV" > /extra.env
fi

kill -s SIGUSR2 $(/find_puppeteer.sh)
while [ ! -f /root/daemon-active ]; do sleep 1; done
