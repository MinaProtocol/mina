# Makefile for ppx_coda tests

# useful for negative tests, so we know the failure is the failure
# we expect

ifdef VERBOSE
REDIRECT=
else
REDIRECT= > /dev/null 2>&1
endif

.PHONY: positive-tests negative-tests

all : positive-tests negative-tests

positive-tests : unexpired.ml
# expiration
	@ echo -n "Unexpired, should succeed..."
	@ dune build unexpired.cma ${REDIRECT}
	@ echo "OK"
# define locally
	@ echo -n "Define locally, should succeed..."
	@ dune build define_locally_good.cma ${REDIRECT}
	@ echo "OK"
# define existing
	@ echo -n "Define from scope, should succeed..."
	@ dune build define_from_scope_good.cma ${REDIRECT}
	@ echo "OK"

negative-tests :
# expiration
	@ echo -n "Expired, should fail..."
	@ ! dune build expired.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Expired in module, should fail..."
	@ ! dune build expiry_in_module.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Invalid date, should fail..."
	@ ! dune build expiry_invalid_date.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Invalid format, should fail..."
	@ ! dune build expiry_invalid_format.cma ${REDIRECT}
	@ echo "OK"
