"""
    Module responsible for extracting information from GitHub webhook event payload json
"""


class GithubPayloadInfo(object):
    """
        Class responsible for parsing webhook event payload json
    """

    def __init__(self, json):
        self.data = json

    @property
    def incoming_branch(self):
        """
            Gets full branch id (refs/head/{})
        """
        branch_id = self.data["ref"]
        return str.replace(branch_id, "refs/head/", "")

    @property
    def comment_body(self):
        """
              Gets comment body
        """
        return self.data["comment"]["body"]

    @property
    def issue_number(self):
        """
            Gets issue number
        """
        return self.data["issue"]["number"]


    @property
    def issue_title(self):
        """
            Gets issue title
        """
        return self.data["issue"]["title"]

    @property
    def repository(self):
        """

        Returns: repository name

        """
        return self.data["repository"]["full_name"]

    @property
    def new_commit_hash(self):
        """
            Gets new commit hash
        """
        after = self.data["after"]
        return after

    @property
    def old_commit_hash(self):
        """
            Gets old commit hash
        """
        before = self.data["before"]
        return before

    @property
    def commits(self):
        """
            Gets commits info
        """
        return list(map(CommitInfo, self.data["commits"]))


class CommitInfo(object):
    """
        Responsible for providing information about commit
    """

    def __init__(self, json):
        self.data = json

    @property
    def files(self):
        """
            Returns all files touched by this commit
        """
        added = self.data["added"]
        removed = self.data["removed"]
        modified = self.data["modified"]
        return added + removed + modified

    @property
    def message(self):
        """
            Gets commit message
        """
        return self.data["message"]
