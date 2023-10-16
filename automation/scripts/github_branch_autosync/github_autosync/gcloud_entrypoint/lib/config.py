import os

'''
Controls updates from submodules. Tool can handle testing changes in submodules. 
On push event for any related branches submodules defined in `sub-modules` section
tool will create new commit in main repo with new hash and additionally will start buildkite
pipeline to test new changes in main repo.
'''
@dataclass
class SubModule:
    name: str
    branches: dict[str,str]
    pipeline: str
    token: str

'''
    Settings for github repository. 
    dryrun: if set to true, program will not perform any operations but will printout
    token: valid github token (classic or fine-grained)
           WARNING: 

           Token need to have permission to:
            - list prs
            - list branches
            - create new branch
            - create new pr
            - delete branch
            - merge branch

    username: owner of repo
    repo: repo name
    secret: github webhook secret (for validation of request)
    branches: Controls relation between branches. Dictionary Key is a branch name
              on which change we will try to merge to branch with name as value.
              For example tuple develop -> compatible: 
              If there is a new commit on develop branch, 
              program will attempt to merge new changes to compatible branch
'''
@dataclass
class Github:
    dryrun: bool
    token: str
    username: str
    repo: str
    secret: str
    branches: dict[str, str]

    def tmp_branch_name(source_branch,target_branch):
        '''
            Method which will be used for naming temp branch (needed for checking merge ability)
        '''
        return f"sync-{source_branch}-with-{target_branch}"


'''
Specific settings for PR creation (if there is necessity to do it based on current repo situation).
'''
@dataclass
class PullRequest:
    title_prefix: str
    assignees: list[str]
    body_prefix: str
    labels: list[str]
    
'''
    Buildkite specific settings
'''
@dataclass
class Buildkite:
    token: str
    org: str

'''
Main configuration file for auto-sync logic. 
One can define relation between branches in section 'branches' or accessibility settings 
for Buildkite and Github
'''
@dataclass
class Config:
    submodules: list[Submodule]
    github: Github  
    pr: PullRequest
    buildkite: Buildkite


def load(self,config_file_path):
    if os.path.isfile(config_file_path):
        with open(config_file_path, 'r') as f:
            app_config = json.load(f)
            EnvVarSubs.substitude_env_vars(app_config,SystemEnvVarProvider())
            return app_config
    else:
        raise Exception('Configuration file not found: '.format(config_file_path))

from abc import ABC, abstractmethod

class EnvVarSubs:

    def _cast_to_type(s):
        try:
            return int(s)
        except ValueError:
            try:
                return float(s)
            except ValueError:
                return s

    def substitude_env_vars(d,env_var_provider):
        for key in d.keys():
            v = d.get(key)
            if isinstance(v, str):
                m = re.match('\${(\w+)\:-(\w+)}', v)
                if m:
                    env_name = m.group(1)
                    def_val = m.group(2)
                    env_val = env_var_provider.get(env_name)#os.environ.get(env_name)
                    if env_val is None:
                        env_val = _cast_to_type(def_val)
                    d[key] = env_val
            elif isinstance(v, dict):
                _substitude_env_vars(v)

class EnvVarProvider(ABC):

    @abstractmethod
    def get(env_name):
        pass

class SystemEnvVarProvider(EnvVarProvider):

    def get(env_name):
        return os.environ.get(env_name)

submodules = [
    SubModule(
        name="proof-systems", 
        branches={
            "develop":"develop",
            "berkeley":"berkeley"
        },
        pipeline="Crypto Pipeline",
        token=os.environ[f'WEBHOOK__TOKEN']
    )
],

github = Github(
    dryrun=False,
    token=os.environ["WEBHOOK_APP_TOKEN"],
    username=os.environ["WEBHOOK_APP_USER"],
    repo=os.environ["WEBHOOK_APP_REPO"],
    secret=os.environ["WEBHOOK_APP_GITHUB_SECRET"]
)

branches = dict(
    compatible = 'rampup',
    rampup = 'berkeley',
    berkeley = 'develop'
)

pr = PullRequest(
    title_prefix="[Branches auto sync failure] ",
    assignees=["dkijania"],
    body_prefix="This is auto-generated PR in order to solve merge conflicts between two branches.",
    draft=False,
    labels=["auto-sync"]
)
buildkite = Buildkite(
    token="...",
    org= "mina-foundation"    
)

config = Config(
    submodules,
    github,
    pr,
    buildkite
)  