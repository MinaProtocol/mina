#!/bin/bash

eval `opam config env` && make check-format
