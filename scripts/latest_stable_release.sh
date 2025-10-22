#!/usr/bin/env bash
git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1
