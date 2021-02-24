#!/usr/bin/env python3

from glob import glob
import json
import os
import sys
import requests
from socket import gethostname
import hashlib
import re

# Authentication for user filing issue
USE_GITHUB = True
try:
    USERNAME = os.environ['GITHUB_USER']
except KeyError:
    print('WARN: Environent variable GITHUB_USER unset -- cannot write to github.')
    USE_GITHUB = False
try:
    # Use a developer token if you have 2FA
    PASSWORD = os.environ['GITHUB_PASSWORD']
except KeyError:
    print('WARN: Environent variable GITHUB_PASSWORD unset -- cannot write to github.')
    USE_GITHUB = False

# The repository to add this issue to
REPO_OWNER = 'CodaProtocol'
REPO_NAME = 'coda'


""" Mask out actual line numbers and collumns, generate a signature based on stripped data """


def error_sig(string):
    output = ''
    for line in string.splitlines(True):
        if 'Called' in line or 'Raised' in line:
            line = re.sub("line (\d+), characters (\d+)-(\d+)",
                          "line HIDDEN, characters HIDDEN", line)
        output += line
    sig = hashlib.md5(output.encode('utf-8')).hexdigest()
    return(sig)


def make_github_issue(title, body=None, labels=None):
    '''Create an issue on github.com using the given parameters.'''
    # Our url to create issues via POST
    url = 'https://api.github.com/repos/%s/%s/issues' % (REPO_OWNER, REPO_NAME)
    # Create an authenticated session to create the issue
    session = requests.Session()
    session.auth = (USERNAME, PASSWORD)
    # Create our issue
    issue = {'title': title,
             'body': body,
             'labels': labels}
    # Add the issue to our repository
    r = session.post(url, json.dumps(issue))
    if r.status_code == 201:
        print ('Successfully created Issue {0:s}'.format(title))
        data = r.json()
        print ('URL: %s' % data['html_url'])
    else:
        print ('Could not create Issue {0:s}'.format(title))
        print ('Response:', r.content)


def yes_or_no(question):
    while "the answer is invalid":
        try:
            reply = str(input(question+' (y/n)[default: n]: ')).lower().strip()
        except KeyboardInterrupt:
            print('\nExiting')
            sys.exit(1)
        if len(reply) < 1:
            return False
        elif reply[0] == 'y':
            return True
        elif reply[0] == 'n':
            return False


if __name__ == "__main__":
    crashdirs = glob('test-coda-CRASH-*/coda.log')

    seen_exns = []
    for crashdir in crashdirs:
        with open(crashdir, encoding="ISO-8859-1") as fp:
            for count, line in enumerate(fp):
                if 'Fatal' in line:
                    data = json.loads(line)
                    try:
                        exn_1000 = "".join(
                            data['metadata']['exn'].splitlines())[:1000]
                        exn = exn_1000[:130] + '...'
                    except KeyError:
                        exn = 'Unknown'

                    if exn in seen_exns:
                        # Duplicate
                        continue
                    else:
                        seen_exns.append(exn)

                    print('-'*80)
                    print(crashdir)
                    print('New: %s' % exn)
                    body = 'Details:\n\n'
                    body += 'Hash: %s\n' % error_sig(exn)
                    body += 'Crash Timestamp: %s\n' % data['timestamp']
                    body += 'Host: `%s`\n\n' % gethostname()
                    body += 'Partial trace:\n'
                    body += '```\n'
                    body += exn_1000.replace('    ', '\n')
                    body += '...'
                    body += '\n```'
                    print(body)

                    if sys.stdin.isatty():
                        # running interactively
                        if yes_or_no('Create new issue?'):
                            # FIXME - how to attach gz to issue.
                            title = 'TESTING - CRASH - TESTNET - %s' % exn.strip()
                            if USE_GITHUB:
                                make_github_issue(title=title,
                                                  body=body,
                                                  labels=['testnet', 'robot'])
                    else:
                        print('Running non-interactively.')
