#!/usr/bin/python

"""Parse build logs and report on warn conditions"""

import fileinput
import collections
errorcodes = {
    '6':     'label key was omitted in the application of this function.',
    '9':     'the following labels are not bound in this record pattern',
    '27':    'unused variable',
    '32':    'unused value',
    '33':    'unused open',
    '34':    'unused type',
    '35':    'unused for-loop index',
    '37':    'unused constructor',
    '39':    'unused rec flag.',
    '58':    'no cmx file was found in path for module',
    'total': 'total'
}
# init data sets
perfile = collections.Counter()
percode = collections.Counter()
fulldata = {}

# parse the log
lastline = ''  # init
for line in fileinput.input():
    if 'Warning' in line:
        code=line.split()[1].replace(':','')
        percode[code] += 1
        percode['total'] += 1
        try:
            myfile = lastline.split('"')[1]
        except:
            # Cannot parse line
            continue
        perfile[myfile] += 1
        if myfile not in fulldata:  # init
            fulldata[myfile] = collections.Counter()
        fulldata[myfile][code] += 1
        fulldata[myfile]['total'] += 1
    lastline=line

print '=' * 80
print 'Warnings by type/code'
for key, value in sorted(percode.iteritems(), reverse=True, key=lambda (k,v): (v,k)):
    try:
        print percode[key] , errorcodes[key]
    except KeyError:
        continue
print '=' * 80
print 'Warnings by file'
for key, value in sorted(perfile.iteritems(), reverse=True, key=lambda (k,v): (v,k)):
    print value, key

print '=' * 80
print 'Warnings detail per file'
# Walk per file again, but read from full data
for key, value in sorted(perfile.iteritems(), reverse=True, key=lambda (k,v): (v,k)):
    print '-'*80
    print key
    for k in fulldata[key]:
        if k is not 'total':
            print "\t", fulldata[key][k], errorcodes[k]
    print "\t", fulldata[key]['total'], 'total'
