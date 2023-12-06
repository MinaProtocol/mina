from datetime import datetime, timedelta
import contextlib
import pickle
import pandas as pd
import json
import os
from pybuildkite.buildkite import Buildkite, BuildState

DEBUG = False
OUTPUTDIR = os.environ.get("OUTPUTDIR", ".")
TOKEN = os.environ.get("BUILDKITE_TOKEN", "")


def log(s=""):
    if DEBUG:
        print(s)


buildkite = Buildkite()
buildkite.set_access_token(TOKEN)

total_days = 1
_to = datetime.now()
_from = _to - timedelta(days=total_days)

filename = _from.strftime("%m-%d-%Y") + "_" + _to.strftime("%m-%d-%Y")


def fetch_builds_with_state(page, states, retries=True):
    return buildkite.builds().list_all_for_pipeline(
        "o-1-labs-2",
        "mina",
        states=states,
        created_from=_from,
        created_to=_to,
        include_retried_jobs=retries,
        page=page,
        with_pagination=True,
    )


def get_all_builds():
    builds = {"all": []}
    page = 0
    while True:
        result = fetch_builds_with_state(
            page=page,
            states=[BuildState.PASSED, BuildState.CANCELED, BuildState.FAILED],
            retries=True,
        )
        for i in range(len(result.body)):
            if not result.body[i].get("author") is None:
                author = result.body[i]["author"]["name"]
                if author not in builds:
                    builds[author] = []
                builds[author].append(result.body[i])
            builds["all"].append(result.body[i])

        if result.next_page:
            page = result.next_page
        else:
            break

    return builds


def get_build_stats(builds):
    build_data = []
    for build in builds:
        cleaned_build = {
            k: v
            for k, v in build.items()
            if (k != "jobs" and k != "pipeline" and k != "metadata")
        }
        build_data.append(cleaned_build)

    df = pd.DataFrame.from_dict(build_data)
    df["build_time_m"] = (
        pd.to_datetime(df["finished_at"]) - pd.to_datetime(df["created_at"])
    ).dt.total_seconds() / 60
    df["build_time_h"] = df["build_time_m"] / 60
    return df


def get_job_stats(all_builds):
    cleaned_data = []
    for a_build in all_builds:
        all_jobs_in_a_build = a_build["jobs"]
        for a_job_in_a_build in all_jobs_in_a_build:
            if (
                a_job_in_a_build.get("finished_at") is None
                or a_job_in_a_build.get("created_at") is None
            ):
                continue

            cleaned_data.append(a_job_in_a_build)

    df = pd.DataFrame.from_dict(cleaned_data)
    df["run_time_in_minutes"] = (
        pd.to_datetime(df["finished_at"]) - pd.to_datetime(df["created_at"])
    ).dt.total_seconds() / 60
    df["run_time_in_hours"] = df["run_time_in_minutes"] / 60
    return df


def get_df_groupedby_job_name_sorted_by_run_time(df):
    grouped_df = df.groupby(by=["name"], dropna=False)
    agg_filter = {
        "run_time_in_minutes": ["mean"],
        "run_time_in_hours": [sum],
        "proportion": [sum],
        "name": ["count"],
    }
    grouped_df = grouped_df.aggregate(agg_filter)
    sorted_df = grouped_df.sort_values([("run_time_in_hours", "sum")], ascending=False)
    return sorted_df


def get_df_groupedby_exit_status_and_name(df):
    grouped_df = df.groupby(by=["name", "exit_status"], dropna=False)
    agg_filter = {
        "run_time_in_minutes": ["mean"],
        "run_time_in_hours": [sum],
        "proportion": [sum],
        "name": ["count"],
    }
    grouped_df = grouped_df.aggregate(agg_filter)
    return grouped_df


