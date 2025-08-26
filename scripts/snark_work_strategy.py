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

# Handle large work spec in CLI
import tempfile

# Managing subprocesses
from concurrent.futures import ProcessPoolExecutor, as_completed

# The executable that is called by this script to perform and submit work. run_snark_worker.ml needs to be built before running this script
executable = "_build/default/src/lib/snark_worker/standalone/run_snark_worker.exe"

# TODO: we will probably want to generalize this with giving a public key / endpoint to some node that does not necessarily run locally
url = "http://localhost:3085/graphql"


# Generates a query that returns the specified range of pending snark work ([starting_index] included, [ending_index] excluded)
def pending_work_query(starting_index, ending_index):
    query = f"""
    {{
      snarkWorkRange(endingIndex: "{ending_index}", startingIndex: "{starting_index}") {{
        workBundleSpec {{
          spec
          snarkFee
        }}
      }}
    }}
    """
    return query.strip()  # strip() removes useless spaces


# This function parses the response as a list of (spec, id)
def format_response(response):
    pending_work = []
    for work_bundle_spec in response.json().get("data").get("snarkWorkRange"):
        work_bundle_spec = work_bundle_spec.get("workBundleSpec")
        pending_work.append(
            (work_bundle_spec.get("spec"), work_bundle_spec.get("snarkFee"))
        )
    return pending_work


# There are two types of pending work: completed and not completed yet.
# For the not completed work, we give the bid given by the CLI.
# For the already completed work, we halve the corresponding fee.
def set_fee(pending_work, bid, work_counter):
    pending_work_with_fee = []
    for work, fee in pending_work:
        if fee == None:
            print(
                f"{work_counter}-th work not completed yet; performing with fee = {bid}"
            )
            pending_work_with_fee.append((work, bid))
        # some work was already done, do it for half of the original fees
        elif float(fee) > 0:
            # fee unit is different when submitting and receiving
            # 1 submitted = 1000000000 received
            fee_ratio = 1000000000.0
            old_fee = float(fee) / fee_ratio
            new_fee = float(old_fee) / (2.0)
            print(
                f"{work_counter}-th work already completed with fee = {old_fee}; performing with fee = {new_fee}"
            )
            pending_work_with_fee.append((work, new_fee))
        else:  # fee = 0, do not perform the work
            print(f"{work_counter}-th work already completed with fee = {fee}; pass")
            pass
        work_counter += 1
    return pending_work_with_fee


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
def spawn_worker(work_spec, bid, public_key):
    try:
        # Create a temporary file to store the work_spec content which may be too large for the command line
        with tempfile.NamedTemporaryFile(
            delete=True, mode="w+", encoding="utf-8"
        ) as temp_file:
            temp_file.write(f"{work_spec}")
            temp_file.flush()  # Ensure the content is written to disk
            temp_file.seek(0)
            cmd = [
                executable,
                "--spec-json-file",
                temp_file.name,
                "--graphql-uri",
                url,
                "--snark-worker-fee",
                f"{bid}",
                "--snark-worker-public-key",
                public_key,
            ]
            print("Running", cmd)
            result = subprocess.run(
                cmd,
                check=True,
                capture_output=True,
                text=True,
            )
            print("Done", result.stdout)
    except subprocess.CalledProcessError as e:
        raise ValueError("Error:", e.stderr, e.stdout)
    return result.stdout


# Runs workers in parallel to produce work in [work_list]
def spawn_workers(work_list, public_key):
    print("Spawning worker processes...")
    with ProcessPoolExecutor() as executor:
        # Schedules the snark worker processes
        futures = {
            executor.submit(spawn_worker, work_spec, bid, public_key): (work_spec, bid)
            for (work_spec, bid) in work_list
        }
        # Collect results as they complete
        for future in as_completed(futures):
            try:
                result = future.result()
            except Exception as e:
                print(f"Worker generated an exception: {e}")


def main(bid, start_index, batch_size, public_key):
    end_index = start_index + batch_size
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
            pending_work = set_fee(pending_work, bid, start_index)
            spawn_workers(pending_work, public_key)
            start_index += batch_size
            end_index += batch_size


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch, perform & send snark work")
    parser.add_argument(
        "--bid",
        type=float,
        default=0,
        help="The bid to ask for each work performed. In case the work has already been completed, the bid is ignored and the existent fee is halved.",
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
    parser.add_argument(
        "--public-key",
        type=str,
        help="The public key to provide for the snark-work",
    )
    args = parser.parse_args()
    if args.public_key == None:
        print("Error: a --public-key is expected.")
        exit(1)
    main(args.bid, args.start, args.batch_size, args.public_key)
