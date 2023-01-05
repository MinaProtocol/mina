import docker as doc
import subprocess
from git import Repo

# Checks out the branch and updates every submodule
def checkout_branch(repo, branch):
  repo.git.checkout(branch)
  for submodule in repo.submodules:
    submodule.update()


def build_container_nix(client, repo, branch):
  checkout_branch(repo, branch)
  print('Building docker image script')
  image_script = subprocess.run(["nix", "build", "mina#packages.x86_64-linux.mina-image-full", "--print-out-paths"], capture_output=True)
  print(image_script.stdout.decode('UTF-8').strip())
  # call_script = subprocess.run(image_script.stdout.decode('UTF-8').strip(), capture_output=True) 
  # print('Ran docker image script')
  # docker_load = subprocess.Popen(["docker", "load"], stdin=call_script.stdout)
  
  # client.images.load(call_script.stdout)
  # subprocess.run(["docker", "load"], input=image_script.strip())
  # with open(image_script.decode('UTF-8').strip(), 'rb') as f:
  #   client.images.load(f)
  # print(image)


docker_client = doc.from_env()
repo = Repo('..')

build_container_nix(docker_client,repo,'ppx-lint-script')
