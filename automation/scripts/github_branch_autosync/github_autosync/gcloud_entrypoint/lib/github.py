''' Github api tailored for auto-sync needs'''

import json
from github import Github,PullRequest
import requests

class GithubException(Exception):
    """Exception raised for errors when interacting with Github REST api.

    Attributes:
        message -- explanation of the error
    """
    def __init__(self,  message):
        super().__init__(message)

class GithubApi:
    '''
    Responsible for various operation on github rest api 
    like creating new branches or merging changes.
    Is tightly coupled with config module
    '''

    def __init__(self, config):
        self.token = config["token"]
        self.username = config["username"]
        self.repo = config["repo"]
        self.github = Github(self.token)
        self.default_timeout = 60
        self.dryrun = bool(config["dryrun"])

    def repository(self):
        '''
            Retrieves github repository based on configuration       
        '''
        return Repository(self.github,
                self.username,
                self.repo,
                self.dryrun,
                self.get_authorization_header,
                self.default_timeout)

    def branch(self, name):
        '''
            Retrieves github branch from configured repository with given name

            Parameters:
                name (string): Branch name

            Returns:
                branch object
        '''
        return self.repository().get_branch(branch=name)

    def get_diff_commits(self, left_branch, right_branch):
        '''
            Retrieves differences between two branches

            Parameters:
                left_branch (string): Left branch name
                right_branch (string): Right branch name

            Returns:
                commit compare object
        '''

        left_branch_ref = self.branch(left_branch).commit.sha
        right_branch_ref = self.branch(right_branch).commit.sha
        return self.repository().compare(left_branch_ref, right_branch_ref)

    def has_merge_conflict(self,base_branch,head_branch):
        '''
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
        '''
        res = requests.get(f'https://github.com/{self.username}/{self.repo}/branches/pre_mergeable/{base_branch}...{head_branch}',
                           timeout=60)
        return "Able to merge" not in res.text

    def create_new_branch(self, branch_name, from_branch):
        '''
            Creates new branch

            Parameters:
                branch_name (string): New branch name
                from_branch (string): Branch name from which we create new branch

            Returns:
                new branch object
        '''
        from_branch_sha = self.branch(from_branch).commit.sha
        branch_ref_name = f"refs/heads/{branch_name}"

        return self.repository().create_git_ref(branch_ref_name,from_branch_sha)
    
    def fast_forward(self, source, target):
        '''
            Fast forward source branch name to target branch commit. Method extract head commit sha 
            from target branch and update reference sha of source branch.

            Unfortunately this method is not available in pygithub library. 
            Therefore we are accessing REST api directly

            Parameters:
                source (string): Branch name to update
                target (string): Branch name to which head commit we want to update

            Returns:
                fast forward response json

            Raises:
                GithubException: On request failure.
        '''

        target_sha = self.branch(name=target).commit.sha
        return self.repository().fast_forward(source,target_sha)

    @property
    def get_authorization_header(self):
        """
            Gets authorization header for situation when we need to bypass pygithub library
        """
        return {'Authorization': "Bearer " + self.token }

    def delete_branch(self, branch_name):
        '''
            Deletes branch. According to github documentation this operation will also remove
            all PRs that relates to given branch

            Parameters:
                branch_name (string): Branch name to delete

            Raises:
                GithubException: On request failure.
        '''
        self.repository().delete_branch(branch_name)

    def create_pull_request(self,config,source_branch,target_branch,new_branch):
        """ 
            Creates new pull request

            Parameters:
                config (config): Config module
                source_branch (string): Branch name from new branch was created
                target_branch (string): Branch name to which we want to merge changes
                new_branch (string): temporary branch which will be used to check mergeability and perform merge
            
            Returns:
                return PullRequest object
        """
        title = config.pr["title_prefix"] + f"into {source_branch} from {target_branch}"
        assignee_tags = list(map(lambda x: "@" + x, config.pr["assignees"]))
        separator = ", "
        body = config.pr["body_prefix"] + "\n" + separator.join(assignee_tags)
        base = target_branch
        head = new_branch
        draft = bool(config.pr["draft"])
        self.repository().create_pull(title=title,body=body,base=base,head=head,draft=draft,assignees=assignee_tags,labels=config.pr["labels"])
        return title
         
    def create_pull_request_for_tmp_branch(self,config,source_branch,temp_branch):
        """ 
            Creates new pull request

            Parameters:
                config (config): Config module
                source_branch (string): Branch name from new branch was created
                target_branch (string): Branch name to which we want to merge changes
                new_branch (string): temporary branch which will be used to check mergeability and perform merge
            
            Returns:
                return PullRequest object
        """
        title = config.pr["title_prefix"] + f"into {source_branch} from {temp_branch} for commit {self.branch(source_branch).commit.sha[0:6]}"
        assignee_tags = list(map(lambda x: "@" + x, config.pr["assignees"]))
        separator = ", "
        body = config.pr["body_prefix"] + "\n" + separator.join(assignee_tags)
        base = temp_branch
        head = source_branch
        draft = bool(config.pr["draft"])
        self.repository().create_pull(title,body,base,head,draft,assignees=config.pr["assigness"],labels=config.pr["labels"])
        return title
    
    def branch_exists(self, branch):
        """
            Returns true if branch by given name exists. False otherwise

            Parameters:
                branch (string): branch name
        """
        return any(x.name == branch for x in self.repository().get_branches())

    def merge(self,base,head,message):
        """
            Merges head branch to base branch

            Parameters:
                base (string): base branch name
                head (string): head branch name
                commit (string): commit message

        """
        self.repository().merge(base,head,message)
                
