#!/usr/bin/python

import jinja2

base_actions = [
    'full-test',
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-prefix-test -who-proposes 0',
    'coda-shared-prefix-test -who-proposes 1',
    'coda-shared-state-test',
    'coda-restart-node-test',
    'transaction-snark-profiler -check-only'
]

build_profiles = [
    'dev',
    'testnet_posig',
    'testnet_postake',
    'testnet_public',
    'testnet_postake_snarkless_fake_hash'
]

tests = [
   {
       'friendly': 'Fake Hash',
       'config': 'fake_hash',
       'name': 'fake_hash_full_test',
       'actions': ['full-test']
   },
   {
       'friendly': 'Proof of Signature Tests',
       'config': 'test_posig_snarkless',
       'name': 'posig_integration_tests',
       'actions': base_actions
   },
   {
       'friendly': 'Proof of Stake Tests',
       'config': 'test_postake_snarkless',
       'name': 'postake_integration_tests',
       'actions': base_actions + ['coda-shared-prefix-multiproposer-test']
   },
   {
       'friendly': 'Full test with SNARK (sig)',
       'config': 'test_posig',
       'name': 'withsnark-sig',
       'actions': ['full-test']
   },
   {
       'friendly': 'Full test with SNARK (stake)',
       'config': 'test_postake',
       'name': 'withsnark-stake',
       'actions': ['full-test']
   }
]

# Render it
env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
template = env.get_template('./config.yml.jinja')
rendered = template.render(tests=tests, build_profiles=build_profiles)
print(rendered)
