'''
Main configuration file for auto-sync logic. 
One can define relation between branches in section 'branches' or accessibility settings 
for Buildkite and Github
'''
import os

'''
Controls relation between branches. Dictionary Key is a branch name
on which change we will try to merge to branch with name as value.
For example tuple develop -> compatible: 
If there is a new commit on develop branch, 
program will attempt to merge new changes to compatible branch
'''
branches = dict(
    compatible = 'berkeley',
    berkeley = 'develop'
)

'''
    Settings for github repository. 
    dryrun: if set to true, program will not perform any operations but will printout
    token: github webhook secret (for validation of request)
    username: owner of repo
    repo: repo name
    secret: valid github token (classic or fine-grained)
        WARNING: 

        Token need to have permission to:
            - list prs
            - list branches
            - create new branch
            - create new pr
            - delete branch
            - merge branch
'''
github = {
    "dryrun": False,
    "token": os.environ["WEBHOOK_APP_TOKEN"],
    "username": os.environ["WEBHOOK_APP_USER"],
    "repo": os.environ["WEBHOOK_APP_REPO"],
    "secret": os.environ["WEBHOOK_APP_GITHUB_SECRET"]
}

def tmp_branch_name(source_branch,target_branch):
    '''
        Method which will be used for naming temp branch (needed for checking merge ability)
    '''
    return f"fix-conflict-of-{source_branch}-and-{target_branch}"

'''
Specific settings for PR creation (if there is necessity to do it based on current repo situation).
'''
pr = {
    "title_prefix": "[Fix me] Merge conflict between ",
    "assignees": ["dkijania"],
    "body_prefix": "This is auto-generated PR in order to solve merge conflicts between two branches.",
    "draft": 'false',
    "labels": ["auto-sync"],
    "alert_header": """
# :exclamation: New Conflict detected :exclamation: 
This PR conflicts with one of our main branches. As a result below Pull requests were created to aid you in resolving merge conflicts. Each temporary branch contains *cherry picked* changes from this PR. 
"""
}

'''
    Buildkite specific settings
'''
buildkite = {
    "token": "...",
    "org": "mina-foundation",
    "pipeline": "test-buildkite"    
}
