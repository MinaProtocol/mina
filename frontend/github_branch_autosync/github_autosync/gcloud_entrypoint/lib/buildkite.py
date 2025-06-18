'''
    Module for Buildkite operations
'''
from pybuildkite.buildkite import Buildkite

class BuildkiteApi:
    """ Api for running buildkite pipeline. Currently not used"""

    def __init__(self, config):
        self.buildkite = Buildkite()
        self.buildkite.set_access_token(config["token"])
        self.org = config["org"]
        self.pipeline = config["pipeline"]


    def run_pipeline(self, sha, branch, message):   
        '''
        Runs pipeline for given branch.

        Parameters:
            sha (str): Commit sha.
            branch (str): Branch name.
            message (str): Message seen on buildkite job.
        Returns:
            Buildkite pipeline handle.   
        '''
        return self.buildkite.builds().create_build(self.org, self.pipeline, sha, branch, 
        clean_checkout=True, message=message)
