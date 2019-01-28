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

tests = [
   {'friendly': 'Fake Hash', 'config':'fake_hash',  'name': 'fake_hash_full_test', 'env_str': "CODA_PROPOSAL_INTERVAL=8000", 'actions': ['full-test']},
   {'friendly': 'Sig Tests', 'config':'test_sigs',  'name': 'all_sig_integration_tests', 'env_str': "CODA_PROPOSAL_INTERVAL=8000", 'actions': base_actions},
   {'friendly': 'Stake Tests', 'config':'test_stakes', 'name': 'all_stake_integration_tests', 'env_str': "CODA_SLOT_INTERVAL=8000 CODA_UNFORKABLE_TRANSITION_COUNT=24 CODA_PROBABLE_SLOTS_PER_TRANSITION_COUNT=8", 'actions': base_actions}
]

# Render it
env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
template = env.get_template('./config.yml.jinja')
rendered = template.render(tests=tests)
print(rendered)
