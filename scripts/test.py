#!/usr/bin/env python

import argparse
import collections
import jinja2
import os
import re
import shutil
import subprocess
import sys
import time
from glob import glob
from itertools import chain
from readchar import readchar


#################
# CONFIGURATION #
#################


build_artifact_profiles = [
    'testnet_postake_medium_curves'
]

unit_test_profiles = ['dev']

unit_test_profiles_medium_curves = ['dev_medium_curves']

simple_tests = [
    'full-test',
    'transaction-snark-profiler -k 2',
]

integration_tests = [
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-prefix-test -who-produces 0',
    'coda-shared-prefix-test -who-produces 1',
    'coda-change-snark-worker-test',
    'coda-archive-node-test'
]

all_tests = simple_tests + integration_tests

compile_config_agnostic_tests = [
    'coda-bootstrap-test',
    'coda-shared-state-test',
    'coda-batch-payment-test',
]

compile_config_agnostic_profiles = [
    'dev'
]

required_config_agnostic_tests = {
    'dev': [
        'coda-bootstrap-test',
        'coda-shared-state-test',
        'coda-batch-payment-test',
      ]
}

# dictionary mapping configs to lists of tests
small_curves_tests = {
    'fake_hash': ['full-test'],
    'test_postake_snarkless':
    simple_tests,
    'test_postake_split_snarkless':
    integration_tests,
    'test_postake_split':
    ['coda-shared-prefix-multiproducer-test -num-block-producers 2'],
    'test_postake':
    simple_tests,
    'test_postake_catchup': ['coda-restart-node-test'],
    'test_postake_three_producers': ['coda-txns-and-restart-non-producers'],
    'test_postake_delegation': ['coda-delegation-test'],
    'test_postake_five_even_txns':
    ['coda-shared-prefix-multiproducer-test -num-block-producers 5 -payments'],
}

medium_curves_and_other_tests = {
    'test_postake_medium_curves':
    simple_tests,
    'test_postake_snarkless_medium_curves':
    simple_tests,
    'test_postake_split_medium_curves':
    ['coda-shared-prefix-multiproducer-test -num-block-producers 2'],
    'test_postake_full_epoch': ['full-test'],
}

archive_processor_test = {
    'test_archive_processor': ['coda-archive-processor-test'],
}

medium_curve_profiles_full = [
    'test_postake_medium_curves', 'testnet_postake_medium_curves',
    'testnet_postake_many_producers_medium_curves'
]

ci_excludes = [
    "ci/circleci: lint-opt",
]

# of all the generated CI jobs, allow these specific ones to fail (extra excludes on top of ci_excludes)
required_excludes = [
    'test_postake_catchup:*',
    'test_postake_three_producers:*',
    'test_postake_split_snarkless:*'
]

# these extra jobs are not filters, they are full status check names
extra_required_status_checks = [
    "ci/circleci: lint",
    "ci/circleci: tracetool",
    "ci/circleci: build-wallet",
    "ci/circleci: compare-test-signatures",
    "ci/circleci: build-client-sdk",
    "ci/circleci: test-unit--nonconsensus_medium_curves",
]

# these are full status check names. they will not be required to succeed.
not_required_status_checks = [
    "ci/circleci: build-macos",
]


#########
# UTILS #
#########


def panic(msg):
    print('ERROR: %s' % msg)
    exit(1)


class TempWorkingDirectory:
    def __init__(self, path):
        self.path = path
        self.prev_path = None

    def __enter__(self):
        if self.prev_path:
            panic('cannot enter TempWorkingDirectory in a nested fashion')
        self.prev_path = os.getcwd()
        os.chdir(self.path)

    def __exit__(self, type, value, tb):
        if not self.prev_path:
            panic('cannot exit TempWorkingDirectory that has not been entered')
        os.chdir(self.prev_path)
        self.prev_path = None
        return False


def relative_glob(root_dir, pattern):
    with TempWorkingDirectory(root_dir):
        return glob(pattern)


###############################
# TEST PATTERNS AND FILTERING #
###############################


def test_pattern(pattern, string):
    return (pattern and (pattern == '*' or pattern == string))


def parse_filter(pattern_src):
    if not (pattern_src):
        return (None, None)
    elif pattern_src == '*':
        return ('*', '*')
    else:
        parts = pattern_src.split(':')
        if len(parts) != 2:
            panic('invalid filter syntax')
        [profile, test] = parts
        return (profile, test)


