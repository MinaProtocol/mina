# Makefile for ppx_mina tests

# useful for negative tests, so we know the failure is the failure
# we expect

ifdef VERBOSE
REDIRECT=
else
REDIRECT= > /dev/null 2>&1
endif

.PHONY: positive-tests negative-tests

# all : positive-tests negative-tests
all : negative-tests

positive-tests :
# version syntax
	@ echo -n "Version syntax, should succeed..."
	dune build good_version_syntax.cma ${REDIRECT}
	echo "OK"
# versioning
	@ echo -n "Versioned types, should succeed..."
	@ dune build versioned_good.cma ${REDIRECT}
	@ echo "OK"
# module versioning
	@ echo -n "Module versioning, should succeed..."
	@ dune exec ./versioned_module_good.exe ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module signature versioning, should succeed..."
	@ dune exec ./versioned_sig_good.exe ${REDIRECT}
	@ echo "OK"

negative-tests :
# version syntax
	@ echo -n "Missing %%versioned, should fail..."
	@ ! dune build bad_version_syntax_missing_versioned.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "%%versioned in functor body, should fail..."
	@ ! dune build bad_versioned_in_functor.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "bin_io in nested functor body, should fail..."
	@ ! dune build bad_versioned_in_nested_functor.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Multiple version syntax errors, use VERBOSE to see them all..."
	@ ! dune build bad_version_syntax_multiple_errors.cma ${REDIRECT}
	@ echo "OK"
# versioning
	@ echo -n "Versioned type in module with invalid name, should fail..."
	@ ! dune build versioned_bad_module_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type has wrong name, should fail..."
	@ ! dune build versioned_bad_type_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type with bad option, should fail..."
	@ ! dune build versioned_bad_option.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type with bad version name, should fail..."
	@ ! dune build versioned_bad_version_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned types with bad contained types, should fail..."
	@ ! dune build versioned_bad_contained_types.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type with arrow type, should fail..."
	@ ! dune build versioned_bad_arrow_type.cma ${REDIRECT}
	@ echo "OK"
# module versioning
	@ echo -n "Module versioning with wrong module name, should fail..."
	@ ! dune build versioned_module_bad_stable_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module versioning with wrong version name, should fail..."
	@ ! dune build versioned_module_bad_version_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module versioning with missing type, should fail..."
	@ ! dune build versioned_module_bad_missing_type.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module versioning with incorrect version order, should fail..."
	@ ! dune build versioned_module_bad_version_order.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module versioning with missing to_latest, should fail..."
	@ ! dune build versioned_module_bad_missing_to_latest.cma ${REDIRECT}
	@ echo "OK"