def successful_runs_with_greater_than_n_retries(builds_df, retry_limit):
    successful_build = list(filter(lambda build: build["state"] == "passed", builds_df))

    def has_more_than_n_retries(build_df):
        jobs = filter(lambda job: job["type"] != "waiter", build_df["jobs"])
        jobs_with_retries_above_limit = filter(
            lambda job: job["retries_count"] is not None
            and job["retries_count"] > retry_limit,
            jobs,
        )
        return any(jobs_with_retries_above_limit)

    return any(filter(lambda build: has_more_than_n_retries(build), successful_build))


def get_stats_for_builds(all_builds_for_all_users):
    data = {}
    for key, all_builds_for_a_user in all_builds_for_all_users.items():
        if key not in data:
            data[key] = {}

        if len(all_builds_for_a_user) > 0:
            jobs_df = get_job_stats(all_builds_for_a_user)
            builds_df = get_build_stats(all_builds_for_a_user)

            total_build_time = builds_df["build_time_h"].sum()
            jobs_df["proportion"] = jobs_df["run_time_in_hours"] / (total_days * 24)

            auto_mask = jobs_df["retry_type"] == "automatic"
            manual_mask = jobs_df["retry_type"] == "manual"
            auto_retried_df = jobs_df[auto_mask]
            manual_retried_df = jobs_df[manual_mask]

            retried_mask = jobs_df["retries_count"] > 0
            retried_df = jobs_df[retried_mask]
            not_retried_df = jobs_df[~retried_mask]

            number_of_builds = len(builds_df)

            data[key]["number_of_builds"] = number_of_builds
            data[key]["building_time_in_hours"] = round(total_build_time, 2)
            data[key]["average_build_time_in_hours"] = round(
                total_build_time / number_of_builds, 2
            )

            successful_runs_with_greater_than_4_retries = (
                successful_runs_with_greater_than_n_retries(all_builds_for_a_user, 4)
            )
            data[key]["reliability"] = int(
                float(
                    float(
                        number_of_builds - successful_runs_with_greater_than_4_retries
                    )
                    / float(number_of_builds)
                )
                * 100
            )

            not_retried_passed_mask = not_retried_df["state"] == "passed"
            not_retried_failed_mask = not_retried_df["state"] == "failed"
            not_retried_canceled_mask = not_retried_df["state"] == "canceled"

            retried_passed_mask = retried_df["state"] == "passed"
            retried_failed_mask = retried_df["state"] == "failed"
            retried_canceled_mask = retried_df["state"] == "canceled"

            if key == "all":
                log_urls = jobs_df[
                    (jobs_df["name"] == "dev unit-tests")
                    & (jobs_df["state"] != "passed")
                ]["log_url"].to_list()

                if DEBUG:
                    with open("log_file_urls.json", "w", encoding="utf-8") as f:
                        f.write(json.dumps(log_urls, ensure_ascii=False))
                        log("Log URLs saved to a JSON file")

            data[key]["jobs"] = {
                "executions": len(jobs_df),
                "retries": len(retried_df),
                "no_retries": len(not_retried_df),
                "auto_retries": len(auto_retried_df),
                "manual_retries": len(manual_retried_df),
                "failed": {
                    "retried": {
                        "total": len(retried_df[retried_failed_mask]),
                        "stats": None,
                    },
                    "not_retried": {
                        "total": len(not_retried_df[not_retried_failed_mask]),
                        "stats": None,
                    },
                },
                "passed": {
                    "retried": {
                        "total": len(retried_df[retried_passed_mask]),
                        "stats": None,
                    },
                    "not_retried": {
                        "total": len(not_retried_df[not_retried_passed_mask]),
                        "stats": None,
                    },
                },
                "canceled": {
                    "retried": {
                        "total": len(retried_df[retried_canceled_mask]),
                        "stats": None,
                    },
                    "not_retried": {
                        "total": len(not_retried_df[not_retried_canceled_mask]),
                        "stats": None,
                    },
                },
            }

            # Stats for failed jobs, which CI did retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                retried_df[retried_failed_mask]
            )
            data[key]["jobs"]["failed"]["retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

            # Exit status codes:')
            df = get_df_groupedby_exit_status_and_name(retried_df[retried_failed_mask])
            data[key]["jobs"]["failed"]["retried"]["exit_status"] = json.loads(
                df.to_json(orient="index")
            )

            # Failed and retried job urls for by exit status
            grouped_df = retried_df[retried_failed_mask].groupby(
                by=["exit_status"], dropna=False
            )
            data[key]["jobs"]["failed"]["retried"][
                "urls_by_exit_status"
            ] = grouped_df.apply(
                lambda x: list(x["web_url"].to_dict().values())
            ).to_dict()

            # Stats for failed jobs, which did not retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                not_retried_df[not_retried_failed_mask]
            )
            data[key]["jobs"]["failed"]["not_retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

            # Stats for passed jobs, which CI did retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                retried_df[retried_passed_mask]
            )
            data[key]["jobs"]["passed"]["retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

            # Stats for passed jobs, which CI did not retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                not_retried_df[not_retried_passed_mask]
            )
            data[key]["jobs"]["passed"]["not_retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

            # Stats for canceled jobs, which CI did retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                retried_df[retried_canceled_mask]
            )
            data[key]["jobs"]["canceled"]["retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

            # Stats for canceled jobs, which CI did not retry
            df_sorted = get_df_groupedby_job_name_sorted_by_run_time(
                not_retried_df[not_retried_canceled_mask]
            )
            data[key]["jobs"]["canceled"]["not_retried"]["stats"] = json.loads(
                df_sorted.to_json(orient="index")
            )

    return data


def ciMetricsDashboard(results: dict) -> None:
    """
    Computes metrics to be pushed to the CI Metrics Dashboard
    """

    passedWithRetries = results["all"]["jobs"]["passed"]["retried"]
    retries = []
    for _,stat in passedWithRetries["stats"].items():
        retries.append(int(stat["('name', 'count')"]))

    ciMetrics = {
        "reliability.dat": results["all"]["reliability"],
        "ci-builds.dat": results["all"]["number_of_builds"],
        "avg-time-per-build-hours.dat": results["all"]["average_build_time_in_hours"],
        "executions.dat" : results["all"]["jobs"]["executions"],
        "retries-per-passed-test.dat": pd.Series(retries).fillna(0).mean()
    }

    for k, v in ciMetrics.items():
        print(f"{k}: {v}")
        if not os.path.exists(OUTPUTDIR):
            os.makedirs(OUTPUTDIR)

        _outputFileName = os.path.join(OUTPUTDIR, k)
        try:
            with open(_outputFileName, "w") as output:
                json.dump(v, output)
        except Exception as e:
            print(f"Could not dump {_outputFileName}: {e}")


def run(force_clean_state=False):
    log("Checking for BK builds in cache")
    all_builds = []
    pkl_filename = filename + "_builds.pkl"

    # Remove old log files
    with contextlib.suppress(FileNotFoundError):
        os.remove("log_file_urls.json")
        log("Removed old json log files")

    if DEBUG:
        # Read dictionary pkl file
        try:
            fp = None
            with open(pkl_filename, "rb") as fp:
                all_builds = pickle.load(fp)
        except IOError:
            log("Nothing found")

    if len(all_builds) == 0 or force_clean_state is True:
        log("Fetching BK builds from API...")
        all_builds = get_all_builds()

        if DEBUG:
            with open(pkl_filename, "wb") as fp:
                pickle.dump(all_builds, fp)
                log("Builds were cached to a file")
    else:
        log("Found builds in cache, continuing...")

    results = get_stats_for_builds(all_builds)

    if DEBUG:
        with open("results.json", "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=3)

    # Relevant metrics for CI Metrics Dashboard
    ciMetricsDashboard(results)


if __name__ == "__main__":
    run()
