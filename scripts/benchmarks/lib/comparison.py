"""
 Decides whether a benchmark measurement has regressed against its history.

 This module is deliberately free of influx, files and process exit, so the
 decision can be tested on its own. Callers do the logging and the exiting.
"""

from dataclasses import dataclass
from enum import Enum


class Policy(Enum):
    """
     Which directions of change count against a measurement.

     Benchmarks here measure times, counts, words and bytes, so a rise is a
     regression and a fall is usually an improvement. A steep fall can also
     mean the benchmark broke, hence the middle policy.
    """

    upward = "upward"
    upward_warn_on_drop = "upward-warn-on-drop"
    symmetric = "symmetric"

    def __str__(self):
        return self.value


class Verdict(Enum):
    ok = "ok"
    yellow = "yellow"
    red = "red"

    def __str__(self):
        return self.value


@dataclass(frozen=True)
class Comparison:
    """
     One measurement weighed against the moving average of its history.

     yellow_delta and red_delta are absolute allowances, already scaled from
     the ratios the caller passed in.
    """

    name: str
    value: float
    average: float
    yellow_delta: float
    red_delta: float
    verdict: Verdict
    unit: str = ""

    @property
    def deviation(self):
        return self.value - self.average

    @property
    def limit(self):
        """
         The limit this measurement broke, on the side it broke it. Meaningless
         for an ok verdict, where it reports the yellow limit it stayed within.
        """
        delta = self.red_delta if self.verdict is Verdict.red else self.yellow_delta
        return self.average + delta if self.deviation >= 0 else self.average - delta

    def quantity(self, value):
        """
         Renders a number in the unit it was measured in, when there is one.

         Limits carry the float noise of a ratio applied to a moving average,
         which no reader of a benchmark log needs, so they are rounded.
        """
        rounded = round(value, 2)
        return f"{rounded} {self.unit}" if self.unit else f"{rounded}"

    @property
    def message(self):
        moved = "exceeds" if self.deviation >= 0 else "dropped below"
        if self.verdict is Verdict.red:
            return (f"{self.name} {moved} red threshold "
                    f"({self.quantity(self.value)} against "
                    f"{self.quantity(self.limit)}). failing the build")
        if self.verdict is Verdict.yellow:
            return (f"WARNING: {self.name} {moved} yellow threshold "
                    f"({self.quantity(self.value)} against "
                    f"{self.quantity(self.limit)})")
        return (f"comparison succesful for {self.name}. "
                f"{self.quantity(self.value)} is within threshold "
                f"[yellow={self.quantity(self.average + self.yellow_delta)},"
                f"red={self.quantity(self.average + self.red_delta)}]")


def _grade(excess, yellow_delta, red_delta):
    """
     Grades how far a one-directional excess ran past the two allowances.
    """
    if excess > red_delta:
        return Verdict.red
    if excess > yellow_delta:
        return Verdict.yellow
    return Verdict.ok


def _demote(verdict):
    """
     Downgrades a breach to a warning, so a policy can flag a move without
     failing the build over it.
    """
    return Verdict.yellow if verdict is Verdict.red else verdict


def compare_measurement(name, value, average, yellow_ratio, red_ratio,
                        policy=Policy.upward, unit=""):
    """
     Weighs a measurement against the moving average of its history.

     The ratios are fractions of the average, so 0.3 allows a 30% move before
     the red verdict. Unit names what was measured so messages can report it,
     and never affects the verdict.
    """
    yellow_delta = abs(average) * yellow_ratio
    red_delta = abs(average) * red_ratio
    deviation = value - average

    if policy is Policy.symmetric:
        verdict = _grade(abs(deviation), yellow_delta, red_delta)
    elif deviation >= 0:
        verdict = _grade(deviation, yellow_delta, red_delta)
    elif policy is Policy.upward_warn_on_drop:
        verdict = _demote(_grade(-deviation, yellow_delta, red_delta))
    else:
        verdict = Verdict.ok

    return Comparison(name=name,
                      value=value,
                      average=average,
                      yellow_delta=yellow_delta,
                      red_delta=red_delta,
                      verdict=verdict,
                      unit=unit)