def filter_tests(tests,
                 includes_filters,
                 excludes_filters,
                 permutations=None):
    if permutations is None:
        permutations = tests

    includes_patterns = list(map(parse_filter, includes_filters))
    excludes_patterns = list(map(parse_filter, excludes_filters))

    def keep(profile, test):
        included = all(
            test_pattern(profile_pat, profile)
            and test_pattern(test_pat, test)
            for (profile_pat, test_pat) in includes_patterns)
        excluded = any(
            test_pattern(profile_pat, profile)
            and test_pattern(test_pat, test)
            for (profile_pat, test_pat) in excludes_patterns)
        return included and not excluded

    result = collections.defaultdict(list)
    for (profile, tests) in permutations.items():
        for test in tests:
            if keep(profile, test):
                result[profile].append(test)
    return result


#######################
# ARTIFACT COLLECTION #
#######################


class ArtifactCollector:
    def __init__(self, root_dir, context):
        self.root_dir = root_dir
        self.context = context

    def resolve_source_path(self, path):
        return os.path.join(self.root_dir, path)

    def decorate_target_path(self, target_path):
        dirname = os.path.dirname(target_path)
        old_basename = os.path.basename(target_path)
        new_basename = '%s--%s' % (self.context, target_path)
        return os.path.join(dirname, new_basename)


class SingleArtifactCollector(ArtifactCollector):
    def __init__(self, root_dir, context, src_name, dst_name=None):
        ArtifactCollector.__init__(self, root_dir, context)
        self.src_name = src_name
        self.dst_name = dst_name

    def collect(self, destination):
        src = self.resolve_source_path(self.src_name)
        dst_name = self.dst_name if self.dst_name else os.path.basename(self.src_name)
        shutil.copyfile(src, os.path.join(destination, self.decorate_target_path(dst_name)))


class BatchArtifactCollector(ArtifactCollector):
    def __init__(self, root_dir, context, pattern):
        ArtifactCollector.__init__(self, root_dir, context)
        self.pattern = pattern

    def collect(self, destination):
        for artifact in relative_glob(self.root_dir, self.pattern):
            name = self.decorate_target_path(artifact.replace('/', '--'))
            location = os.path.join(self.root_dir, artifact)
            shutil.copyfile(location, os.path.join(destination, name))


#############
# EXECUTIVE #
#############


# The Executive oversees the execution of the integration test runner,
# providing a single layer where we implement the logic for how to
# execute a test in adherence with arguments provided from the CLI.
class Executive:
    def __init__(self, args, artifact_directory):
        self.is_dry = args.dry_run
        self.non_interactive = args.non_interactive
        self.force_yes = args.yes
        self.should_collect_artifacts = args.collect_artifacts
        self.artifact_directory = artifact_directory
        self.artifact_collectors = []

    def do(self, name, f):
        if self.is_dry:
            print(name)
        else:
            f()

    def run_cmd(self, cmd, directory='.', log=None):
        def action():
            with TempWorkingDirectory(directory):
                if subprocess.call(['bash', '-c', cmd], stdout=sys.stdout, stderr=sys.stderr) != 0:
                    if log:
                        with open(log, 'r') as file:
                            lines = file.readlines()
                            for line in lines[-200:]:
                                sys.stdout.write(line)
                    self.fail('command failed: %s' % cmd)
        self.do('$ %s' % cmd, action)

    def prompt(self, msg, default):
        if self.force_yes:
            return True
        elif self.non_interactive:
            return default
        else:
            while True:
                sys.stdout.write('%s [y/n] ' % msg)
                sys.stdout.flush()
                c = readchar()
                print()
                if c == 'y' or c == 'Y':
                    return True
                elif c == 'n' or c == 'N':
                    return False
                else:
                    print('  invalid input')

    def reserve_file(self, path):
        if os.path.exists(path):
            if self.prompt('"%s" already exits. Should it be overwritten?' % path, False):
                self.remove_directory(path, 'old test logs')
            else:
                self.fail('Refusing to overwrite "%s"' % path)

    def remove_directory(self, directory, context=None):
        if context:
            context += ' '
        self.do('remove %sdirectory' % context, lambda: os.remove(directory) if os.path.exists(directory) else None)

    def make_directory(self, directory, context=None):
        if context:
            context += ' '
        self.do('make %sdirectory' % context, lambda: os.makedirs(directory) if not os.path.exists(directory) else None)

    def register_artifact_collector(self, collector):
        self.artifact_collectors.append(collector)

    def collect_artifacts(self):
        def action():
            for collector in self.artifact_collectors:
                collector.collect(self.artifact_directory)
        if self.should_collect_artifacts:
            self.do('collect artifacts', action)

    def fail(self, msg):
        self.collect_artifacts()
        panic(msg)


################
# CODA PROJECT #
################

