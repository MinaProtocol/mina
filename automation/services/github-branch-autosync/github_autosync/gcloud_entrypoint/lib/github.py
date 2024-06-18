""" Github api tailored for auto-sync needs"""

import json
from github import Github, PullRequest, InputGitTreeElement
import requests


class GithubException(Exception):
    """Exception raised for errors when interacting with Github REST api.

    Attributes:
        message -- explanation of the error
    """

    def __init__(self, message):
        super().__init__(message)


class GithubApi:
    """
    Responsible for various operation on github rest api
    like creating new branches or merging changes.
    Is tightly coupled with config module
    """

    def __init__(self, config):
        self.config = config
        self.github = Github(config.token)
        self.default_timeout = 60

    def repository(self):
        """
            Retrieves github repository based on configuration
        """
        return Repository(self.github,
                          self.config.username,
                          self.config.repo,
                          self.config.dryrun,
                          self.get_authorization_header,
                          self.default_timeout)

    def submodules(self, branch):
        head = self.repository().get_branch(branch).commit.sha
        tree = self.repository().inner.get_git_tree(head)
        print(tree)

    def branch(self, name):
        """
            Retrieves github branch from configured repository with given name

            Parameters:
                name (string): Branch name

            Returns:
                branch object
        """
        return self.repository().get_branch(branch=name)

    def get_diff_commits(self, left_branch, right_branch):
        """
            Retrieves differences between two branches

            Parameters:
                left_branch (string): Left branch name
                right_branch (string): Right branch name

            Returns:
                commit compare object
        """

        left_branch_ref = self.branch(left_branch).commit.sha
        right_branch_ref = self.branch(right_branch).commit.sha
        return self.repository().compare(left_branch_ref, right_branch_ref)

    def has_merge_conflict(self, base_branch, head_branch):
        """
            Detects if two branches have merge conflict.
            It doesn't use github rest api for this purpose, but a little 'hack'
            by not accessing REST api but sending request to part of github web which is
            only indicating mergeability. Then, it scrapes text visible on page to detect if
            branches are mergeable or not. It uses 60s. of timeout for response. However, usually
            the response is immediate.

            Parameters:
                base_branch (string): Branch name to which we want to merge
                head_branch (string): Branch name from which we want to merge

            Returns:
                boolean indicating if branches are mergeable. True if they are, False otherwise
        """
        res = requests.get(
            f'https://github.com/{self.config.username}/{self.config.repo}/branches/pre_mergeable/{base_branch}...{head_branch}',
            timeout=60)
        return "Able to merge" not in res.text

    def merge(self, base, head, message):
        """
            Merges head branch to base branch

            Parameters:
                message:
                base (string): base branch name
                head (string): head branch name
                commit (string): commit message

        """
        self.repository().merge(base, head, message)

    def create_new_branch(self, branch_name, from_branch):
        """
            Creates new branch

            Parameters:
                branch_name (string): New branch name
                from_branch (string): Branch name from which we create new branch

            Returns:
                new branch object
        """
        from_branch_sha = self.branch(from_branch).commit.sha
        branch_ref_name = f"refs/heads/{branch_name}"

        return self.repository().create_git_ref(branch_ref_name, from_branch_sha)

    @property
    def get_authorization_header(self):
        """
            Gets authorization header for situation when we need to bypass pygithub library
        """
        return {'Authorization': "Bearer " + self.config.token}

    def update_module_hash(self, old_hash, new_hash, module_name):
        inputs = [InputGitTreeElement(
            path=module_name, mode="", type="", sha=new_hash
        )]
        self.repository().inner.create_git_tree(inputs, old_hash)

    def comment_conflict(self, data, alert_header):
        """
          Template for issue comment after conflict in PR is detected
        """
        content = alert_header + """
"""
        for (base, branch, conflicting_branch) in data:
            content = content + f"""
  
## {branch} 

```
git fetch
git checkout {base}
git merge {conflicting_branch}
(Resolve conflict)
git push
```  
    """
        return content

    def create_pull_request(self, draft, labels, title, body_prefix, base, head, assignees):
        """ 
            Creates new pull request

            Parameters:
                body_prefix: body text prefix for pull request
                labels: pull request labels
                draft: create pull request as draft
                title (string): Pull request title
                base (string): Branch name from new branch was created
                head (string): Branch name to which we want to merge changes
                assignees: requested assignees

            Returns:
                return PullRequest object
        """
        assignee_tags = list(map(lambda x: "@" + x, assignees))
        separator = ", "
        body = body_prefix + "\n" + separator.join(assignee_tags)
        return self.repository().create_pull(title=title, body=body, base=base, head=head, draft=draft,
                                             assignees=assignees, labels=labels)

    def comment(self, pr):
        pass


