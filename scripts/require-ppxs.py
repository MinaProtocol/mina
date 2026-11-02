#!/usr/bin/env python3

# In dune files, require preprocessing by ppx_version, so that the version syntax linter is always run

import subprocess
import string
import sexpdata

dune_string = subprocess.check_output(['find', 'src', '-name', 'dune'])

dune_paths_raw = dune_string.decode('utf-8').split('\n')


# filter out dune paths where we don't require linting
def dune_paths_ok(dune):
    path = dune.split('/')
    path_prefix2 = path[1:2]
    path_prefix3 = path[1:3]
    path_prefix4 = path[1:4]
    return (not (path_prefix2 == ['_build'] or path_prefix2 == ['external']
                 or path_prefix4 == ['lib', 'crypto', 'proof-systems']
                 or path_prefix3 == ['lib', 'snarky']
                 or path_prefix3 == ['lib', 'ppx_version']
                 or path_prefix3 == ['lib', 'bounded_types']
                 or path_prefix3 == ['app', 'reformat']
                 or path_prefix3 == ['app', 'coverage_utils']
                 or path_prefix3 == ['lib', 'ppx_mina']
                 or path_prefix3 == ['lib', 'mina_ppx']))


dune_paths = list(
    filter(lambda s: len(s) > 0 and dune_paths_ok(s), dune_paths_raw))


# filter out dune paths that cannot define a ppx bundling ppx_version; unlike
# the above, this keeps the bundles themselves
def bundle_paths_ok(dune):
    path = dune.split('/')
    path_prefix2 = path[1:2]
    path_prefix3 = path[1:3]
    path_prefix4 = path[1:4]
    return (not (path_prefix2 == ['_build'] or path_prefix2 == ['external']
                 or path_prefix4 == ['lib', 'crypto', 'proof-systems']
                 or path_prefix3 == ['lib', 'snarky']))


bundle_paths = list(
    filter(lambda s: len(s) > 0 and bundle_paths_ok(s), dune_paths_raw))

library = sexpdata.loads('library')
executable = sexpdata.loads('executable')
preprocess = sexpdata.loads('preprocess')
pps = sexpdata.loads('pps')
backend = sexpdata.loads('backend')
no_preprocessing = sexpdata.loads('no_preprocessing')
instrumentation = sexpdata.loads('instrumentation')

ppx_lint = sexpdata.loads('ppx_version')
ppx_coverage = sexpdata.loads('bisect_ppx')

version_lint_as_warning_flag = sexpdata.loads('-lint-version-syntax-warnings')

kind = sexpdata.loads('kind')
ppx_rewriter = sexpdata.loads('ppx_rewriter')
name = sexpdata.loads('name')
public_name = sexpdata.loads('public_name')
libraries = sexpdata.loads('libraries')


def symbol_name(x):
    return x.value() if isinstance(x, sexpdata.Symbol) else str(x)


def read_dune(dune):
    with open(dune) as fp:
        # wrap in parens to get list of top-level clauses
        return sexpdata.loads('(' + fp.read() + ')')


# Local ppx rewriters that bundle ppx_version, directly or through another
# bundle; a pps list naming one of them runs ppx_version.
def find_ppx_lint_bundles():
    rewriters = []
    for dune in bundle_paths:
        for sexp in read_dune(dune):
            if not (isinstance(sexp, list) and len(sexp) > 0
                    and sexpdata.car(sexp) == library):
                continue
            names = []
            deps = []
            is_rewriter = False
            for clause in sexpdata.cdr(sexp):
                if not (isinstance(clause, list) and len(clause) > 0):
                    continue
                head = sexpdata.car(clause)
                if head == name or head == public_name:
                    names += [symbol_name(x) for x in sexpdata.cdr(clause)]
                elif head == libraries:
                    deps += [
                        symbol_name(x) for x in sexpdata.cdr(clause)
                        if not isinstance(x, list)
                    ]
                elif head == kind and ppx_rewriter in sexpdata.cdr(clause):
                    is_rewriter = True
            if is_rewriter:
                rewriters.append((names, deps))
    bundles = {symbol_name(ppx_lint)}
    changed = True
    while changed:
        changed = False
        for names, deps in rewriters:
            if any(dep in bundles for dep in deps) and not all(
                    n in bundles for n in names):
                bundles.update(names)
                changed = True
    return bundles

