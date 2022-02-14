#!/bin/bash

cat new.sql | sed 's/$1/'$1'/' | sed 's/$2/'$2'/'

