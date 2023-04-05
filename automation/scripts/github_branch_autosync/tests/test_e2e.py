""" E2E tests for auto-sync merges"""

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

    def test_no_conflict(self):
        stage_1_branch,stage_2_branch,file_to_edit = self.generator.generate_unique_names()

        change = """develop
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"commit", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        left_sha = self.github.branch(stage_1_branch).commit.sha
        right_sha = self.github.branch(stage_2_branch).commit.sha

        self.assertEqual(left_sha,right_sha)

    def test_conflict(self):
        stage_1_branch,stage_2_branch,file_to_edit = self.generator.generate_unique_names()        

        change = """first_change
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"commit on stable branch", file_to_edit, change)

        change = """merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,stage_2_branch,"commit on unstable branch", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        prs = self.github.repository().get_pulls(base=stage_2_branch).get_page(0)

        self.assertEqual(len(prs),1)

        pr = prs[0]
        self.assertEqual(config.pr["assignees"],list(map(lambda x: x.login, pr.assignees)))
        self.assertTrue(config.pr["title_prefix"] in pr.title)
        self.assertEqual(config.pr["labels"],list(map(lambda x: x.name, pr.labels)))
        self.assertTrue(config.pr["body_prefix"] in pr.body)
        self.assertEqual(bool(config.pr["draft"]),pr.draft)

    def test_update_stable_branch_while_conflict(self):
        stage_1_branch,stage_2_branch,file_to_edit = self.generator.generate_unique_names()        


        change = """hot-fix
        """
        utils.create_simple_commit(self.github, config.github,stage_2_branch,"commit on unstable branch", file_to_edit, change)


        change = """first_merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"commit on stable branch", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        change = """update_merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"another commit on stable branch", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        temp_branch_sha = self.github.branch(config.tmp_branch_name(stage_1_branch,stage_2_branch)).commit.sha
        stable_branch_sha = self.github.branch(stage_1_branch).commit.sha
        hotfix_branch_sha = self.github.branch(stage_2_branch).commit.sha

        self.assertEqual(temp_branch_sha,stable_branch_sha)
        self.assertNotEqual(temp_branch_sha,hotfix_branch_sha)

    def test_update_stable_branch_while_conflict_causes_conflict_with_temp_branch(self):
        stage_1_branch,stage_2_branch,file_to_edit = self.generator.generate_unique_names()
        temp_branch = config.tmp_branch_name(stage_1_branch,stage_2_branch)    

        change = """hot-fix
        """
        utils.create_simple_commit(self.github, config.github,stage_2_branch,"commit on unstable branch", file_to_edit, change)

        change = """first_merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"commit on stable branch", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        change = """attempt_to_fix_merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,temp_branch,"commit on temp branch", file_to_edit, change)
 
        change = """update_merge_conflict
        """
        utils.create_simple_commit(self.github, config.github,stage_1_branch,"another commit on stable branch", file_to_edit, change)

        self.fire_commit_event(stage_1_branch)

        prs = self.github.repository().get_pulls(base=temp_branch,head=stage_1_branch).get_page(0)
        self.assertEqual(1,len(prs))

        prs = self.github.repository().get_pulls(base=temp_branch,head=stage_2_branch).get_page(0)
        self.assertEqual(1,len(prs))


    def fire_commit_event(self,branch):
        handle_incoming_commit_push_json(json={ "ref": "refs/heads/" + branch},config=config)

    @classmethod
    def tearDownClass(cls):
        cls.generator.tear_down()


if __name__ == '__main__':
    unittest.main()
