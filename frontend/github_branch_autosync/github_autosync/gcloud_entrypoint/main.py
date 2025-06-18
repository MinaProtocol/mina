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

def handle_incoming_commit_push_in_stable_branches(source_branch):
    """Hand incoming commit on major branch.
    Args:
        source_branch (String): Name of branch which commit was pushed to.
    """

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

def get_branches_earlier_in_chain(branches,branch):
    """ Retrieves names of branches earlier in the chain that incoming one
    Args:
        branches (Dictionary): Configuration element which defines branches relation.
        branch (String): Incoming branch
    Returns:
        List of branches earlier in the chain
    """
    inv_branches = {v: k for k, v in branches.items()}
    return get_branches_later_in_chain(inv_branches,branch)

def get_branches_later_in_chain(branches,branch):
    """ Retrieves names of branches earlier in the chain that incoming one
    Args:
        branches (Dictionary): Configuration element which defines branches relation.
        branch (String): Incoming branch
    Returns:
        List of branches later in the chain
    """
    output = []
    next = branches.get(branch)
    while next is not None:
        output.append(next)
        next = branches.get(next)
    return output


def handle_pr(pr,github,source_branch):
    """ Handle push in personal pr
    Args:
        pr (PullRequest): Configuration element which defines branches relation.
        github (Github): Github wrapper
        branch (String): Incoming branch
    """
    branches = get_branches_earlier_in_chain(config.branches,pr.base.ref)
    later_branches = get_branches_later_in_chain(config.branches,pr.base.ref)
    branches.extend(later_branches)

    data = []
   
    for branch in branches: 
        if github.has_merge_conflict(branch,source_branch):
            print(f"{branch} and {source_branch} branches have a merge conflict! creating PR to address those changes...")
            
            new_branch = config.tmp_branch_name(source_branch,branch)

            if github.branch_exists(new_branch):
                print(f"{new_branch} already exists therefore we will recreate it")
                github.delete_branch(new_branch)

            github.create_new_branch(new_branch,branch)

            commits = pr.get_commits()
            github.cherry_pick_commits(new_branch,commits,skip_merges=True)

            title = github.create_pull_request(config,source_branch,branch,new_branch)
            print(f"new PR: '{title}' created. Please resolve it before merge...")

            for pr in github.repository().inner.get_pulls(head=new_branch):
                if pr.title == title:
                    data.append((pr.html_url,new_branch,branch))
    if any(data):
        pr.create_issue_comment(comment_conflict(data))

def handle_incoming_commit_push_in_personal_branches(source_branch):
    """
      Main handler for change in personal branch
    """
    github = GithubApi(config.github)
    
    pull_requests = github.get_opened_not_draft_prs_from(source_branch)

    if not any(pull_requests):
        print(f"skipping... merge check as branch {source_branch} does not have any non-draft pr opened")

    for pr in pull_requests:
        handle_pr(pr,github,source_branch)
    
def comment_conflict(data):
    """
      Template for issue comment after conflict in PR is detected
    """
    content = config.pr["alert_header"] + """
<table>
  <tr>
    <th>Pull request name</th>
    <th> Temporary branch name</th>
    <th> Conflicting branch </th>
  </tr>
"""
    for (url,base,branch) in data: 
        content = content + f"""
<tr>
    <td> <a href="{url}"> {url} </a> </td>
    <td> {base}  </td>
    <td> {branch} </td>
</tr>
"""
    content = content + """
</table>
"""
    return content

def handle_incoming_commit_push_json(json,config):
    """
      Main logic for handling incoming github webhook event
    """
    payload_info=  GithubPayloadInfo(json)

    source_branch = payload_info.incoming_branch

    if not source_branch in config.branches:
        handle_incoming_commit_push_in_personal_branches(source_branch)
    else:
        handle_incoming_commit_push_in_stable_branches(source_branch)
    