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
    request_json = request.get_json()
    if request.args and 'message' in request.args:
        return request.args.get('message')
    if request_json and 'message' in request_json:
        return request_json['message']

    try:
        verify_signature(request_json, config.github["secret"], request.headers['x-hub-signature'])
        if is_push_event(request):
            return "not a push event. skipping..."
        handle_incoming_commit_push_json(request_json,config=config)
        return "done"
    except Exception as exp:
        return str(exp)


def handle_incoming_commit_push_json(json,config):
    """
      Main logic for handling incoming github webhook event
    """
    payload_info=  GithubPayloadInfo(json)

    source_branch = payload_info.incoming_branch
    target_branch = config.branches[source_branch]
    github = GithubApi(config.github)
    cmp = github.get_diff_commits(target_branch,source_branch)

    if cmp.status == "identical":
        print(f"'{source_branch} and '{target_branch}' branches are identical. skipping merge...")

    elif cmp.status == "behind":
        print(f"'{source_branch}' is behind '{target_branch}'. skipping merge...")

    elif cmp.status == "ahead":
        print(f"'{source_branch}' is ahead of '{target_branch}'. It is enough just to fast-forward...")
        info = github.fast_forward(target_branch,source_branch)
        print(f'branch {target_branch} successfully fast-forward. It is now on commit: {info["object"]["sha"]}')
    else:
        print(f"'{source_branch}' and '{target_branch}' branches are not identical, both branches contains different commits (there are 'diverged'). approaching merge...")
        new_branch = config.tmp_branch_name(source_branch,target_branch)

        if github.branch_exists(new_branch):
            print(f'temporary sync branch {new_branch} already exists. fast-forwarding or creating yet another pr for new changes')

            try:
                info = github.fast_forward(new_branch,source_branch)
                print(f'branch {new_branch} successfully fast-forward. It is now on commit: {info["object"]["sha"]}')
            except GithubException:
                pull = github.create_pull_request_for_tmp_branch(config,source_branch,new_branch)
                print(f"new PR: '{pull.title}' created. Please resolve it before merge...")

        else:
            print(f'creating new sync branch {new_branch} to incorporate changes from {source_branch} to {target_branch}')
            github.create_new_branch(new_branch,source_branch)

            print("checking mergeability...")

            if github.has_merge_conflict(new_branch,target_branch):
                print("branches have a merge conflict! creating PR to address those changes...")
                #buildkite = BuildkiteApi(config.buildkite)
                pull = github.create_pull_request(config,source_branch,target_branch,new_branch)

                print(f"new PR: '{pull.title}' created. Please resolve it before merge...")

            else:
                print(f"there is no merge conflict. merging {new_branch} into {target_branch}...")
                github.repository().merge(target_branch,new_branch, f"Github Autosync: {source_branch} -> {target_branch}")
                github.delete_branch(new_branch)
