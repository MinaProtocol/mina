#!/usr/bin/python

import jinja2

tests = [
  'unit_tests',
  'all_sig_integration_tests',
  'all_stake_integration_tests'
]

# Render it
env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
template = env.get_template('./config.yml.jinja')
rendered = template.render(tests=tests)
print(rendered)
