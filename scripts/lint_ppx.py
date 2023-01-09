import docker as doc
import subprocess
import argparse
import re
from git import Repo

# Checks out the branch and updates every submodule

def checkout_branch(repo, branch):

  print(branch)
  repo.git.checkout('--recurse-submodules', branch)
  subprocess.run('nix/pin.sh')

# Builds the nix script describing the docker image
# Loads the script with docker
# Return the name of the image

def build_load_image_nix(client, repo, branch):

  checkout_branch(repo, branch)
  print('Currently on branch: ' + branch)
  print('Building docker image script')
  try:
    image_script = subprocess.run(["nix", "build", "mina#packages.x86_64-linux.mina-image-full", "--print-out-paths", "--print-build-logs"], capture_output=True, check=True)
    print(image_script.stdout.decode('UTF-8').strip())
  except CalledProcessError:
    print(image_script.returncode)
    print(image_script.stderr)
    raise
  call_script = subprocess.run(image_script.stdout.decode('UTF-8').strip(), capture_output=True)
  print('Ran docker image script')
  docker_load = subprocess.run(["docker", "load"], input=call_script.stdout, capture_output=True)
  print('Finished loading docker image')
  return (docker_load.stdout.decode('UTF-8').strip()[docker_load.stdout.decode('UTF-8').strip().index("mina"):])

# Runs container with given image and command

def run_container(image, command):
  print('Running container')
  container = docker_client.containers.run(image, command, detach=True)
  return container

def get_container_output(container):
  print('Getting output from container')
  output = container.attach(stdout=True, stream=True, logs=True)
  return output

docker_client = doc.from_env()
repo = Repo('.')
lint_command = 'mina internal dump-type-shapes -max-depth 5'
branches = ['ppx-lint-script', 'ppx-lint-dummy1', 'ppx-lint-dummy2']
lint_result = {}
for branch in branches:
  lint_result[branch] = {}

print(lint_result)

for branch in branches:
  docker_image = build_load_image_nix(docker_client, repo, branch)
  print(docker_image)

  container = run_container(docker_image, lint_command)
  print('Container running')

  container_result_string = get_container_output(container)
  print('Output successfully retrieved')

  for lines in container_result_string:
    for line in lines.decode('UTF-8').split('\n'):
      if re.match(r"^.+/", line[0:10]):
        lint_result[branch][line[:line.index(',')]] = line[line.index(',')+1:line.index(',', line.index(',')+1, len(line))].strip()
  print('Finished branch loop')
  # repo.git.checkout('.')


print(lint_result)

container.stop()
container.remove()
