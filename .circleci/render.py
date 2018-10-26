#!/usr/bin/python

import jinja2

base_actions = [
    'full-test',
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-prefix-test -who-proposes 0 -proposal-interval 8000',
    'coda-shared-prefix-test -who-proposes 1 -proposal-interval 8000',
    'coda-shared-state-test -proposal-interval 6000',
    'coda-restart-node-test -proposal-interval 6000',
    'transaction-snark-profiler -check-only'
]

tests = [
   {'friendly': 'Sig Tests', 'name': 'all_sig_integration_tests', 'env_str': "CODA_CONSENSUS_MECHANISM=proof_of_signature CODA_PROPOSAL_INTERVAL=1000", 'actions': base_actions},
   {'friendly': 'Stake Tests', 'name': 'all_stake_integration_tests', 'env_str': "CODA_CONSENSUS_MECHANISM=proof_of_stake CODA_SLOT_INTERVAL=1000 CODA_UNFORKABLE_TRANSITION_COUNT=24 CODA_PROBABLE_SLOTS_PER_TRANSITION_COUNT=8", 'actions': base_actions}
]

# Render it
env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
template = env.get_template('./config.yml.jinja')
rendered = template.render(tests=tests)
print(rendered)
