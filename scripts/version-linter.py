#!/usr/bin/env python3

# version-linter.py -- makes sure serializations of versioned types don't change

"""
For the PR branch, PR base branch, and release branch, download the
type shapes file from Google storage There should be a type shape file
available for every commit in a PR branch.

For each branch, store the type shape information in a Python dictionary.

For each type, compare the type shapes of each branch. If the shapes don't match, print an
error message. The exact comparison rules are given in RFC 0047 (with some embellishments
mentioned below). We print the minimum S-expression depth where the shapes differ.

There are some special rules for the types associated with signed commands and zkApp commands;
see `check_command_types`, below. There is also a special rule for RPC types; see
`check_rpc_types`, below.
"""

import subprocess
import os
import io
import sys
import re
import sexpdata
import requests

exit_code=0

def set_error():
  global exit_code
  exit_code=1

def branch_commit(branch):
  print ('Retrieving', branch, 'head commit...')
  result=subprocess.run(['git','log','-n','1','--format="%h"','--abbrev=7',f'{branch}'],
                        capture_output=True)
  output=result.stdout.decode('ascii')
  print ('command stdout:', output)
  print ('command stderr:', result.stderr.decode('ascii'))
  return output.replace('"','').replace('\n','')

def download_type_shapes(role,branch,sha1) :
  file=type_shape_file(sha1)
  print ('Downloading type shape file',file,'for',role,'branch',branch,'at commit',sha1)
  url = f'https://storage.googleapis.com/mina-type-shapes/{file}'
  r = requests.head(url, allow_redirects=True)
  if r.status_code != 200:
    print ("cannot fetch file reference from non-existing path: ${url}")
    print ("looks like you need to generate it. Please use below steps")
    print (f"git checkout ${sha1}")
    print ("nix develop mina")
    print (f"dune exec src/app/cli/src/mina.exe internal dump-type-shape > ${sha1}-type_shape.txt")
    print ("gsutil cp gs://mina-type-shapes ${sha1}-type_shape.txt ")

    sys.exit(1)

  result=subprocess.run(['wget','--no-clobber',url])

def type_shape_file(sha1) :
  # created by buildkite build-artifact script
  # loaded to cloud bucket
  return sha1 + '-type_shape.txt'

def type_shapes_diff_depth(type_shape1,type_shape2) :

  def find_diff_depth(sexp1,sexp2,curr_depth):
    is_list1 = isinstance(sexp1,list)
    is_list2 = isinstance(sexp2,list)

    if not is_list1 and is_list2:
      return curr_depth

    if is_list1 and not is_list2:
      return curr_depth

    if not is_list1 and not is_list2:
      # both atoms
      if sexp1==sexp2:
        return None
      else:
        return curr_depth

    # lists of unequal length
    if not len(sexp1)==len(sexp2):
      # the difference is inside the lists
      return curr_depth + 1

    # lists, same length
    raw_depths = list(map(lambda sub1, sub2: find_diff_depth(sub1,sub2,curr_depth+1), sexp1, sexp2))
    depths = list(filter(lambda n : not n is None,raw_depths))

    if depths==[]:
      return None
    else:
      return min(depths)

  sexp1=sexpdata.loads(type_shape1)
  sexp2=sexpdata.loads(type_shape2)

  return (find_diff_depth(sexp1,sexp2,0))

def make_type_shape_dict(type_shape_file):
  shape_dict=dict()
  with open(type_shape_file) as file :
    for entry in file :
      if entry=='':
        break
      fields=entry.split(', ')
      path=fields[0]
      digest=fields[1]
      shape=fields[2]
      type_=fields[3]
      shape_dict[path]=[digest,shape,type_]
  return shape_dict

def type_name_from_path(path):
  components=path.split('.')
  return components[len(components)-1]

def module_path_from_path(path):
  # filename.ml:module_path
  components=path.split(':')
  mod_path=components[1].split('.')
  # modules ... Stable.Vn.t
  return mod_path

def is_signed_command_module_path(modpath):
  return (modpath[0]=='Mina_base__Signed_command' and
          modpath[1]=='Make_str' and
          modpath[2]=='Stable' and
          re.match(r'V[0-9]+',modpath[3]) and
          modpath[4]=='t')

def is_zkapp_command_module_path(modpath):
  return (modpath[0]=='Mina_base__Zkapp_command' and
          modpath[1]=='T' and
          modpath[2]=='Stable' and
          re.match(r'V[0-9]+',modpath[3]) and
          modpath[4]=='t')

def check_rpc_types(pr_type_dict,release_branch,release_type_dict) :
  # every query, response type in release still present
  for path in release_type_dict:
    type_name=type_name_from_path(path)
    if type_name=='query' or type_name=='response':
      release_shape=release_type_dict[path]
      if path in pr_type_dict:
        pr_shape=pr_type_dict[path]
      else:
        pr_shape=None
      if pr_shape is None:
        print('RPC type at path',path,f'in release branch ({release_branch}) is missing from PR branch')
        set_error()