class Repository:
    """
        Class responsible for low level operation on github 
        For testing purposes it can be configured to just printout 
        operations meant to perform (dryrun)
    """

    def __init__(self, github, username, repo, dryrun, authorization_header, timeout):
        self.inner = github.get_repo(username + "/" + repo)
        self.username = username
        self.repo = repo
        self.dryrun = dryrun
        self.dryrun_suffix = "[DRYRUN]"
        self.authorization_header = authorization_header
        self.timeout = timeout

    def get_branches(self):
        return self.inner.get_branches()

    def any_pulls(self, head, base):
        """
            Get prs with given head and  state

            Parameters:
                head (string): head branch name
                base (Bool): base branch
        """
        return any(filter(lambda x: x.head.ref == head and x.base.ref == base,self.inner.get_pulls()))

    def get_pull(self, head, base):
        """
            Get prs with given head and  state

            Parameters:
                head (string): head branch name
                base (Bool): base branch
        """
        pulls = filter(lambda x: x.head.ref == head and x.base.ref == base,self.inner.get_pulls())
        return pulls[0] if any(pulls) else None

    def get_pull_from(self, head):
        """
            Get prs with given head and  state

            Parameters:
                head (string): head branch name
                base (Bool): base branch
        """
        pulls = list(filter(lambda x: x.head.ref == head,self.inner.get_pulls()))
        return pulls[0] if any(pulls) else None

    def get_pull_by_id(self, id):
        """
            Get prs with given head and  state

            Parameters:
                id (int): pull request id
        """
        return self.inner.get_pull(id)

    def merge(self, base, head, message):
        if self.dryrun:
            print(f'{self.dryrun_suffix} Merge {head} to {base} with message {message}')
        else:
            self.inner.merge(base, head, message)

    def create_pull(self, title, body, base, head, draft, assignees, labels):
        if self.dryrun:
            print(f'{self.dryrun_suffix} Pull request created:')
            print(f"{self.dryrun_suffix} title: '{title}'")
            print(f"{self.dryrun_suffix} body: '{body}'")
            print(f"{self.dryrun_suffix} base: '{base}'")
            print(f"{self.dryrun_suffix} head: '{head}'")
            print(f"{self.dryrun_suffix} is draft: '{draft}'")
            print(f"{self.dryrun_suffix} assignees: '{assignees}'")
            print(f"{self.dryrun_suffix} labels: '{labels}'")
        else:
            pull = self.inner.create_pull(title=title, body=body, base=base, head=head, draft=draft)
            for assignee in assignees:
                pull.add_to_assignees(assignee)

            for label in labels:
                pull.add_to_labels(label)

            return pull

    def create_git_ref(self, branch_ref_name, from_branch_sha):
        if self.dryrun:
            print(f'{self.dryrun_suffix} New branch created:')
            print(f"{self.dryrun_suffix} name: '{branch_ref_name}'")
            print(f"{self.dryrun_suffix} head: '{from_branch_sha}'")
        else:
            self.inner.create_git_ref(branch_ref_name, from_branch_sha)

    def compare(self, left_branch_ref, right_branch_ref):
        return self.inner.compare(left_branch_ref, right_branch_ref)

    def get_branch(self, branch):
        try:
            return self.inner.get_branch(branch)
        except Exception as ex:
            raise GithubException(f'unable to find branch "{branch}" due to {ex}') from ex
