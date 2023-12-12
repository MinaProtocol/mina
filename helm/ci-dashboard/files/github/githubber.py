#!/usr/bin/env python3

import os, pprint, json
from datetime import date
from github import Github, Auth

TOKEN = os.environ.get('GITHUB_TOKEN', '')
OUTPUTDIR = os.environ.get('OUTPUTDIR', '.')

def dump(data: dict) -> None:
    """
    Dumps data to OUTPUTDIR
    """

    for k,v in data.items():
        if not os.path.exists(OUTPUTDIR):
            os.makedirs(OUTPUTDIR)

        _outputFileName = os.path.join(OUTPUTDIR, k)
        try:
            with open(_outputFileName, "w") as output:
                json.dump(v, output)
        except Exception as e:
            print(f'Could not dump {_outputFileName}: {e}')


repos = ["MinaProtocol/mina"]
today = date.today()

auth = Auth.Token(TOKEN)
g = Github(auth=auth)

today_pull_requests = 0
average_checks_per_pr = 0

for repo in repos:
    try:
        r = g.get_repo(repo, True)
        print(f"Repo: {r.name}")

        # Collecting Open Pull-Requests
        pull_requests = r.get_pulls(state='open', sort='created', direction='desc')
        if pull_requests.totalCount == 0:
            continue

        print(f"{pull_requests.totalCount} Open Pull-Requests:")
        for pr in pull_requests:
            if (today - pr.created_at.date()).days <= 1:
                print(f"\t [{pr.created_at}] PR #{pr.number}: {pr.title}. Url: {pr.html_url}")
                today_pull_requests += 1
                
                # checking runs for 1d-old open prs
                checks = 0
                for commit in pr.get_commits():
                    check_suites = commit.get_check_suites()
                    for suite in check_suites:
                        check_runs = suite.get_check_runs()
                        checks += check_runs.totalCount
                print(f"\t\t# of Runs: {checks}")
                average_checks_per_pr += checks
        print("\n")        
    except Exception as e:
        print(f"Error: {e}")
    
g.close()

average_checks_per_pr = float(average_checks_per_pr / today_pull_requests)
metrics = {
    "today-pull-requests.dat": today_pull_requests,
    "average-checks-per-pr.dat": average_checks_per_pr
}
pprint.pprint(metrics, indent=4)

dump(metrics)