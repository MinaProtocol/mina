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
	@ echo -n "Versioned type, should succeed..."
	@ dune build versioned_good.cma > /dev/null 2>&1
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
	@ echo -n "Versioned type in module with invalid name, should fail..."
	@ ! dune build versioned_bad_module_name.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Versioned type has wrong name, should fail..."
	@ ! dune build versioned_bad_type_name.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Versioned type with option, bad module structure, should fail..."
	@ ! dune build versioned_bad_with_option.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Versioned type with bad option, should fail..."
	@ ! dune build versioned_bad_option.cma > /dev/null 2>&1
	@ echo "OK"
	@ echo -n "Versioned type with bad version name, should fail..."
	@ ! dune build versioned_bad_version_name.cma > /dev/null 2>&1
	@ echo "OK"
