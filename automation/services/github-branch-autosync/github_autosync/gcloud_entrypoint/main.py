import git_merge_me
import stable_branch
from lib.config import load as load_configuration

configuration = load_configuration('config.json')


def handle_git_merge_me_request(request):
    git_merge_me.handle_request(request, configuration)
    return "ok"


def handle_branch_sync_request(request):
    stable_branch.handle_request(request, configuration)
    return "ok"
