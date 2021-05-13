#!/bin/bash

kill -s SIGUSR1 $(find_puppeteer)
while [ -f daemon-active ]; do sleep 1; done