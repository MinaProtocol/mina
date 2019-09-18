#!/usr/bin/env python

import argparse
import collections
import jinja2
import os
import subprocess
import sys
import time
from itertools import chain

build_artifact_profiles = [
    'testnet_postake_medium_curves'
]

unit_test_profiles = [
    'test_postake_snarkless_unittest',
    'dev'
]

unit_test_profiles_medium_curves = [
    'test_postake_snarkless_medium_curves_unit_test',
    'dev_medium_curves'
]

simple_tests = [
    'full-test',
    'transaction-snark-profiler -k 2',
]

integration_tests = [
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-prefix-test -who-proposes 0',
    'coda-shared-prefix-test -who-proposes 1',
    'coda-restart-node-test',
    'coda-change-snark-worker-test',
    'coda-archive-node-test'
]

all_tests = simple_tests + integration_tests

# dictionary mapping configs to lists of tests
small_curves_tests = {
    'fake_hash': ['full-test'],
    'test_postake_snarkless': simple_tests,
    'test_postake_split_snarkless': integration_tests,
    'test_postake_split': ['coda-shared-prefix-multiproposer-test -num-proposers 2'],
    'test_postake': simple_tests,
    'test_postake_catchup': ['coda-restart-node-test'],
    'test_postake_bootstrap': ['coda-bootstrap-test', 'coda-long-fork -num-proposers 2'],
    'test_postake_three_proposers': ['coda-txns-and-restart-non-proposers'],    
    'test_postake_holy_grail': ['coda-restarts-and-txns-holy-grail -num-proposers 5', 'coda-long-fork -num-proposers 5'],
    'test_postake_delegation': ['coda-delegation-test'],
    'test_postake_txns': ['coda-shared-state-test', 'coda-batch-payment-test'],
    'test_postake_five_even_snarkless': ['coda-shared-prefix-multiproposer-test -num-proposers 5'],
    'test_postake_five_even_txns': ['coda-shared-prefix-multiproposer-test -num-proposers 5 -payments'],
}

medium_curves_tests = {
    'test_postake_medium_curves': simple_tests,
    'test_postake_snarkless_medium_curves': simple_tests,
    'test_postake_split_snarkless_medium_curves': integration_tests,
    'test_postake_split_medium_curves': ['coda-shared-prefix-multiproposer-test -num-proposers 2'],
    'test_postake_delegation_medium_curves': ['coda-delegation-test'],
    'test_postake_txns_medium_curves': ['coda-shared-state-test', 'coda-batch-payment-test'],
}

medium_curve_profiles_full = [
    'test_postake_medium_curves',
    'testnet_postake_medium_curves',
    'testnet_postake_many_proposers_medium_curves']

ci_blacklist = []

# of all the generated CI jobs, allow these specific ones to fail (extra blacklist on top of ci_blacklist)
required_blacklist = [
    'test_postake_five_even_snarkless:*',
    'test_postake_holy_grail:*',
    'test_postake_catchup:*',
]

# these extra jobs are not filters, they are full status check names
extra_required_status_checks = [
    "ci/circleci: lint",
    "ci/circleci: tracetool",
    # "ci/circleci: build-wallet",
]

# these are full status check names. they will not be required to succeed.
not_required_status_checks = [
    "ci/circleci: build-macos",
    "ci/circleci: build-wallet",
]


def fail(msg):
    print('ERROR: %s' % msg)
    exit(1)

def fail_with_log(msg, log):
    with open(log, 'r') as file:
        print(file.read())
    fail(msg)

def test_pattern(pattern, string):
    return (pattern and (pattern == '*' or pattern == string))

def parse_filter(pattern_src):
    if not(pattern_src):
        return (None, None)
    elif pattern_src == '*':
        return ('*', '*')
    else:
        parts = pattern_src.split(':')
        if len(parts) != 2:
            fail('invalid filter syntax')
        [profile, test] = parts
        return (profile, test)

