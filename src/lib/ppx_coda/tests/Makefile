# Makefile for ppx_coda tests

.PHONY: positive-tests negative-tests

all : positive-tests negative-tests

positive-tests : unexpired.ml
	@ echo -n "Unexpired, should succeed..."
	@ dune build unexpired.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Unexpired in module, should succeed..."
	@ dune build unexpired_in_module.cma > /dev/null 2>&1
	@ echo "OK"


negative-tests :
	@ echo -n "Expired, should fail..."
	@ ! dune build expired.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Expired in module, should fail..."
	@ ! dune build expiry_in_module.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Invalid date, should fail..."
	@ ! dune build expiry_invalid_date.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Invalid format, should fail..."
	@ ! dune build expiry_invalid_format.cma > /dev/null 2>&1
	@ echo "OK"
