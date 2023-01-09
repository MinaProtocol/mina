import subprocess
import argparse
import re
import os
import sys
from git import Repo

# Checks out the branch and updates every submodule

def checkout_branch(repo, branch):

  print(branch)
  repo.git.checkout('--recurse-submodules', branch)
  subprocess.run('nix/pin.sh', stdout=subprocess.DEVNULL)

# Builds the nix script describing the docker image
# Loads the script with docker
# Return the name of the image

def build_load_image_nix(repo, branch):

  checkout_branch(repo, branch)
  print('Currently on branch: ' + branch)
  print('Initialize shell and run command')
  pwd = os.environ['PWD']
  output = subprocess.run(['nix', 'shell', "git+file://"+pwd+"?submodules=1", '-c', 'mina', 'internal', 'dump-type-shapes', '-max-depth', '5'], capture_output=True)

  return output.stdout

# Checks for compatibility between PR branch and release branch by checking query and response type hashes

def query_and_response_lint(input, branches, log, index):
  for element in input[branches[2]]:
    if re.search(r"query$", element) or re.search(r"response$", element):
      if element in input[branches[0]]:
        if input[branches[2]][element][0] != input[branches[0]][element][0]:
          index += 1
          log.write("---------\nError Nr. " + str(index) + "\n---------\n")
          log.write("[ERROR] " + element + " type in PR branch doesn't have the same hash as in the release branch! The code will not be compatible. \n")
          log.write(branches[0] + " branch has hash: " + input[branches[0]][element][0] + "\n")
          log.write(branches[2] + " branch has hash: " + input[branches[2]][element][0] + "\n")
      else:
        index += 1
        log.write("---------\nError Nr. " + str(index) + "\n---------\n")
        log.write("[ERROR] " + element + " type is not present in the PR branch!\n")

# Searches for signed_command type and checks if it's present in both PR and release branches

def signed_command_lint(input, branches, log, index):
  for element in input[branches[2]]:
    if re.search(r"Signed_command\.Vn\.t$", element):
      print("Found signed command")
      if element in input[branches[0]]:
        print("Type " + element + " is present in both branches")
      else:
        index += 1
        log.write("---------\nError Nr. " + str(index) + "\n---------\n")
        log.write("[ERROR] Type " + element + " type is not present in the PR branch!\n")

# Searches for zkapp_command type and checks if it's present in both PR and release branches

def zkapp_command_lint(input, branches, log, index):
  for element in input[branches[2]]:
    if re.search(r"Zkapp_command\.Vn\.t$", element):
      print("Found zkapp command")
      if element in input[branches[0]]:
        print("Type " + element + " is present in both branches")
      else:
        index += 1
        log.write("---------\nError Nr. " + str(index) + "\n---------\n")
        log.write("[ERROR] Type " + element + " type is not present in the PR branch!\n")

# Checks every types hash and shape between the three branches

def t_query_and_response_lint(input, branches, log, index):
  for element in input[branches[0]]:
    if re.search(r"query$", element) or re.search(r"response$", element) or re.search(r"\.t$", element):
      if element in input[branches[1]] and element in input[branches[2]]:
        if (input[branches[0]][element][0] == input[branches[1]][element][0]) and (input[branches[0]][element][0] == input[branches[2]][element][0]):
          print("All good!" + element + " types have matching hashes")
        elif (input[branches[0]][element][0] != input[branches[1]][element][0]) and (input[branches[0]][element][0] != input[branches[2]][element][0]):
          if (input[branches[0]][element][1] != input[branches[1]][element][1]) and (input[branches[0]][element][1] != input[branches[2]][element][1]):
            index += 1
            log.write("---------\nError Nr. " + str(index) + "\n---------\n")
            log.write("[ERROR] Type shape and hash of " + element + " in PR branch is not matching with base and release branch\n")
            log.write("Hashes: \n" + branches[0] + " branch has hash " + input[branches[0]][element][0] + "\n" + branches[1] + " branch has hash " + input[branches[1]][element][0] + "\n" + branches[2] + " branch has hash " + input[branches[2]][element][0] + "\n")
            log.write("Shapes: \n" + branches[0] + " branch has hash " + input[branches[0]][element][1] + "\n" + branches[1] + " branch has hash " + input[branches[1]][element][1] + "\n" + branches[2] + " branch has hash " + input[branches[2]][element][1] + "\n")

# Initialize resources

repo = Repo('.')
logfile = 'ppx_lint.log'
index = 0

# Initialize parser

parser = argparse.ArgumentParser()
parser.add_argument('--PR-branch', dest='pr', type=str, required=True, help='The name of the branch that has feature changes')
parser.add_argument('--base-branch', dest='base', type=str, required=True, help='The name of the branch that is the destination of the PR (ex. develop)')
parser.add_argument('--release-branch', dest='release', type=str, required=True, help='The name of the release branch (ex. release/2.0.0)')
args = parser.parse_args()

branches = [args.pr, args.base, args.release] 
lint_result = {}
for branch in branches:
  lint_result[branch] = {}

# Iterates through branches to gather data

for branch in branches:
  output_bytes = build_load_image_nix(repo, branch)
  for line in output_bytes.decode('UTF-8').split('\n'):
    if re.match(r"^.+/", line[0:10]):
      first_occurence = line.index(',')
      second_occurence = line.index(',', first_occurence+1, len(line))
      lint_result[branch][line[:first_occurence]] = [line[first_occurence+1:second_occurence].strip(), line[second_occurence+1:].strip()]
  repo.git.checkout('.') # Git recognizes changes in the repository so in order to checkout new branch we have to get rid of these changes

# Linting

with open(logfile, 'a') as log:
  query_and_response_lint(lint_result, branches, log, index)
  signed_command_lint(lint_result, branches, log, index)
  zkapp_command_lint(lint_result, branches, log, index)
  t_query_and_response_lint(lint_result, branches, log, index)

  log.close()

# Prints errors

with open(logfile, 'r') as log:
  print(log.read())
  log.close()

# Cleanup temp file

os.remove(logfile)
