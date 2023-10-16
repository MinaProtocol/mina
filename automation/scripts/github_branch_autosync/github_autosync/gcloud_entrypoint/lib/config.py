import os

'''
Controls updates from submodules. Tool can handle testing changes in submodules. 
On push event for any related branches submodules defined in `sub-modules` section
tool will create new commit in main repo with new hash and additionally will start buildkite
pipeline to test new changes in main repo.
'''
class SubModule:
    
    def __init__(self, name, branches, pipeline,secret):
        self.name = name
        self.branches = branches
        self.pipeline = pipeline
        self.secret = secret

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
class Github:

    def __init__(self, dryrun, token, username,repo,secret,branches):
        self.dryrun = dryrun
        self.token = token
        self.username = username
        self.repo = repo
        self.secret = secret
        self.branches = branches

    def tmp_branch_name(source_branch,target_branch):
        '''
            Method which will be used for naming temp branch (needed for checking merge ability)
        '''
        return f"sync-{source_branch}-with-{target_branch}"


'''
Specific settings for PR creation (if there is necessity to do it based on current repo situation).
'''
class PullRequest:
    
    def __init__(self, title_prefix, assignees, body_prefix, labels):
        self.title_prefix = title_prefix
        self.assignees = assignees
        self.body_prefix = body_prefix
        self.labels = labels
    
'''
    Buildkite specific settings
'''
class Buildkite:
    def __init__(self, token, org):
        self.token = token
        self.org = org  

'''
Main configuration file for auto-sync logic. 
One can define relation between branches in section 'branches' or accessibility settings 
for Buildkite and Github
'''
class Config:
    def __init__(self, submodules, github, pr, buildkite):
        self.submodules = submodules
        self.github = github  
        self.pr = pr
        self.buildkite = buildkite


submodules = [
        SubModule(
            name="proof_system", 
            branches={
                "develop":"develop",
                "berkeley":"berkeley"
            },
            pipeline="Crypto Pipeline",
            token=os.environ["WEBHOOK_APP_TOKEN"]
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