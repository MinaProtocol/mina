#!/usr/bin/env python3

import pandas as pd
import os, json
from datetime import datetime, timedelta
from pprint import pprint as pp
from pybuildkite.buildkite import Buildkite

OUTPUTDIR = os.environ.get("OUTPUTDIR", ".")
TOKEN = os.environ.get("BUILDKITE_TOKEN", "")
ORG = os.environ.get("BUILDKITE_ORG", "o-1-labs-2")
INTERVAL_MINS = int(os.environ.get("BUILDKITE_TRIGGER_INTERVAL_MINUTES", "200"))

now = datetime.now()
interval_ago = now - timedelta(minutes=INTERVAL_MINS)

buildkite = Buildkite()
buildkite.set_access_token(TOKEN)


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


# agents_response = buildkite.agents().list_all(organization=ORG)
# pipelines_response = buildkite.pipelines().list_pipelines(organization=ORG)

jobs_per_agent = {}
builds_response = buildkite.builds().list_all_for_org(organization=ORG, 
                                                      created_from=interval_ago)
for build in builds_response:
    # agents are selected at a step-level, i.e., jobs
    jobs = build['jobs']
    
    if len(jobs) == 0:
        continue

    for job in jobs:
        try:
            agent_name = job['agent']['name']
            if agent_name not in jobs_per_agent.keys():
                jobs_per_agent.setdefault(agent_name, 0)
            jobs_per_agent[agent_name] += 1
        except (TypeError, AttributeError) as e:
            continue
        except Exception as e:
            print("ERROR: at navigating job")
            print(f"ERROR: {e}")

# Metrics and dump call
# metrics-name generated at runtime
dynamic_metrics = { k + "-jobs.dat": v for k,v in jobs_per_agent.items() }

average_jobs_per_agent = 0.0
for jobs in jobs_per_agent.values():
    average_jobs_per_agent += float(jobs)
average_jobs_per_agent /= len(jobs_per_agent)

# static metrics with defined filenames
static_metrics = {
    "average-jobs-per-agent.dat": average_jobs_per_agent
}

metrics = {**static_metrics, **dynamic_metrics}
pp(metrics, indent=4)

# dumping
dump(metrics)