# A CodaProject is a thin wrapper around interacting the Coda source code.
# It is responsible for dispatching builds and tests.
class CodaProject:
    logproc_exe_path = 'src/app/logproc/logproc.exe'
    coda_exe_path = 'src/app/cli/src/coda.exe'

    def __init__(self, executive, root='.'):
        self.executive = executive
        self.root = root
        self.build_path = os.path.join(root, '_build/default')
        self.current_profile = None

    def build(self, build_log, profile='dev'):
        cmd = 'dune build --display=progress --profile=%s %s %s 2> %s' % (profile, self.coda_exe_path, self.logproc_exe_path, build_log)
        self.executive.run_cmd(cmd, directory=self.root, log=build_log)
        self.current_profile = profile

    def no_build(self, profile='dev'):
        print('Skipping build')
        self.current_profile = profile


    def run_test(self, test, test_log):
        if self.current_profile == None:
            self.executive.fail('run_test initiated without building')

        cmd_template = (
            'set -o pipefail '
            '&& {{coda}} integration-test {{test}} 2>&1 '
            '| tee \'{{log}}\' '
            '| {{logproc}} -f \'.level in ["Warn", "Error", "Fatal", "Faulty_peer"]\''
        )
        cmd = jinja2.Template(cmd_template).render(
            log=test_log,
            coda=self.coda_exe(),
            logproc=self.logproc_exe(),
            test=test
        )
        self.executive.run_cmd(cmd, log=test_log)

    def coda_exe(self):
        return os.path.join(self.build_path, self.coda_exe_path)

    def logproc_exe(self):
        return os.path.join(self.build_path, self.logproc_exe_path)


###########
# ACTIONS #
###########


# Initializes and maps the output directory structure for running tests.
class OutDirectory:
    def __init__(self, root):
        self.root = root
        self.build_logs = os.path.join(self.root, 'build_logs')
        self.test_logs = os.path.join(self.root, 'test_logs')
        self.test_configs = os.path.join(self.root, 'test_configs')
        self.artifacts = os.path.join(self.root, 'artifacts')
        self.all_directories = [
            self.root,
            self.build_logs,
            self.test_logs,
            self.test_configs,
            self.artifacts
        ]

    def initialize(self, executive):
        for dir in self.all_directories:
            executive.make_directory(dir)


def run(args):
    all_tests = small_curves_tests
    all_tests.update(medium_curves_and_other_tests)
    all_tests.update(archive_processor_test)
    all_tests.update({profile:compile_config_agnostic_tests
                      for profile in compile_config_agnostic_profiles})
    all_tests = filter_tests(all_tests, args.includes_patterns, args.excludes_patterns)
    if len(all_tests) == 0:
        if args.includes_patterns != ['*']:
            panic('no tests were selected -- includes pattern did not match any known tests')
        else:
            panic('no tests were selected -- excludes is too restrictive')

    out_dir = OutDirectory(args.out_dir)
    executive = Executive(args, out_dir.artifacts)
    project = CodaProject(executive)
    out_dir.initialize(executive)
    os.environ['CODA_INTEGRATION_TEST_DIR'] = os.path.join(os.getcwd(), out_dir.test_configs)

    print('Preparing to run the following tests:')
    for (profile, tests) in all_tests.items():
        print('- %s:' % profile)
        for test in tests:
            print('  - %s' % test)
    print('======================================')
    print('============= %d =============' % int(time.time()))
    print('======================================')

    for profile in all_tests.keys():
        print('- %s:' % profile)
        if args.no_build:
            project.no_build(profile)
        else:
            build_log_name = '%s.log' % profile
            build_log = os.path.join(out_dir.build_logs, build_log_name)
            executive.reserve_file(build_log)
            executive.register_artifact_collector(SingleArtifactCollector(out_dir.build_logs, 'build', build_log_name))
            project.build(build_log, profile)

        for test in all_tests[profile]:
            print('  - %s' % test)
            test_log_name = '%s--%s.log' % (profile, test)
            test_log = os.path.join(out_dir.test_logs, test_log_name)
            executive.reserve_file(test_log)
            executive.register_artifact_collector(SingleArtifactCollector(out_dir.test_logs, 'test-main', test_log_name))
            executive.register_artifact_collector(BatchArtifactCollector(out_dir.test_configs, 'test-node--%s--%s' % (profile, test), '**/*.log'))
            project.run_test(test, test_log)

    executive.collect_artifacts()
    print('Testing successful')


def get_required_status():
    tests = filter_tests(small_curves_tests, ['*'],
                         required_excludes,
                         permutations=filter_tests(small_curves_tests, ['*'],
                                                   ci_excludes))
    return list(
        filter(
            lambda el: el not in not_required_status_checks,
            chain(("ci/circleci: %s" % job
                   for job in chain(("test--%s" % profile
                                     for profile in tests.keys()), (
                                         "test-unit--%s" % profile
                                         for profile in unit_test_profiles),
                                    ("build-artifacts--%s" % profile
                                     for profile in build_artifact_profiles),
                                    ("test--%s--%s" % (profile, name)
                                     for profile in required_config_agnostic_tests
                                     for name in required_config_agnostic_tests[profile]))),
                  extra_required_status_checks)))


