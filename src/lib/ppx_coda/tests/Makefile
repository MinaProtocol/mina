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
# versioning
	@ echo -n "Versioned types, should succeed..."
	@ dune build versioned_good.cma ${REDIRECT}
	@ echo "OK"
# define locally
	@ echo -n "Define locally, should succeed..."
	@ dune build define_locally_good.cma ${REDIRECT}
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