class Repository:
    """
        Class responsible for low level operation on github 
        For testing purposes it can be configured to just printout 
        operations meant to perform (dryrun)
    """

    def __init__(self,github,username,repo,dryrun,authorization_header,timeout):
        self.inner = github.get_repo(username + "/" + repo)
        self.username = username
        self.repo = repo
        self.dryrun = dryrun
        self.dryrun_suffix = "[DRYRUN]"
        self.authorization_header = authorization_header
        self.timeout = timeout

    def get_branches(self):
        return self.inner.get_branches()

    def merge(self,base,head,message):
        if self.dryrun:
            print(f'{self.dryrun_suffix} Merge {head} to {base} with message {message}')
        else:
            self.inner.merge(base,head,message)

    def create_pull(self,title,body,base,head,draft,assignees,labels):
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
            pull = self.inner.create_pull(title,body,base,head,draft)
            for assignee in assignees:
                pull.add_to_assignees(assignee)

            for label in labels:
                pull.add_to_labels(label)
    def create_git_ref(self,branch_ref_name,from_branch_sha):
        if self.dryrun:
            print(f'{self.dryrun_suffix} New branch created:')
            print(f"{self.dryrun_suffix} name: '{branch_ref_name}'")
            print(f"{self.dryrun_suffix} head: '{from_branch_sha}'")
        else:
            self.inner.create_git_ref(branch_ref_name,from_branch_sha)
    
    def compare(self,left_branch_ref, right_branch_ref):
        return self.inner.compare(left_branch_ref,right_branch_ref)
    
    def get_branch(self,branch):
        try:
            return self.inner.get_branch(branch)
        except Exception as ex:
            raise GithubException(f'unable to find branch "{branch}" due to {ex}') from ex
        
    def fast_forward(self,source,target_sha):
        if self.dryrun:
            print(f"{self.dryrun_suffix} Fast forward '{source}' to '{target_sha}'")
            return target_sha
        res = requests.patch(f"https://api.github.com/repos/{self.username}/{self.repo}/git/refs/heads/{source}",
                        json={"sha": target_sha},
                        headers=self.authorization_header,
                        timeout=self.timeout
                        )
        if res.status_code == 200:
            output =  json.loads(res.text)
            return output["object"]["sha"]
        raise GithubException(f'unable to fast forward branch {source} due to : {res.text}')
    
    def delete_branch(self,branch_name):
        if self.dryrun:
            print(f"{self.dryrun_suffix} Delete branch '{branch_name}'")
        else:
            res = requests.delete(f"https://api.github.com/repos/{self.username}/{self.repo}/git/refs/heads/{branch_name}",
                                headers=self.authorization_header,timeout=self.timeout)
            if not res.status_code == 204:
                raise GithubException(f"unable to delete branch '{branch_name}' due to : '{res.text}'. Status code: '{res.status_code}'")
