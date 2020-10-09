#!/bin/bash

# create coverage profiles in _coverage
# see Makefile targets coverage-* to display results

run_unit_tests_with_coverage() {
  if [ "${DUNE_PROFILE}" = "" ]; then
    DUNE_PROFILE=dev
  fi
  NPROC=${NPROC:-$(nproc --all)} # Linux-specific
  # force to make sure all coverage files generated
  # don't test nonconsensus code
  if [ -z $@ ] ; then
      echo "Creating coverage files for all libraries"
      BISECT_ENABLE=YES dune runtest --force src/lib --profile=${DUNE_PROFILE} -j${NPROC}
  else
      for libdir in $@; do
	  echo "Creating coverage files for library \"$libdir\""
	  BISECT_ENABLE=YES dune runtest --force src/lib/$libdir --profile=${DUNE_PROFILE} -j${NPROC}
      done
  fi
}

run_unit_tests_with_coverage $@
