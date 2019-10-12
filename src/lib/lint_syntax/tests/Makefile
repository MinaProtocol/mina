# Makefile for syntax linter tests

# useful for negative tests, so we know the failure is the failure
# we expect

ifdef VERBOSE
REDIRECT=
else
REDIRECT= > /dev/null 2>&1
endif

LINTER=../../../_build/default/lib/lint_syntax/driver.exe

.PHONY: positive-tests negative-tests

all : linter positive-tests negative-tests

linter :
	${MAKE} -C ../../../.. build-syntax-linter

positive-tests :
	@ echo -n "Good syntax, should succeed..."
	@ ${LINTER} good_syntax.ml ${REDIRECT}
	@ echo "OK"

negative-tests :
	@ echo -n "Missing deriving version, should fail..."
	@ ! ${LINTER} bad_syntax_missing_version.ml ${REDIRECT}
	@ echo "OK"

	@ echo -n "Missing deriving bin_io, should fail..."
	@ ! ${LINTER} bad_syntax_missing_bin_io.ml ${REDIRECT}
	@ echo "OK"

	@ echo -n "bin_io in functor body, should fail..."
	@ ! ${LINTER} bad_syntax_bin_io_in_functor.ml ${REDIRECT}
	@ echo "OK"

	@ echo -n "version in functor body, should fail..."
	@ ! ${LINTER} bad_syntax_version_in_functor.ml ${REDIRECT}
	@ echo "OK"

	@ echo -n "bin_io in nested functor body, should fail..."
	@ ! ${LINTER} bad_syntax_bin_io_in_nested_functor.ml ${REDIRECT}
	@ echo "OK"
