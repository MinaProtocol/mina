# This file is a script that implement these steps:
# - Query snark work
# - Spawn snark worker processes
# - Dispach work among worker processes
# - Submit work via GraphQL
# Use it with `python3 scripts/snark_work_strategy.py` at the root of the mina/ repository, with a node running with a graphql endpoint at http://localhost:3085/graphql.

import argparse

# GraphQL requests
import requests

# Command line
import subprocess

# Managing subprocesses
from concurrent.futures import ProcessPoolExecutor, as_completed

# TODO: we will probably want to generalize this with giving a public key / endpoint to some node that does not necessarily run locally
url = "http://localhost:3085/graphql"


# Generates a query that returns the specified range of pending snark work ([starting_index] included, [ending_index] excluded)
def pending_work_query(starting_index, ending_index):
    query = f"""
    {{
      pendingSnarkWorkRange(endingIndex: "{ending_index}", startingIndex: "{starting_index}") {{
        workBundleSpec {{
          spec
          workIds
        }}
      }}
    }}
    """
    return query.strip()  # strip() removes useless spaces


# This function parses the response as a list of (spec, id)
def format_response(response):
    pending_work = []
    for work_bundle_spec in response.json().get("data").get("pendingSnarkWorkRange"):
        work_bundle_spec = work_bundle_spec.get("workBundleSpec")
        pending_work.append(
            (work_bundle_spec.get("spec"), work_bundle_spec.get("workIds"))
        )
    return pending_work


# This function returns a range of pending work specified by [start_index] (included) & [end_index] (excluded) obtain via the graphQL endpoint
def fetch_pending_work(start_index, end_index):
    body = pending_work_query(start_index, end_index)
    print(
        f"Fetching pending work between {start_index} and {end_index} in the pending snark work queue..."
    )
    response = requests.post(url=url, json={"query": body})
    if response.status_code != 200:
        raise ValueError("PendingSnarkWorkRange graphQL request status code is not 200")
    return format_response(response)


# call [_build/default/src/lib/snark_worker/standalone/run_snark_worker.exe]
# perform the work given by [work_spec] and send it to the graphql [endpoint]
def spawn_worker(work_spec, bid):
    try:
        result = subprocess.run(
            [
                "_build/default/src/lib/snark_worker/standalone/run_snark_worker.exe",
                "--spec-json",
                work_spec,
                "--graphql-uri",
                url,
                "--snark-worker-fee",
                f"{bid}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        print("Done", result.stdout)
    except subprocess.CalledProcessError as e:
        raise ValueError("Error:", e.stderr)
    return result.stdout


# Runs workers in parallel to produce work in [work_list]
def spawn_workers(work_list, bid):
    print("Spawning worker processes...")
    with ProcessPoolExecutor() as executor:
        # Schedules the snark worker processes
        futures = {
            executor.submit(spawn_worker, work_spec, bid): (work_spec, id)
            for (work_spec, id) in work_list
        }
        # Collect results as they complete
        for future in as_completed(futures):
            index = futures[future]
            try:
                result = future.result()
            except Exception as e:
                print(f"Worker number {index} generated an exception: {e}")


def main(bid, start_index, batch_size):
    end_index = batch_size
    while True:
        pending_work = fetch_pending_work(start_index, end_index)
        # if no pending work was received, it means that either the node has not start yet, or we went over the size of the pending snark work list. In these cases we just reset the indices to go back from the beginning
        if pending_work == []:
            start_index, end_index = 0, batch_size
            print(
                f"No pending work received. Asking for pending works between {start_index} and {batch_size}"
            )
        else:
            print("Pending work was retreived successfully.")
            spawn_workers(pending_work, bid)
            start_index += batch_size
            end_index += batch_size


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch, perform & send snark work")
    parser.add_argument(
        "--bid", type=int, default=0, help="The bid to ask for each work performed"
    )
    parser.add_argument(
        "--start",
        type=int,
        default=0,
        help="The index from which to start to fetch work in the pending work queue",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=5,
        help="The size of range of work to query and complete. A same amount of worker processes will be spawned",
    )
    args = parser.parse_args()
    main(args.bid, args.start, args.batch_size)