def check_command_types(pr_type_dict,release_branch,release_type_dict) :
  # every signed command, zkapp command type in release still present
  for path in release_type_dict:
      module_path=module_path_from_path(path)
      if is_signed_command_module_path(module_path) or is_zkapp_command_module_path(module_path):
        release_shape=release_type_dict[path]
        if path in pr_type_dict:
          pr_shape=pr_type_dict[path]
        else:
          pr_shape=None
        if pr_shape is None:
          print('Command type at path',path,f'in release branch ({release_branch}) is missing from PR branch')
          set_error()

def check_type_shapes(pr_branch_dict,base_branch,base_type_dict,release_branch,release_type_dict) :
  for path in pr_branch_dict:
    if path in release_type_dict:
      release_info=release_type_dict[path]
    else:
      release_info=None
    if path in base_type_dict:
      base_info=base_type_dict[path]
    else:
      base_info=None
    pr_info=pr_branch_dict[path]
    # an error if the shape has changed from both the release and base branches
    # see RFC 0047
    if not release_info is None and not base_info is None:
      # shape digests may differ, even if depth-limited shapes are the same
      pr_digest=pr_info[0]
      pr_shape=pr_info[1]
      pr_type=pr_info[2]
      release_digest=release_info[0]
      release_shape=release_info[1]
      release_type=release_info[2]
      base_digest=base_info[0]
      base_shape=base_info[1]
      base_type=base_info[2]
      if not pr_shape==release_shape and not pr_shape==base_shape:
        print(f'At path {path}:')
        print(f'  Type shape in PR differs from shapes in release branch \'{release_branch}\' and base branch \'{base_branch}\'')
        release_diff_depth=type_shapes_diff_depth(pr_shape,release_shape)
        print ('  In release branch:')
        print ('    Shape differs from PR branch shape at depth',release_diff_depth)
        print ('    Digest:',release_digest)
        print ('    Shape :',release_shape)
        print ('    Type  :',release_type)
        base_diff_depth=type_shapes_diff_depth(pr_shape,base_shape)
        print ('  In base branch:')
        print ('    Shape differs from PR branch shape at depth',base_diff_depth)
        print ('    Digest:',base_digest)
        print ('    Shape :',base_shape)
        print ('    Type  :',base_type)
        print ('  In PR branch:')
        print ('    Digest:',pr_digest)
        print ('    Shape :',pr_shape)
        print ('    Type  :',pr_type)
        set_error()
    # an error if the type was deleted in the base branch, added back in PR branch with different shape
    # not mentioned in RFC 0047
    if not release_shape is None and base_shape is None:
      if not pr_shape==release_shape:
        print(f'At path {path}:')
        print(f'  Type shape in PR differs from shape in release branch \'{release_branch}\' (was deleted in base branch \'{base_branch}\')')
        release_diff_depth=type_shapes_diff_depth(pr_shape,release_shape)
        print ('  In release branch:')
        print ('    Shape differs from PR branch shape at depth',release_diff_depth)
        print ('    Digest:',release_digest)
        print ('    Shape :',release_shape)
        print ('    Type  :',release_type)
        print ('  In base branch:')
        print ('    Digest:',base_digest)
        print ('    Shape :',base_shape)
        print ('    Type  :',base_type)
        print ('  In PR branch:')
        print ('    Digest:',pr_digest)
        print ('    Shape :',pr_shape)
        print ('    Type  :',pr_type)
        set_error()
    # not an error if the type was introduced in the base branch, and the type changed in PR branch

def assert_commit(commit, desc):
  if not commit:
    f"Empty commit detected when evaluating commit of {desc}"

if __name__ == "__main__":
  if len(sys.argv) != 4 :
        print("Usage: %s pr-branch base-branch release-branch" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

  pr_branch=sys.argv[1]
  base_branch=sys.argv[2]
  release_branch=sys.argv[3]

  subprocess.run(['git','fetch'],capture_output=False)

  base_branch_commit=branch_commit(base_branch)
  download_type_shapes('base',base_branch,base_branch_commit)

  print('')

  release_branch_commit=branch_commit(release_branch)
  download_type_shapes('release',release_branch,release_branch_commit)

  print('')

  pr_branch_commit=branch_commit(pr_branch)
  download_type_shapes('pr',pr_branch,pr_branch_commit)

  print('')

  base_type_shape_file=type_shape_file(base_branch_commit)
  base_type_dict=make_type_shape_dict(base_type_shape_file)

  release_type_shape_file=type_shape_file(release_branch_commit)
  release_type_dict=make_type_shape_dict(release_type_shape_file)

  pr_type_shape_file=type_shape_file(pr_branch_commit)
  pr_type_dict=make_type_shape_dict(pr_type_shape_file)

  check_rpc_types(pr_type_dict,release_branch,release_type_dict)
  check_command_types(pr_type_dict,release_branch,release_type_dict)
  check_type_shapes(pr_type_dict,base_branch,base_type_dict,release_branch,release_type_dict)

  sys.exit(exit_code)
