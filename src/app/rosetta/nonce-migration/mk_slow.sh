#!/bin/bash

cat slow.sql | sed 's/$1/'$1'/' | sed 's/$2/'$2'/'

