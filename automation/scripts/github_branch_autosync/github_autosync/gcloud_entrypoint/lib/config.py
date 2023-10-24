import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from dataclasses_json import dataclass_json
from typing import Dict, List
import json
import re

'''
Controls updates from submodules. Tool can handle testing changes in submodules. 
On push event for any related branches submodules defined in `sub-modules` section
tool will create new commit in main repo with new hash and additionally will start buildkite
pipeline to test new changes in main repo.
'''


@dataclass_json
@dataclass(frozen=True)
class SubModule:
    name: str
    branches: Dict[str, str]
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


@dataclass_json
@dataclass(frozen=True)
class Github:
    dryrun: bool
    token: str
    username: str
    repo: str
    secret: str
    branches: Dict[str, str]

    def tmp_branch_name(self, source_branch, target_branch):
        """
            Method which will be used for naming temp branch (needed for checking merge ability)
        """
        return f"sync-{source_branch}-with-{target_branch}"


'''
Specific settings for PR creation (if there is necessity to do it based on current repo situation).
'''


@dataclass_json
@dataclass(frozen=True)
class PullRequest:
    title_prefix: str
    assignees: List[str]
    body_prefix: str
    labels: List[str]


@dataclass_json
@dataclass(frozen=True)
class Buildkite:
    """
        Buildkite specific settings
    """
    token: str
    org: str


@dataclass_json
@dataclass(frozen=True)
class Config:
    """
    Main configuration file for auto-sync logic.
    One can define relation between branches in section 'branches' or accessibility settings
    for Buildkite and GitHub
    """

    submodules: List[SubModule]
    github: Github
    pr: PullRequest
    buildkite: Buildkite


def load(config_file_path):
    if os.path.isfile(config_file_path):
        with open(config_file_path, 'r') as f:
            app_config = json.load(f)
            EnvVarSubs.substitude_env_vars(app_config, SystemEnvVarProvider())
            return Config.from_dict(app_config)
    else:
        raise Exception(f'Configuration file not found: {config_file_path}')


class EnvVarSubs:

    def _cast_to_type(s):
        try:
            return int(s)
        except ValueError:
            try:
                return float(s)
            except ValueError:
                return s

    def substitude_env_vars(d, env_var_provider):
        for key in d.keys():
            v = d.get(key)
            if isinstance(v, str):
                m = re.match('\$\{([_a-zA-Z]+)\}', v, )
                if m:
                    env_name = m.group(1)
                    env_val = env_var_provider.get(env_name)
                    d[key] = env_val
            elif isinstance(v, dict):
                EnvVarSubs.substitude_env_vars(v, env_var_provider)


class EnvVarProvider(ABC):

    @abstractmethod
    def get(self, env_name):
        pass


class SystemEnvVarProvider(EnvVarProvider):

    def get(self, env_name):
        env_val = os.environ.get(env_name)
        if env_val is None:
            raise Exception(f"'{env_name}' is not defined")
        else:
            return env_val
