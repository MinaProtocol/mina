#!/usr/bin/env python3

from string import Template
import os
import requests
import json
import pprint as pp
from datetime import date, timedelta


TOKEN = os.environ.get('GITHUB_TOKEN', '')
API = os.environ.get('GITHUB_API', 'https://api.github.com/graphql')
OUTPUTDIR = os.environ.get('OUTPUTDIR', '.')


owner = "MinaProtocol"
repos = ["mina"]
headers = {'Authorization': f'Bearer {TOKEN}'}

today= date.today().strftime("%Y-%m-%d")
yesterday = (date.today() - timedelta(days=1)).strftime("%Y-%m-%d")


## QUERIES
getTodayOpenPullRequestsTemplate = Template(
f"""
{{
    search(query: "is:pr is:open created:{yesterday}..{today} repo:$owner/$repo", type: ISSUE, first: 100, $cursorKeyValue) {{
        edges {{
            node {{
                ... on PullRequest {{
                    title
                    url
                    createdAt
                }}
            }}
            cursor
        }}
        pageInfo {{
            hasNextPage
            endCursor
        }}
    }}
}}""")


getOpenPrs = Template(
f"""
{{
    repository(owner: "$owner", name: "$repo") {{
        pullRequests(states: OPEN, first: 40, $cursorKeyValue) {{
            nodes {{
                number
                headRefName
                commits(last: 100) {{
                    nodes {{
                        commit {{
                            checkSuites(first: 100) {{
                                totalCount
                            }}
                        }}
                    }}
                }}
            }}
            pageInfo {{
                hasNextPage
                endCursor
            }}
        }}
    }}
}}""")


def triggerQuery(query: str) -> dict:
    """
    Triggers query and returns JSON response
    """
    
    # print(f"Query:\n{query}")
    request = requests.post(API, json={'query' : query}, headers=headers)

    if request.status_code == 200:
        return request.json()
    else:
        raise Exception(f'Query failed. Returning code {request.status_code}')


def dumpData(data: dict) -> None:
    """
    Dumps data to OUTPUTDIR
    """

    print(f'\n[DATA SUMMARY]')
    for k,v in data.items():
        print(f'\t[{k}]:\n\t\t{v}')

        if not os.path.exists(OUTPUTDIR):
            os.makedirs(OUTPUTDIR)

        _outputFileName = os.path.join(OUTPUTDIR, k)
        try:
            with open(_outputFileName, "w") as output:
                json.dump(v, output)
        except Exception as e:
            print(f'Could not dump {_outputFileName}: {e}')


def getPullRequests(owner: str, repo: str, cursor: str) -> int:
    """
    Gets the total number of Pull-Requests for today
    """

    pullRequests = []
    todayPrQuery = getTodayOpenPullRequestsTemplate.substitute({"owner": owner, "repo": repo, "cursorKeyValue": cursor})
    todayPrs = triggerQuery(todayPrQuery)

    pullRequests.extend(todayPrs['data']['search']['edges'])

    # are there more entries?
    pageInfo = todayPrs['data']['search']['pageInfo']
    if pageInfo['hasNextPage'] == True:
        endCursor = pageInfo['endCursor']
        cursor = f'after: "{endCursor}"'
        pullRequests.extend([getPullRequests(owner, repo, cursor)])

    return pullRequests


def getCiRunsForOpenPullRequests(owner: str, repo: str, cursor: str) -> list:
    """
    Computes the average CI runs per open PR over all branches
    """

    getOpenPrsQuery = getOpenPrs.substitute({"owner": owner, "repo": repo, "cursorKeyValue": cursor})
    response = triggerQuery(getOpenPrsQuery)

    openPrs = response['data']['repository']['pullRequests']['nodes']
    checkSuitesPerPr = []
    for pr in openPrs:
        checks = 0
        commits = pr['commits']['nodes']
        for commit in commits:
            checks += int(commit['commit']['checkSuites']['totalCount'])
        checkSuitesPerPr.append(checks)
    
    pageInfo = response['data']['repository']['pullRequests']['pageInfo']
    if pageInfo['hasNextPage'] == True:
        endCursor = pageInfo['endCursor']
        cursor = f'after: "{endCursor}"'
        checkSuitesPerPr.extend(getCiRunsForOpenPullRequests(owner, repo, cursor))

    return checkSuitesPerPr


def start() -> None:
    """
    Iteratively triggers API with queries
    """

    for repo in repos:
        # Build the query templates
        ## Today's pull-requests
        todaysPullRequests = getPullRequests(owner, repo, cursor="")

        ## Compute average CI runs over all open PRs in all branches
        ciRunsForOpenPrs = getCiRunsForOpenPullRequests(owner, repo, cursor="")

        dumpData({
            "today-pull-requests.dat": len(todaysPullRequests),
            "average-checks-per-pr.dat": sum(ciRunsForOpenPrs)/len(ciRunsForOpenPrs)
        })

if __name__ == "__main__":
    start()
