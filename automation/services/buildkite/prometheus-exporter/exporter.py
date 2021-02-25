from datetime import datetime, timedelta
import json
import os
import requests
import time

import asyncio

from functools import wraps

from python_graphql_client import GraphqlClient
from prometheus_client import start_http_server
from prometheus_client.core import CounterMetricFamily, GaugeMetricFamily, REGISTRY

API_KEY = os.getenv("BUILDKITE_API_KEY")
API_URL = os.getenv("BUILDKITE_API_URL", "https://graphql.buildkite.com/v1")

ORG_SLUG = os.getenv("BUILDKITE_ORG_SLUG", "o-1-labs-2")
PIPELINE_SLUG = os.getenv("BUILDKITE_PIPELINE_SLUG", "o-1-labs-2/mina").strip()
BRANCH = os.getenv("BUILDKITE_BRANCH", "*")

JOBS = os.getenv("BUILDKITE_JOBS", "")

MAX_JOB_COUNT = os.getenv("BUILDKITE_MAX_JOB_COUNT", 500)

MAX_AGENT_COUNT = os.getenv("BUILDKITE_MAX_AGENT_COUNT", 500)

MAX_ARTIFACTS_COUNT = os.getenv("BUILDKITE_MAX_ARTIFACT_COUNT", 500)

EXPORTER_SCAN_INTERVAL = os.getenv("BUILDKITE_EXPORTER_SCAN_INTERVAL", 3600)

METRICS_PORT = os.getenv("METRICS_PORT", 8000)


def timing(f):
    @wraps(f)
    def wrap(*args, **kw):
        ts = time.time()
        result = f(*args, **kw)
        te = time.time()

        try:
            print("function={func}, runtime={runtime}".format(func=f.__name__, runtime=te-ts))
        except:
            print("timing capture failed")

        return result
    return wrap


