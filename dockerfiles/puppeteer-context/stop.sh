#!/bin/bash

kill -s SIGUSR1 $(/find_puppeteer.sh)
while [ -f /root/daemon-active ]; do sleep 1; done
