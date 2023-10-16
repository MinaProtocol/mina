""" Test config """
import os
from github_autosync.gcloud_entrypoint.lib.config import Config,SubModule,PullRequest,Buildkite,Github

submodules = [
        SubModule(
            "web_hook_submodule_test", 
            {
                "develop":"develop",
                "berkeley":"berkeley"
            },
            "Crypto Pipeline"
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
