#!/usr/bin/python

import jinja2

tests = []

test_names= [
    'full-test',
    'coda-peers-test',
    'coda-transitive-peers-test',
    'coda-block-production-test',
    'coda-shared-state-test',
    'coda-shared-prefix-test -who-proposes 0',
    'coda-shared-prefix-test -who-proposes 1',
    'transaction-snark-profiler -check-only'
    ]

mechanisms = [ 
    '',
    'proof_of_signature'
    ]

# Build list
for mechanism in mechanisms:
    for name in test_names:    
        friendly = name.replace(' ','') + '-' + mechanism
        test_detail = dict(
            friendly=friendly, 
            name=name,
            mechanism=mechanism)
        tests.append(test_detail)    

# Render it
loader = jinja2.FileSystemLoader('./config.yml.jinja')
env = jinja2.Environment(loader=loader)
template = env.get_template('')
print(template.render(tests=tests))
