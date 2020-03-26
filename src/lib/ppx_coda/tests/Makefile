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
# version syntax
	@ echo -n "Version syntax, should succeed..."
	@ dune build good_version_syntax.cma ${REDIRECT}
	@ echo "OK"
# versioning
	@ echo -n "Versioned types, should succeed..."
	@ dune build versioned_good.cma ${REDIRECT}
	@ echo "OK"
# define locally
	@ echo -n "Define locally, should succeed..."
	@ dune build define_locally_good.cma ${REDIRECT}
	@ echo "OK"
# define existing
	@ echo -n "Define from scope, should succeed..."
	@ dune build define_from_scope_good.cma ${REDIRECT}
	@ echo "OK"
# module versioning
	@ echo -n "Module versioning, should succeed..."
	@ dune exec ./versioned_module_good.exe ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module signature versioning, should succeed..."
	@ dune exec ./versioned_sig_good.exe ${REDIRECT}
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
# version syntax
	@ echo -n "Missing deriving version, should fail..."
	@ ! dune build bad_version_syntax_missing_version.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "bin_io in functor body, should fail..."
	@ ! dune build bad_version_syntax_bin_io_in_functor.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "version in functor body, should fail..."
	@ ! dune build bad_version_syntax_version_in_functor.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "versioned in functor body, should fail..."
	@ ! dune build bad_version_syntax_versioned_in_functor.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "bin_io in nested functor body, should fail..."
	@ ! dune build bad_version_syntax_bin_io_in_nested_functor.cma ${REDIRECT}
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
	@ echo -n "Versioned type, bad module structure, should fail..."
	@ ! dune build versioned_bad_module_structure.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type, unnumbered, invalid use of 'version', should fail..."
	@ ! dune build versioned_bad_unnumbered.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned type, bad wrapped module structure, should fail..."
	@ ! dune build versioned_bad_wrapped_module_structure.cma ${REDIRECT}
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
	@ echo -n "Versioned types with unversioned type with type parameters, should fail..."
	@ ! dune build versioned_bad_type_parameters.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned types with GADT type with unversioned inputs, should fail..."
	@ ! dune build versioned_bad_gadt.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Versioned types with GADT type with unversioned results, should fail..."
	@ ! dune build versioned_bad_gadt_results.cma ${REDIRECT}
	@ echo "OK"
# module versioning
	@ echo -n "Module versioning with wrong module name, should fail..."
	@ ! dune build versioned_module_bad_stable_name.cma ${REDIRECT}
	@ echo "OK"
	@ echo -n "Module versioning with wrong version name, should fail..."
	@ ! dune build versioned_module_bad_version.cma ${REDIRECT}
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
