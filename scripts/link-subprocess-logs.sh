#!/bin/sh

# link subprocess logs for CI to help debug test failures

# This only works for mac-os and linux

if [ -z ${TMPDIR+x} ] ;
then TMPDIR="/tmp/" ;
else false ;
fi

COUNTER=0 ;
for file in `find $TMPDIR  -name "coda-prover.log"` ;
  do ln -s "$file" "$1/coda-prover.log.$COUNTER" ;
  COUNTER=$((COUNTER+1)) ;
done