#!/bin/bash

kill -s SIGUSR2 $(find_puppeteer )
while [ ! -f daemon-active ]; do sleep 1; done