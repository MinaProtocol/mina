''' Main module for handling incoming github webhook event'''

from .lib import GithubPayloadInfo, config, GithubApi, GithubException, verify_signature,is_push_event

def handle_incoming_commit_push(request):
    """Responds to any HTTP request.
    Args:
        request (flask.Request): HTTP request object.
    Returns:
        The response text or any set of values that can be turned into a
        Response object using
        `make_response <http://flask.pocoo.org/docs/1.0/api/#flask.Flask.make_response>`.
    """
    verify_signature(request.data, config.github["secret"], request.headers['x-hub-signature-256'])
    if not is_push_event(request):
        print("not a push event. skipping...")
        return

    handle_incoming_commit_push_json(request.json,config=config)
    print("done")
    return

def handle_incoming_commit_push_json(json,config):
    """
      Main logic for handling incoming github webhook event
    """
    payload_info=  GithubPayloadInfo(json)

    source_branch = payload_info.incoming_branch

    if not source_branch in config.branches:
        print(f"change in '{source_branch}' is not supported ")
        return

    target_branch = config.branches[source_branch]
    github = GithubApi(config.github)
    print(f"generating diff between {source_branch} and '{target_branch}'...")
    cmp = github.get_diff_commits(target_branch,source_branch)

    if cmp.status == "identical":
        print(f"'{source_branch}' and '{target_branch}' branches are identical. skipping merge...")
        return
    if cmp.status == "behind":
        print(f"'{source_branch}' is behind '{target_branch}'. skipping merge...")
        return

    if cmp.status == "ahead":
        print(f"'{source_branch}' is ahead of '{target_branch}'. It is enough just to fast-forward...")
        new_sha = github.fast_forward(target_branch,source_branch)
        print(f'branch {target_branch} successfully fast-forward. It is now on commit: {new_sha}')
        return

    print(f"'{source_branch}' and '{target_branch}' branches are not identical, both branches contains different commits (there are 'diverged'). approaching merge...")
    new_branch = config.tmp_branch_name(source_branch,target_branch)

    if github.branch_exists(new_branch):
        print(f'temporary sync branch {new_branch} already exists. fast-forwarding or creating yet another pr for new changes')

        try:
            new_sha = github.fast_forward(new_branch,source_branch)
            print(f'branch {new_branch} successfully fast-forward. It is now on commit: {new_sha}')
        except GithubException:
            title = github.create_pull_request_for_tmp_branch(config,source_branch,new_branch)
            print(f"new PR: '{title}' created. Please resolve it before merge...")

    else:
        print(f'creating new sync branch {new_branch} to incorporate changes from {source_branch} to {target_branch}')
        github.create_new_branch(new_branch,source_branch)

        print("checking mergeability...")

        if github.has_merge_conflict(new_branch,target_branch):
            print("branches have a merge conflict! creating PR to address those changes...")
            title = github.create_pull_request(config,source_branch,target_branch,new_branch)
            print(f"new PR: '{title}' created. Please resolve it before merge...")

        else:
            print(f"there is no merge conflict. merging {new_branch} into {target_branch}...")
            github.merge(target_branch,new_branch, f"Github Autosync: {source_branch} -> {target_branch}")
            github.delete_branch(new_branch)