def required_status(args):
    print('\n'.join(get_required_status()))


def render(args):
    circle_ci_conf_dir = os.path.dirname(args.circle_jinja_file)
    jinja_file_basename = os.path.basename(args.circle_jinja_file)
    (output_file, ext) = os.path.splitext(args.circle_jinja_file)
    assert ext == '.jinja'

    tests = filter_tests(small_curves_tests, ['*'], ci_excludes)

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(circle_ci_conf_dir), autoescape=False)
    template = env.get_template(jinja_file_basename)
    rendered = template.render(
        build_artifact_profiles=build_artifact_profiles,
        unit_test_profiles=unit_test_profiles,
        unit_test_profiles_medium_curves=unit_test_profiles_medium_curves,
        small_curves_tests=tests,
        medium_curves_and_other_tests=medium_curves_and_other_tests,
        medium_curve_profiles=medium_curve_profiles_full,
        compile_config_agnostic_profiles=compile_config_agnostic_profiles,
        compile_config_agnostic_tests=compile_config_agnostic_tests)

    if args.check:
        with open(output_file, 'r') as file:
            if file.read() != rendered:
                panic('circle CI configuration is out of date, re-render it')
    else:
        with open(output_file, 'w') as file:
            file.write(rendered)

    # now for mergify!
    mergify_conf_dir = os.path.dirname(args.mergify_jinja_file)
    jinja_file_basename = os.path.basename(args.mergify_jinja_file)
    (output_file, ext) = os.path.splitext(args.mergify_jinja_file)
    assert ext == '.jinja'

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(mergify_conf_dir),
                             autoescape=False)
    template = env.get_template(jinja_file_basename)

    rendered = template.render(required_status=get_required_status())

    if args.check:
        with open(output_file, 'r') as file:
            if file.read() != rendered:
                panic('mergify configuration is out of date, re-render it')
    else:
        with open(output_file, 'w') as file:
            file.write(rendered)


def list_tests(_args):
    all_tests = small_curves_tests
    all_tests.update(medium_curves_and_other_tests)
    for profile in all_tests.keys():
        print('- ' + profile)
        for test in small_curves_tests[profile]:
            print('  - ' + test)


actions = {
    'run': run,
    'render': render,
    'list': list_tests,
    'required-status': required_status
}


#######
# CLI #
#######


def main():

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
        '--non-interactive',
        action='store_true',
        help='Run in non-interactive mode (make default decisions at interactive prompts).'
    )
    run_parser.add_argument(
        '--yes',
        action='store_true',
        help='Automatically say yes to all interactive prompts.'
    )
    run_parser.add_argument(
        '--out-dir',
        action='store',
        type=str,
        default='test_output',
        help='Set the directory where build logs, test logs, and configs will be stored. Default is "test_output".'
    )
    run_parser.add_argument(
        '--collect-artifacts',
        action='store_true',
        help='Collect test artifacts together (for CI).'
    )
    run_parser.add_argument(
        '-d',
        '--dry-run',
        action='store_true',
        help='Do not perform any side effects, only print what the program would do.'
    )
    run_parser.add_argument(
        '-b',
        '--excludes-pattern',
        action='append',
        type=str,
        default=[],
        dest='excludes_patterns',
        help='''
            Specify a pattern of tests to exclude from running. This flag can be
            provided multiple times to specify a series of patterns'
        '''
    )
    run_parser.add_argument(
        '--no-build',
        action='store_true',
        help='Run tests using an existing built binary.'
    )
    run_parser.add_argument(
        'includes_patterns',
        nargs='*',
        type=str,
        default=['*'],
        help='The pattern(s) of tests you want to run. Defaults to "*".'
    )

    render_parser = subparsers.add_parser(
        'render',
        description='Render circle CI configuration.'
    )
    render_parser.set_defaults(action='render')
    render_parser.add_argument(
        '-c',
        '--check',
        action='store_true',
        help='Check that CI configuration was rendered properly.'
    )
    render_parser.add_argument('circle_jinja_file')
    render_parser.add_argument('mergify_jinja_file')

    list_parser = subparsers.add_parser(
        'list',
        description='List available tests.'
    )
    list_parser.set_defaults(action='list')

    required_status_parser = subparsers.add_parser(
        'required-status',
        description='Print required status checks'
    )
    required_status_parser.set_defaults(action='required-status')

    args = root_parser.parse_args()
    if not (hasattr(args, 'action')):
        print('Unrecognized action')
        root_parser.print_help()
        exit(1)
    actions[args.action](args)


if __name__ == "__main__":
    main()
