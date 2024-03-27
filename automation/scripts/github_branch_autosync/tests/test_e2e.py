""" E2E tests for auto-sync merges"""

import random
import unittest
from github_autosync.gcloud_entrypoint.main import handle_incoming_commit_push_json
from tests import config,utils
from github_autosync.gcloud_entrypoint.lib.github import GithubApi

class TestEndToEndFlow(unittest.TestCase):

    generator = None
    github = None

    @classmethod
    def setUpClass(cls):
        cls.generator = utils.BranchNamesGenerator()
        cls.github = GithubApi(config.github)

    def push_commit_to(self, branch,some_source_file):
        change = "change" + str(random.randint(0, 100_000))
        utils.create_simple_commit(self.github, config.github,branch,"commit", some_source_file, change)

    def assert_on_the_same_commit(self, left, right):
        left_sha = self.github.branch(left).commit.sha
        right_sha = self.github.branch(right).commit.sha

        self.assertEqual(left_sha,right_sha)

    def assert_temp_sync_branch_created(self, new_branch):
        self.assertTrue(self.github.branch_exists(new_branch))

    def assert_temp_sync_branch_was_cleaned(self,base,head):
        self.assertFalse(self.github.branch_exists(config.tmp_branch_name(base,head)))

    def assert_pr_created(self,base,head):
        prs = self.github.repository().get_pulls(base,head).get_page(0)

        self.assertEqual(len(prs),1)

        pr = prs[0]
        self.assertEqual(config.pr["assignees"],list(map(lambda x: x.login, pr.assignees)))
        self.assertTrue(config.pr["title_prefix"] in pr.title)
        self.assertEqual(config.pr["labels"],list(map(lambda x: x.name, pr.labels)))
        self.assertTrue(config.pr["body_prefix"] in pr.body)
        self.assertEqual(bool(config.pr["draft"]),pr.draft)

    def handle_commit_event(self,branch):
        handle_incoming_commit_push_json(json={ "ref": "refs/heads/" + branch},config=config)

    def test_no_conflict(self):
        compatible,develop,some_source_file = self.generator.generate_unique_names()
        
        
        self.push_commit_to(compatible,some_source_file)
        self.handle_commit_event(compatible)
       
        self.assert_on_the_same_commit(compatible,develop)
        self.assert_temp_sync_branch_was_cleaned(compatible,develop)

    def test_conflict(self):
        compatible,develop,some_source_file = self.generator.generate_unique_names()     

        # Creating conflict
        self.push_commit_to(develop,some_source_file)
        self.push_commit_to(compatible,some_source_file)

        self.handle_commit_event(compatible)

        temp_sync_branch = config.tmp_branch_name(compatible,develop)
        self.assert_temp_sync_branch_created(temp_sync_branch)
        self.assert_pr_created(base=develop,head=temp_sync_branch)

    def test_update_stable_branch_while_conflict(self):
        compatible,develop,some_source_file = self.generator.generate_unique_names()        

        # Creating conflict
        self.push_commit_to(develop,some_source_file)
        self.push_commit_to(compatible,some_source_file)

        self.handle_commit_event(compatible)

        temp_sync_branch = config.tmp_branch_name(compatible,develop)
        self.assert_pr_created(base=develop,head=temp_sync_branch)

        self.push_commit_to(compatible,some_source_file)
        self.handle_commit_event(compatible)

        # sync branch should fast forward to compatible head
        temp_branch_head = self.github.branch(temp_sync_branch).commit.sha
        compatible_head = self.github.branch(compatible).commit.sha
        develop_head = self.github.branch(develop).commit.sha

        self.assertEqual(temp_branch_head,compatible_head)
        self.assertNotEqual(compatible_head,develop_head)

    def test_update_stable_branch_while_conflict_causes_conflict_with_temp_branch(self):
        compatible,develop,some_source_file = self.generator.generate_unique_names()
        temp_branch = config.tmp_branch_name(compatible,develop)

        # Creating conflict
        self.push_commit_to(develop,some_source_file)
        self.push_commit_to(compatible,some_source_file)

        self.handle_commit_event(compatible)

        # attempt to fix merge conflict
        self.push_commit_to(temp_branch,some_source_file)

        # but then compatible got yet another commit which now creates conflict not only with develop
        # but also with sync branch
        self.push_commit_to(compatible,some_source_file)

        self.handle_commit_event(compatible)

        # as a result we should have two prs original one and new for fixing intermittent conflict
        self.assert_pr_exist(base=temp_branch,head=compatible)
        self.assert_pr_exist(base=temp_branch,head=develop)

    def assert_pr_exist(self,base,head):
        prs = self.github.repository().get_pulls(base,head).get_page(0)
        self.assertEqual(1,len(prs))

    @classmethod
    def tearDownClass(cls):
        cls.generator.tear_down()


if __name__ == '__main__':
    unittest.main()
