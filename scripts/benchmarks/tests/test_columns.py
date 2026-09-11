import unittest

from lib.bench import (ArchiveBenchmark, HeapUsageBenchmark,
                       JaneStreetBenchmark, LedgerApplyBenchmark,
                       MinaBaseBenchmark, SnarkBenchmark,
                       ZkappLimitsBenchmark)
from lib.influx import FieldColumn


class TestFieldColumn(unittest.TestCase):
    """
     Guards the split between the unit that names an influx series and the
     unit that is only ever shown to a reader.
    """

    def test_display_unit_falls_back_to_unit(self):
        column = FieldColumn("time", 1, "ms")
        self.assertEqual("ms", column.display_unit)

    def test_display_unit_stays_out_of_the_influx_field_name(self):
        column = FieldColumn("heap words", 1, "", display_unit="words")
        self.assertEqual("heap words", str(column))

    def test_unit_still_names_the_influx_field(self):
        self.assertEqual("Time/Run [us]", str(MinaBaseBenchmark.time_per_runs))

    def test_heap_usage_fields_report_words_and_bytes(self):
        self.assertEqual("words", HeapUsageBenchmark.heap_words.display_unit)
        self.assertEqual("bytes", HeapUsageBenchmark.bytes.display_unit)

    def test_heap_usage_series_names_are_unchanged(self):
        self.assertEqual("heap words", str(HeapUsageBenchmark.heap_words))
        self.assertEqual("bytes", str(HeapUsageBenchmark.bytes))

    def test_snark_timings_display_without_the_doubled_bracket(self):
        self.assertEqual("seconds",
                         SnarkBenchmark.verification_time.display_unit)
        self.assertEqual("verification time [[s]]",
                         str(SnarkBenchmark.verification_time))

    def test_every_declared_display_unit_is_spelled_out(self):
        """
         Abbreviations belong in the influx field name, not in a message a
         person reads.
        """
        abbreviations = {"w", "B", "s", "ms", "us", "kc"}
        holders = (JaneStreetBenchmark, SnarkBenchmark, HeapUsageBenchmark,
                   LedgerApplyBenchmark, ArchiveBenchmark,
                   ZkappLimitsBenchmark)
        for holder in holders:
            for name, column in vars(holder).items():
                if isinstance(column, FieldColumn):
                    self.assertNotIn(column.display_unit, abbreviations,
                                     f"{holder.__name__}.{name}")


if __name__ == "__main__":
    unittest.main()
