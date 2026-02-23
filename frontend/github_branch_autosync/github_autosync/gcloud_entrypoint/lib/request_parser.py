"""
    Module responsible for extracting information from github webhook event payload json
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
            Gets full branch id (/refs/head/{})
        """
        branch_id = self.data["ref"]
        return str.split(branch_id,"/")[2]
    
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