def filter_tests(tests, whitelist_filters, blacklist_filters, permutations=None):
    if permutations is None:
        permutations = tests

    whitelist_patterns = list(map(parse_filter, whitelist_filters))
    blacklist_patterns = list(map(parse_filter, blacklist_filters))

    def keep(profile, test):
        whitelisted = all(
            test_pattern(profile_pat, profile) and test_pattern(test_pat, test)
            for (profile_pat, test_pat) in whitelist_patterns
        )
        blacklisted = any(
            test_pattern(profile_pat, profile) and test_pattern(test_pat, test)
            for (profile_pat, test_pat) in blacklist_patterns
        )
        return whitelisted and not(blacklisted)

    result = collections.defaultdict(list)
    for (profile,tests) in permutations.items():
        for test in tests:
            if keep(profile, test):
                result[profile].append(test)
    return result

def run(args):
    # wraps a "wet" action, printing if dry run is set, executing otherwise
    def wet(msg, f):
        if args.dry_run:
            print(msg)
        else:
            f()

    def run_cmd(cmd, on_failure):
        def do():
            if subprocess.call(['bash', '-c', cmd], stdout=sys.stdout, stderr=sys.stderr) != 0:
                on_failure()
        wet('$ ' + cmd, do)


    logproc_filter = '.level in ["Warn", "Error", "Fatal", "Faulty_peer"]'
    coda_build_path = './_build/default'

    coda_app_path = 'app' if os.path.exists('dune-project') else 'src/app'
    coda_exe_path = os.path.join(coda_app_path, 'cli/src/coda.exe')
    coda_exe = os.path.join(coda_build_path, coda_exe_path)

    with open(os.devnull, 'w') as null:
        if subprocess.call(['which', 'logproc'], stdout=null, stderr=null) == 0:
            logproc_exe = 'logproc'
            build_targets = coda_exe
        else:
            logproc_exe_path = os.path.join(coda_app_path, 'logproc/logproc.exe')
            logproc_exe = os.path.join(coda_build_path, logproc_exe_path)
            build_targets = '%s %s' % (coda_exe, logproc_exe)

    all_tests = small_curves_tests
    all_tests.update(medium_curves_tests)
    all_tests = filter_tests(all_tests, args.whitelist_patterns, args.blacklist_patterns)
    if len(all_tests) == 0:
        # TODO: support direct test dispatching
        if args.whitelist_patterns != ['*']:
            fail('no tests were selected -- whitelist pattern did not match any known tests')
        else:
            fail('no tests were selected -- blacklist is too restrictive')

    print('Preparing to run the following tests:')
    for (profile, tests) in all_tests.items():
        print('- %s:' % profile)
        for test in tests:
            print('  - %s' % test)

    timestamp = int(time.time())
    print('======================================')
    print('============= %d =============' % timestamp)
    print('======================================')

    log_dir = os.path.join('test_logs', str(timestamp))
    def make_log_dir():
        if os.path.exists(log_dir):
            fail('test log directory already exists -- how???')
        os.makedirs(log_dir)
    wet('make new directory: ' + log_dir, make_log_dir)

    for profile in all_tests.keys():
        profile_dir = os.path.join(log_dir, profile)
        wet('make directory: ' + profile_dir, lambda: os.mkdir(profile_dir))

        print('- %s:' % profile)
        build_log = os.path.join(profile_dir, 'build.log')
        run_cmd(
            'dune build --display=progress --profile=%s %s 2> %s'
                % (profile, build_targets, build_log),
            lambda: fail_with_log('building %s failed' % profile, build_log)
        )

        for test in all_tests[profile]:
            print('  - %s' % test)
            log = os.path.join(profile_dir, '%s.log' % test)
            cmd = 'set -o pipefail && %s integration-test %s 2>&1 ' % (coda_exe, test)
            cmd += '| tee \'%s\' | %s -f \'%s\' ' % (log, logproc_exe, logproc_filter)
            print('Running: %s' % (cmd))
            run_cmd(cmd, lambda: fail('Test "%s:%s" failed' % (profile, test)))

    print('Testing successful')


def get_required_status():
    tests = filter_tests(small_curves_tests, ['*'], required_blacklist, permutations=filter_tests(small_curves_tests, ['*'], ci_blacklist))
    return list(filter(lambda el: el not in not_required_status_checks,
            chain(
            ("ci/circleci: %s" % job for job in
                chain(("test--%s" % profile for profile in tests.keys()),
                      ("test-unit--%s" % profile for profile in unit_test_profiles),
                      ("build-artifacts--%s" % profile for profile in build_artifact_profiles))),
            extra_required_status_checks
             )))