class Exporter(object):
    """Represents a (Coda) Buildkite pipeline exporter"""

    def __init__(self, client, api_key=API_KEY, org_slug=ORG_SLUG, pipeline_slug=PIPELINE_SLUG, branch=BRANCH, interval=EXPORTER_SCAN_INTERVAL):
        self.api_key = api_key
        self.org_slug = org_slug
        self.pipeline_slug = pipeline_slug
        self.branch = branch
        self.interval = interval

        self.ql_client = client

    @timing
    def execute_qlquery(self, query, vars=dict()):
        return asyncio.run(self.ql_client.execute_async(query=query, variables=vars))

    @timing
    def list_pipeline_stepkeys(self):
        result = []

        headers = {'Authorization': "Bearer {token}".format(token=API_KEY)}
        response = requests.get(
            "https://api.buildkite.com/v2/organizations/{org}/pipelines/{pipeline}/builds".format(
                org=self.org_slug,
                pipeline=self.pipeline_slug.replace(self.org_slug + '/', "")),
            headers=headers)
        data = response.json()
        for build in data:
          result.extend([d['step_key'] if d['step_key'] else "pipeline" for d in build['jobs']])

        return list(set(result)) 

    @timing
    def collect(self):
        print("Collecting...")

        # The metrics we want to export.
        metrics = {}
        metrics['job'] = {
            'runtime':
                GaugeMetricFamily('buildkite_job_runtime', 'Total job runtime',
                labels=['branch', 'exitStatus', 'state', 'passed', 'job', 'agentName', 'agentRules']),
            'waittime':
                GaugeMetricFamily('buildkite_job_waittime', 'Total time job waited to start (from time scheduled)',
                labels=['branch', 'exitStatus', 'state', 'passed', 'job', 'agentName', 'agentRules']),
            'status':
                CounterMetricFamily('buildkite_job_status', 'Count of in-progress job statuses over <scan-interval>',
                labels=['branch', 'state', 'job']),
            'exit_status':
                CounterMetricFamily('buildkite_job_exit_status', 'Count of job exit statuses over <scan-interval>',
                labels=['branch', 'exitStatus', 'softFailed', 'state', 'passed', 'job', 'agentName', 'agentRules']),
            'artifact_size':
                GaugeMetricFamily('buildkite_job_artifact_size', 'Total size of uploaded artifact (bytes)',
                labels=['branch', 'exitStatus', 'state', 'path', 'downloadURL', 'mimeType', 'job', 'agentName', 'agentRules']),
        }
        metrics['agent'] = {
            'total_count':
                CounterMetricFamily('buildkite_agent_total_count', 'Count of active Buildkite agents within <org>',
                labels=['version', 'versionHasKnownIssues','os', 'isRunning', 'metadata', 'connectionState'])
        }

        self.collect_job_data(metrics)
        self.collect_agent_data(metrics)

        for category in ['job', 'agent']:
            for m in metrics[category].values():
                yield m

        print("Metrics collected.")

    @timing
    def collect_job_data(self, metrics):
        scan_from = datetime.now() - timedelta(seconds=int(self.interval))
        query = """
            query jobQuery($slug: ID!, $createdAtFrom: DateTime, $branch: [String!], $jobLimit: Int, $jobKey: [String!], $jobArtifactLimit: Int){
                pipeline(slug:$slug) {
                    builds(createdAtFrom:$createdAtFrom, branch:$branch) {
                    edges {
                        node {
                        id
                        branch
                        commit
                        state
                        startedAt
                        finishedAt
                        message
                        jobs(first:$jobLimit, , step: { key:$jobKey }) {
                            edges {
                                node {
                                __typename
                                ... on JobTypeCommand {
                                    label
                                    step {
                                        key
                                    }
                                    agent {
                                        hostname
                                    }
                                    agentQueryRules
                                    command
                                    exitStatus
                                    startedAt
                                    finishedAt
                                    runnableAt
                                    scheduledAt
                                    softFailed
                                    passed
                                    state
                                    artifacts(first:$jobArtifactLimit) {
                                        edges {
                                            node {
                                                path
                                                downloadURL
                                                size
                                                state
                                                mimeType
                                                sha1sum
                                            }
                                        }
                                    }
                                }
                                }
                            }
                            }
                        }
                    }
                    }
                }
            }
        """

        vars = {
            "slug": self.pipeline_slug,
            "createdAtFrom": scan_from.isoformat(),
            "branch": self.branch,
            "jobLimit": MAX_JOB_COUNT,
            "jobKey": JOBS.split(',') if JOBS else self.list_pipeline_stepkeys(),
            "jobArtifactLimit": MAX_ARTIFACTS_COUNT
        }
        data = self.execute_qlquery(query=query, vars=vars)
        for d in data['data']['pipeline']['builds']['edges']:
            if len(d['node']['jobs']['edges']) > 0:
                for j in d['node']['jobs']['edges']:
                    scheduled_time = datetime.strptime(j['node']['scheduledAt'], '%Y-%m-%dT%H:%M:%S.%fZ')
                    # Completed job metrics
                    if j['node']['state'] == 'FINISHED':
                        start_time = datetime.strptime(j['node']['startedAt'], '%Y-%m-%dT%H:%M:%S.%fZ')
                        end_time = datetime.strptime(j['node']['finishedAt'], '%Y-%m-%dT%H:%M:%S.%fZ')

                        metrics['job']['runtime'].add_metric(
                            labels=[
                                d['node']['branch'],
                                j['node']['exitStatus'],
                                j['node']['state'],
                                str(j['node']['passed']),
                                j['node']['step']['key'],
                                j['node']['agent']['hostname'],
                                ','.join(j['node']['agentQueryRules'])
                            ],
                            value=(end_time - start_time).seconds
                        )

                        metrics['job']['waittime'].add_metric(
                            labels=[
                                d['node']['branch'],
                                j['node']['exitStatus'],
                                j['node']['state'],
                                str(j['node']['passed']),
                                j['node']['step']['key'],
                                j['node']['agent']['hostname'],
                                ','.join(j['node']['agentQueryRules'])
                            ],
                            value=(start_time - scheduled_time).seconds
                        )

                        metrics['job']['exit_status'].add_metric(
                            labels=[
                                d['node']['branch'],
                                j['node']['exitStatus'],
                                str(j['node']['softFailed']),
                                j['node']['state'],
                                str(j['node']['passed']),
                                j['node']['step']['key'],
                                j['node']['agent']['hostname'],
                                ','.join(j['node']['agentQueryRules'])
                            ],
                            value=1
                        )

                        if len(j['node']['artifacts']['edges']) > 0:
                            for a in j['node']['artifacts']['edges']:
                                # Emit artifact upload size and metadata if applicable
                                metrics['job']['artifact_size'].add_metric(
                                    labels=[
                                        d['node']['branch'],
                                        j['node']['exitStatus'],
                                        a['node']['state'],
                                        a['node']['path'],
                                        a['node']['downloadURL'],
                                        a['node']['mimeType'],
                                        j['node']['step']['key'],
                                        j['node']['agent']['hostname'],
                                        ','.join(j['node']['agentQueryRules'])
                                    ],
                                    value=a['node']['size']
                                )
                    else:
                        # In-progress/incomplete Job metrics
                        metrics['job']['status'].add_metric(
                            labels=[
                                d['node']['branch'],
                                j['node']['state'],
                                j['node']['step']['key']
                            ],
                            value=1
                        )

                        t = datetime.strptime(j['node']['startedAt'], '%Y-%m-%dT%H:%M:%S.%fZ') if j['node']['startedAt'] else datetime.now()
                        metrics['job']['waittime'].add_metric(
                            labels=[
                                d['node']['branch'],
                                j['node']['exitStatus'] or "undefined",
                                j['node']['state'],
                                str(j['node']['passed'] or "undefined"),
                                j['node']['step']['key'],
                                j['node']['agent']['hostname'] if j['node']['agent'] else "unassigned",
                                ','.join(j['node']['agentQueryRules'])
                            ],
                            value=(t - scheduled_time).seconds
                        )

    @timing
    def collect_agent_data(self, metrics):
        query = """
            query agentQuery($slug: ID!, $agentLimit: Int) {
                organization(slug:$slug) {
                    agents(first:$agentLimit) {
                    edges {
                        node {
                        name
                        hostname
                        ipAddress
                        operatingSystem {
                        name
                        }
                        userAgent
                        version
                        versionHasKnownIssues
                        createdAt
                        connectedAt
                        connectionState
                        heartbeatAt
                        isRunningJob
                        pid
                        public
                        metaData
                        userAgent
                        }
                    }
                    }
                }
            }
        """

        vars = {
            "slug": self.org_slug,
            "agentLimit": MAX_ARTIFACTS_COUNT
        }
        data = self.execute_qlquery(query=query, vars=vars)
        for d in data['data']['organization']['agents']['edges']:
            metrics['agent']['total_count'].add_metric(
                labels=[
                    d['node']['version'],
                    str(d['node']['versionHasKnownIssues']),
                    d['node']['operatingSystem']['name'],
                    str(d['node']['isRunningJob']),
                    ','.join(d['node']['metaData']),
                    d['node']['connectionState']
                ],
                value=1
            )

def main():
    headers = {
        'Authorization': 'Bearer {api_key}'.format(api_key=API_KEY),
        'Content-Type': 'application/json'
    }
    client = GraphqlClient(endpoint=API_URL, headers=headers)

    exporter = Exporter(client)
    REGISTRY.register(exporter)

    start_http_server(int(METRICS_PORT))
    print("Metrics on Port {}".format(METRICS_PORT))

    while True:
        time.sleep(5)


if __name__ == "__main__":
    print("Starting up...")
    main()
