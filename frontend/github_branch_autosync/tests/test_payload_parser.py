import unittest
import json

from github_autosync.gcloud_entrypoint.lib.request_parser import GithubPayloadInfo

class TestPayloadParser(unittest.TestCase):

    data = None

    @classmethod
    def setUpClass(cls):
        with open("tests/payload.json",encoding="utf-8") as file:
            data = json.load(file)
        cls.data = data

    def test_incoming_branch(self):
        info = GithubPayloadInfo(self.data)
        self.assertEqual("rampup",info.incoming_branch)

    def test_commits(self):
        info = GithubPayloadInfo(self.data)
        commits = info.commits
        self.assertEqual(1,len(commits))
        commit = commits[0]
        self.assertEqual(["src/cucumber/debug.rs"],commit.files)
        self.assertEqual("change in berkeley",commit.message)

if __name__ == '__main__':
    unittest.main()

