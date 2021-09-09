#!/usr/bin/env python

import subprocess
import sys
import os
import jinja2
from datetime import datetime

def generate ():
    jinja_file = sys.argv[1]
    conf_dir = os.path.dirname(jinja_file)
    jinja_file_basename = os.path.basename(jinja_file)
    (output_file, ext) = os.path.splitext(jinja_file)
    assert ext == '.jinja'

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(conf_dir), autoescape=False)

    output = subprocess.check_output(['coda', 'advanced', 'dump-ledger', '-json'])

    accounts=output.split('\n')
    accounts=map(lambda acct: '\"' + acct.replace('\"','\\"') + '\"',accounts)

    now=str(datetime.now ())
    
    template = env.get_template(jinja_file_basename)
    rendered = template.render(accounts=accounts,now=now)

    print(rendered)

if __name__ == "__main__":
    generate()
