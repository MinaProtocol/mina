#!/bin/bash

test "$(python2 render.py)" = "$(cat config.yml)"