exit_code = 0


def missing_ppx_error(dune, ppx):
    print(
        "In dune file " + dune +
        ", the preprocessing clause is missing; there should be one containing "
        + (sexpdata.dumps(ppx)))
    global exit_code
    exit_code = 1


def missing_backend_error(dune, ppx):
    print(
        "In dune file " + dune +
        ", the instrumentation clause is missing; there should be one containing a backend for "
        + (sexpdata.dumps(ppx)))
    global exit_code
    exit_code = 1


def no_ppx_error(dune, ppxs):
    print(
        "In dune file " + dune +
        ", the preprocessing clause indicates no preprocessing, but it should include "
        + (sexpdata.dumps(ppxs)))
    global exit_code
    exit_code = 1


ppx_lint_bundles = find_ppx_lint_bundles()


def get_ppx_ndx(dune, ppxs, ppx):
    if not any(
            symbol_name(x) in ppx_lint_bundles for x in ppxs
            if not isinstance(x, list)):
        print("In dune file " + dune +
              ", the preprocessing clause does not contain " +
              (sexpdata.dumps(ppx)) + " or a ppx bundling it (" +
              ", ".join(sorted(ppx_lint_bundles - {symbol_name(ppx)})) +
              ")")
        global exit_code
        exit_code = 1

def check_for_proscribed_flag(dune, ppxs, flag):
    try:
        ndx = ppxs.index(flag)
        print("In dune file " + dune +
              ", the preprocessing clause contains proscribed flag " + (sexpdata.dumps(flag)))
        global exit_code
        exit_code = 1
    except:
        None

def get_backends_ndx(dune, backends, ppx):
    try:
        backends.index(ppx)
    except:
        print("In dune file " + dune +
              ", the instrumentation backends clause does not contain " +
              (sexpdata.dumps(ppx)))
        global exit_code
        exit_code = 1

for dune in dune_paths:
    with open(dune) as fp:
        # wrap in parens to get list of top-level clauses
        sexps = sexpdata.loads('(' + fp.read() + ')')
        for sexp in sexps:
            if isinstance(sexp, list) and len(sexp) > 0 and (
                    sexpdata.car(sexp) == library
                    or sexpdata.car(sexp) == executable):
                clauses = sexpdata.cdr(sexp)
                found_preprocess = False
                found_instrumentation = False
                for clause in clauses:
                    if sexpdata.car(clause) == preprocess:
                        found_preprocess = True
                        subclause = sexpdata.car(sexpdata.cdr(clause))
                        if subclause == no_preprocessing:
                            # error if no preprocessing explicitly
                            no_ppx_error(dune, ppx_lint)
                        elif sexpdata.car(subclause) == pps:
                            ppxs = sexpdata.cdr(subclause)
                            check_for_proscribed_flag(dune,ppxs,version_lint_as_warning_flag)
                            lint_ppx_ndx = get_ppx_ndx(dune, ppxs, ppx_lint)
                    if sexpdata.car(clause) == instrumentation:
                        found_instrumentation = True
                        subclause = sexpdata.car(sexpdata.cdr(clause))
                        if sexpdata.car(subclause) == backend:
                            backends = sexpdata.cdr(subclause)
                            coverage_ppx_ndx = get_backends_ndx(dune, backends, ppx_coverage)
                if found_preprocess == False:
                    # error if no preprocessing implicitly
                    missing_ppx_error(dune, ppx_lint)
                if found_instrumentation == False:
                    missing_backend_error(dune, ppx_coverage)

exit(exit_code)
