""" Test utility module """

import random
import base64
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
from github_autosync.gcloud_entrypoint.lib.github import GithubApi
from tests import config


def create_simple_commit(github_api,config,branch, message, path, content ):
    """
        Creates simple commit.
        
        Parameters:
            github_api (GithubApi): Github api 
            config (config): Test config module
            branch (string): Branch name to which we commit
            message (string): commit message
            path (string): path to file which will receive new content
            content (string): new content for file in 'path' argument

        Returns:
            Graphql response
    """
    head = github_api.branch(name=branch).commit.sha
    sample_string_bytes = content.encode("ascii")
    base64_bytes = base64.b64encode(sample_string_bytes)
    base64_string = base64_bytes.decode("ascii")

    transport = RequestsHTTPTransport(url="https://api.github.com/graphql",headers=github_api.get_authorization_header)

    client = Client(transport=transport)
    mutation = gql(
    """
    mutation ($input: CreateCommitOnBranchInput!) {
        createCommitOnBranch(input: $input) { 
            commit { url } 
        } 
    }
    """
    )

    variables = {
        "input": {
        "branch": {
            "repositoryNameWithOwner": config["username"] +"/" + config["repo"],
            "branchName": branch
        },
        "message": {"headline": message },
        "fileChanges": {
            "additions": [{
                "path": path,
                "contents": base64_string
            }]
        },
        "expectedHeadOid": head
    }}

    res = client.execute(mutation, variable_values=variables)
    transport.close()
    client.close_sync()
    return res

class BranchNamesGenerator(object):
    """
        Utility class to generate unique (with reasonable uniqueness) names for branches 
        and files which are about to be edited
    """
    def __init__(self):
        self.store = []
        self.github= GithubApi(config.github)

    def generate_unique_names(self):
        """ 
            Generates unique tuple of two branches and file to edit.
            Then stores branches in inner dict for later clean up
        """
        rand = str(random.randint(0, 100_000))
        compatible_branch = "compatible" + rand
        develop_branch = "develop_" + rand
        file_to_edit = f"README_{rand}.md"
        self.github.create_new_branch(compatible_branch,"main")
        self.github.create_new_branch(develop_branch,"main")

        config.branches[compatible_branch] = develop_branch
        self.store.extend([compatible_branch,develop_branch,config.tmp_branch_name(compatible_branch,develop_branch)])
        return (compatible_branch,develop_branch,file_to_edit)

    def tear_down(self):
        """
            Deletes all branches that class is aware of
        """
        all_branches = self.github.repository().get_branches().get_page(0)
        for branch in self.store:
            if any(x.name == branch for x in all_branches):
                self.github.delete_branch(branch)
