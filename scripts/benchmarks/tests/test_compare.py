import logging
import tempfile
import unittest
from pathlib import Path

from lib.bench import HeapUsageBenchmark
from lib.comparison import Policy


class FakeRecord(dict):
    pass


class FakeTable:

    def __init__(self, average, size):
        self.records = [FakeRecord(_value=average) for _ in range(size)]


class FakeInflux:
    """
     Stands in for Influx so comparison can be exercised without a database.
     Answers with a flat history at the average recorded for each field.
    """

    def __init__(self, averages, moving_average_size=10):
        self.averages = averages
        self.moving_average_size = moving_average_size

    def query_moving_average(self, name, branch, field, branch_header):
        return [FakeTable(self.averages[str(field)], self.moving_average_size)]


def write_result(directory, heap_words):
    """
     Writes one heap usage row in the influx annotated csv layout compare reads.
    """
    result = Path(directory) / "result.csv"
    result.write_text("#datatype ignored\n"
                      "Name,heap words,bytes,category,gitbranch\n"
                      f"Parallel_scan.Merge.t,{heap_words},{heap_words * 8},"
                      "heap_usage,compatible\n")
    return str(result)


class TestBenchmarkCompare(unittest.TestCase):
    """
     Exercises the shell around the comparator: csv reading, influx lookup,
     log level per verdict and the exit code.
    """

    average = 8696.0
    yellow = 0.1
    red = 0.3

    def compare(self, heap_words, policy=Policy.upward):
        bench = HeapUsageBenchmark()
        bench.influx_client = FakeInflux({
            "heap words": self.average,
            "bytes": self.average * 8
        })
        with tempfile.TemporaryDirectory() as tmp:
            bench.compare(write_result(tmp, heap_words), self.yellow, self.red,
                          policy)

    def test_measurement_at_baseline_logs_success(self):
        with self.assertLogs("lib.bench", level=logging.INFO) as logs:
            self.compare(self.average)
        self.assertTrue(
            any("comparison succesful" in line for line in logs.output))

    def test_measurement_above_yellow_warns(self):
        with self.assertLogs("lib.bench", level=logging.WARNING) as logs:
            self.compare(self.average * 1.2)
        self.assertTrue(
            any("exceeds yellow threshold" in line for line in logs.output))

    def test_measurement_above_red_fails_the_build(self):
        with self.assertLogs("lib.bench", level=logging.ERROR):
            with self.assertRaises(SystemExit) as exit_code:
                self.compare(self.average * 1.5)
        self.assertEqual(1, exit_code.exception.code)

    def test_policy_reaches_the_comparator(self):
        with self.assertLogs("lib.bench", level=logging.ERROR):
            with self.assertRaises(SystemExit):
                self.compare(self.average * 0.5, Policy.symmetric)

    def test_short_history_is_skipped(self):
        bench = HeapUsageBenchmark()
        bench.influx_client = FakeInflux({})
        bench.influx_client.query_moving_average = (
            lambda *args: [FakeTable(self.average, 3)])
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertLogs("lib.bench", level=logging.WARNING) as logs:
                bench.compare(write_result(tmp, 99999), self.yellow, self.red)
        self.assertTrue(
            any("Skipping comparison" in line for line in logs.output))


if __name__ == "__main__":
    unittest.main()
