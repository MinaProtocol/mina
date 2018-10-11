#!/usr/bin/python

import jinja2

test_names= [
  'full-tests',
  'coda-peers-test',
  'coda-transitive-peers-test',
  'coda-block-production-test',
  'coda-shared-prefix-test -who-proposes 0',
  'coda-shared-prefix-test -who-proposes 1',
  'coda-shared-state-test',
  'coda-restart-node-test',
  'transaction-snark-profiler -check-only',
]

mechanisms = [ 
    'proof_of_signature'
    ]

def make_tests():
    tests = []

    for mechanism in mechanisms:
        for name in test_names:    
            friendly = name + ' | ' + mechanism
            test_detail = dict(
                friendly=friendly, 
                name=name,
                mechanism=mechanism)
            tests.append(test_detail)    
    return tests

# Render it
env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
template = env.get_template('./config.yml.jinja')
rendered = template.render(tests=make_tests())
print(rendered)
