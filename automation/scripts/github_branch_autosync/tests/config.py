""" Test config """
import os

branches = {}

github = {
    "token": os.environ["WEBHOOK_APP_TOKEN"],
    "username": os.environ["WEBHOOK_APP_USER"],
    "repo": os.environ["WEBHOOK_APP_REPO"],
}

def tmp_branch_name(source_branch,target_branch):
    return f"sync-{source_branch}-with-{target_branch}"

pr = {
    "title_prefix": "[Branches auto sync failure] ",
    "assignees": [os.environ["WEBHOOK_APP_USER"]],
    "body_prefix": "This is auto-generated PR in order to solve merge conflicts between two branches.",
    "draft": 'false',
    "maintainer_can_modify": 'false',
    "labels": ["auto-sync"]
}