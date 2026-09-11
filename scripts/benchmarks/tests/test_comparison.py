import unittest

from lib.comparison import Policy, Verdict, compare_measurement


class TestCompareMeasurement(unittest.TestCase):
    """
     Exercises the verdict on its own, with no influx and no csv in the way.
    """

    average = 1000.0
    yellow = 0.1
    red = 0.3

    def verdict(self, value, policy=Policy.upward):
        return compare_measurement(name="Parallel_scan.Merge.t",
                                   value=value,
                                   average=self.average,
                                   yellow_ratio=self.yellow,
                                   red_ratio=self.red,
                                   policy=policy).verdict

    def test_measurement_on_the_baseline_is_ok(self):
        self.assertIs(Verdict.ok, self.verdict(self.average))

    def test_measurement_marginally_below_baseline_is_ok(self):
        """
         Shape of the false failure in build 42209, where a history averaging
         0.3 above the measurement was read as a regression.
        """
        comparison = compare_measurement(name="Parallel_scan.Merge.t",
                                         value=8696.0,
                                         average=8696.3,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red)
        self.assertIs(Verdict.ok, comparison.verdict)

    def test_rise_within_yellow_is_ok(self):
        self.assertIs(Verdict.ok, self.verdict(1099.0))

    def test_rise_past_yellow_warns(self):
        self.assertIs(Verdict.yellow, self.verdict(1200.0))

    def test_rise_past_red_fails(self):
        self.assertIs(Verdict.red, self.verdict(1500.0))

    def test_threshold_is_exclusive(self):
        self.assertIs(Verdict.ok, self.verdict(self.average * 1.1))
        self.assertIs(Verdict.yellow, self.verdict(self.average * 1.3))

    def test_upward_policy_ignores_any_drop(self):
        self.assertIs(Verdict.ok, self.verdict(1.0))

    def test_warn_on_drop_policy_warns_instead_of_failing(self):
        policy = Policy.upward_warn_on_drop
        self.assertIs(Verdict.ok, self.verdict(950.0, policy))
        self.assertIs(Verdict.yellow, self.verdict(800.0, policy))
        self.assertIs(Verdict.yellow, self.verdict(1.0, policy))
        self.assertIs(Verdict.red, self.verdict(1500.0, policy))

    def test_symmetric_policy_fails_on_a_steep_drop(self):
        policy = Policy.symmetric
        self.assertIs(Verdict.ok, self.verdict(950.0, policy))
        self.assertIs(Verdict.yellow, self.verdict(800.0, policy))
        self.assertIs(Verdict.red, self.verdict(1.0, policy))
        self.assertIs(Verdict.red, self.verdict(1500.0, policy))

    def test_message_names_the_limit_that_was_broken(self):
        comparison = compare_measurement(name="Parallel_scan.Merge.t",
                                         value=1500.0,
                                         average=self.average,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red)
        self.assertIn("exceeds red threshold", comparison.message)
        self.assertIn("1500.0 against 1300.0", comparison.message)

    def test_message_reports_the_unit_when_there_is_one(self):
        comparison = compare_measurement(name="Parallel_scan.Merge.t",
                                         value=1500.0,
                                         average=self.average,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red,
                                         unit="words")
        self.assertIn("1500.0 words against 1300.0 words", comparison.message)

    def test_message_reports_the_unit_on_success_too(self):
        comparison = compare_measurement(name="Parallel_scan.Merge.t",
                                         value=1000.0,
                                         average=self.average,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red,
                                         unit="bytes")
        self.assertIn("1000.0 bytes is within threshold", comparison.message)
        self.assertIn("yellow=1100.0 bytes", comparison.message)

    def test_message_omits_the_unit_for_a_bare_count(self):
        comparison = compare_measurement(name="proofs updates",
                                         value=1500.0,
                                         average=self.average,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red)
        self.assertIn("1500.0 against 1300.0", comparison.message)

    def test_message_reports_the_direction_of_a_drop(self):
        comparison = compare_measurement(name="Parallel_scan.Merge.t",
                                         value=500.0,
                                         average=self.average,
                                         yellow_ratio=self.yellow,
                                         red_ratio=self.red,
                                         policy=Policy.symmetric)
        self.assertIn("dropped below red threshold", comparison.message)
        self.assertIn("500.0 against 700.0", comparison.message)


if __name__ == "__main__":
    unittest.main()
