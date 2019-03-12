#!/usr/bin/python

import argparse
import jinja2
import os

build_artifact_profiles = [
    'dev',
    'testnet_posig',
    'testnet_postake',
    'testnet_public',
    'testnet_postake_snarkless_fake_hash'
]

simple_tests = [
    'full-test',
    'transaction-snark-profiler -check-only',
]

integration_tests = [
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-prefix-test -who-proposes 0',
    'coda-shared-prefix-test -who-proposes 1',
    'coda-shared-state-test',
    # FAILING 'coda-restart-node-test',
]

all_tests = simple_tests + integration_tests

test_permutations = {
    'fake_hash': ['full-test'],
    'test_posig_snarkless': all_tests,
    'test_postake_snarkless': simple_tests,
    'test_postake_split_snarkless': integration_tests,
    'test_posig': simple_tests,
    'test_postake': simple_tests,
}

ci_blacklist = [
    '*:coda-restart-node-test'
]

def fail(msg):
    print('ERROR: %s' % msg)
    exit(1)

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

def filter_test_permutations(whitelist_filters, blacklist_filters):
    whitelist_patterns = [parse_filter(filter) for filter in whitelist_filters]
    blacklist_patterns = [parse_filter(filter) for filter in blacklist_filters]

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

    # too complex to represent as a list expression in python
    result = {}
    for (profile,tests) in test_permutations.items():
        for test in tests:
            if keep(profile, test):
                result[profile] = result[profile] if profile in result else []
                result[profile].append(test)
    return result

def run(args):
    test_permutations = filter_test_permutations([args.test_pattern], [args.blacklist_pattern])

    def run_cmd(ctx, cmd):
        if args.dry_run:
            print(cmd)
        else:
            if os.system(cmd) != 0:
                fail('%s failed' % ctx)

    coda_exe_path = 'src/app/cli/src/coda.exe'
    coda_build_path = './_build/default'
    coda_exe = os.path.join(coda_build_path, coda_exe_path)

    for profile in test_permutations.keys():
        run_cmd('building profile %s' % profile, 'dune build --profile=%s %s' % (profile, coda_exe_path))
        for test in test_permutations[profile]:
            run_cmd('running test %s:%s' % (profile, test), '%s integration-test %s' % (coda_exe, test))

    print('all tests ran successfully')

def render(args):
    circle_ci_conf_dir = os.path.dirname(args.jinja_file)
    jinja_file_basename = os.path.basename(args.jinja_file)
    (output_file, ext) = os.path.splitext(args.jinja_file)
    assert ext == '.jinja'

    test_permutations = filter_test_permutations(['*'], ci_blacklist)

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(circle_ci_conf_dir))
    template = env.get_template(jinja_file_basename)
    rendered = template.render(
        build_artifact_profiles=build_artifact_profiles,
        test_permutations=test_permutations
    )

    output_file = open(output_file, 'w')
    output_file.write(rendered)
    output_file.close()

def main():
    actions = {
        'run': run,
        'render': render
    }

    root_parser = argparse.ArgumentParser(description='Coda integration test runner/configurator')
    subparsers = root_parser.add_subparsers(help='command help')

    run_parser = subparsers.add_parser('run', help='run help')
    run_parser.set_defaults(action='run')
    run_parser.add_argument('-d', '--dry-run', action='store_true')
    run_parser.add_argument('-b', '--blacklist-pattern', type=str)
    run_parser.add_argument('test_pattern', nargs='?', type=str, default='*')

    render_parser = subparsers.add_parser('render', help='render help')
    render_parser.set_defaults(action='render')
    render_parser.add_argument('jinja_file')

    args = root_parser.parse_args()
    if not(hasattr(args, 'action')):
        print('Unrecognized action')
        root_parser.print_help()
        exit(1)
    actions[args.action](args)

main()