def required_status(args):
    print('\n'.join(get_required_status()))

def render(args):
    circle_ci_conf_dir = os.path.dirname(args.circle_jinja_file)
    jinja_file_basename = os.path.basename(args.circle_jinja_file)
    (output_file, ext) = os.path.splitext(args.circle_jinja_file)
    assert ext == '.jinja'

    tests = filter_tests(small_curves_tests, ['*'], ci_blacklist)

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(circle_ci_conf_dir), autoescape=False)
    template = env.get_template(jinja_file_basename)
    rendered = template.render(
        build_artifact_profiles=build_artifact_profiles,
        unit_test_profiles=unit_test_profiles,
        unit_test_profiles_medium_curves=unit_test_profiles_medium_curves,
        small_curves_tests=tests,
        medium_curves_tests=medium_curves_tests,
        medium_curve_profiles=medium_curve_profiles_full
    )

    if args.check:
        with open(output_file, 'r') as file:
            if file.read() != rendered:
                fail('circle CI configuration is out of date, re-render it')
    else:
        with open(output_file, 'w') as file:
            file.write(rendered)

    # now for mergify!
    mergify_conf_dir = os.path.dirname(args.mergify_jinja_file)
    jinja_file_basename = os.path.basename(args.mergify_jinja_file)
    (output_file, ext) = os.path.splitext(args.mergify_jinja_file)
    assert ext == '.jinja'

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(mergify_conf_dir), autoescape=False)
    template = env.get_template(jinja_file_basename)

    rendered = template.render(
        required_status=get_required_status()
    )

    if args.check:
        with open(output_file, 'r') as file:
            if file.read() != rendered:
                fail('mergify configuration is out of date, re-render it')
    else:
        with open(output_file, 'w') as file:
            file.write(rendered)

def list_tests(_args):
    all_tests = small_curves_tests
    all_tests.update(medium_curves_tests)
    for profile in all_tests.keys():
        print('- ' + profile)
        for test in small_curves_tests[profile]:
            print('  - ' + test)

def main():
    actions = {
        'run': run,
        'render': render,
        'list': list_tests,
        'required-status': required_status
    }

    root_parser = argparse.ArgumentParser(description='Coda integration test runner/configurator.')
    subparsers = root_parser.add_subparsers(help='subcommands')

    run_parser = subparsers.add_parser(
        'run',
        description='''
            Build and run integration tests. Filters can be provided for
            selecting tests. Filters are specified in the form
            "<profile>:<test>". On either side, a "*" may be provided as
            a wildcard. For shorthand, a filter of "*" expands to "*:*".
        '''
    )
    run_parser.set_defaults(action='run')
    run_parser.add_argument(
        '-d', '--dry-run',
        action='store_true',
        help='Do not perform any side effects, only print what the program would do.'
    )
    run_parser.add_argument(
        '-b', '--blacklist-pattern',
        action='append', type=str, default=[], dest='blacklist_patterns',
        help='''
            Specify a pattern of tests to exclude from running. This flag can be
            provided multiple times to specify a series of patterns'
        '''
    )
    run_parser.add_argument(
        'whitelist_patterns',
        nargs='*', type=str, default=['*'],
        help='The pattern(s) of tests you want to run. Defaults to "*".'
    )

    render_parser = subparsers.add_parser('render', description='Render circle CI configuration.')
    render_parser.set_defaults(action='render')
    render_parser.add_argument(
        '-c', '--check',
        action='store_true',
        help='Check that CI configuration was rendered properly.'
    )
    render_parser.add_argument('circle_jinja_file')
    render_parser.add_argument('mergify_jinja_file')

    list_parser = subparsers.add_parser('list', description='List available tests.')
    list_parser.set_defaults(action='list')

    required_status_parser = subparsers.add_parser('required-status', description='Print required status checks')
    required_status_parser.set_defaults(action='required-status')

    args = root_parser.parse_args()
    if not(hasattr(args, 'action')):
        print('Unrecognized action')
        root_parser.print_help()
        exit(1)
    actions[args.action](args)

if __name__ == "__main__":
    main()
