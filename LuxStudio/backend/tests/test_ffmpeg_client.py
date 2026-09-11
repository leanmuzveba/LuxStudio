"""Ports test/services/ffmpeg_service_test.dart's parseSilenceLog coverage."""

from pathlib import Path
from unittest.mock import MagicMock, patch

from app.services.ffmpeg_client import (
    _escape_concat_value,
    _kept_segments,
    parse_silence_log,
    remove_ranges,
)


class TestParseSilenceLog:
    def test_parses_a_single_silence_start_end_pair(self):
        log = (
            "[silencedetect @ 0x7f1] silence_start: 1.234\n"
            "[silencedetect @ 0x7f1] silence_end: 3.456 | silence_duration: 2.222\n"
        )
        ranges = parse_silence_log(log)
        assert len(ranges) == 1
        assert ranges[0]["startMs"] == 1234
        assert ranges[0]["endMs"] == 3456

    def test_parses_multiple_pairs_in_order(self):
        log = (
            "[silencedetect] silence_start: 0.5\n"
            "[silencedetect] silence_end: 1.0 | silence_duration: 0.5\n"
            "some unrelated ffmpeg log line\n"
            "[silencedetect] silence_start: 10.0\n"
            "[silencedetect] silence_end: 12.75 | silence_duration: 2.75\n"
        )
        ranges = parse_silence_log(log)
        assert len(ranges) == 2
        assert ranges[0]["startMs"] == 500
        assert ranges[0]["endMs"] == 1000
        assert ranges[1]["startMs"] == 10_000
        assert ranges[1]["endMs"] == 12_750

    def test_ignores_an_unpaired_silence_start_with_no_matching_end(self):
        log = "[silencedetect] silence_start: 5.0\n"
        assert parse_silence_log(log) == []

    def test_returns_empty_for_a_log_with_no_silence_markers(self):
        log = "frame=  100 fps=30 q=-1.0 size=    512kB time=00:00:03.33"
        assert parse_silence_log(log) == []

    def test_returns_empty_for_an_empty_log(self):
        assert parse_silence_log("") == []


class TestKeptSegments:
    """_kept_segments computes the complement of ranges_to_remove — what
    remove_ranges actually keeps, via the concat demuxer."""

    def test_single_range_produces_a_lead_and_trailing_segment(self):
        assert _kept_segments([{"startMs": 1000, "endMs": 2000}]) == [(0, 1000), (2000, None)]

    def test_range_starting_at_zero_has_no_lead_segment(self):
        assert _kept_segments([{"startMs": 0, "endMs": 500}]) == [(500, None)]

    def test_overlapping_ranges_merge_into_one_gap(self):
        ranges = [{"startMs": 1000, "endMs": 3000}, {"startMs": 2000, "endMs": 4000}]
        assert _kept_segments(ranges) == [(0, 1000), (4000, None)]

    def test_unsorted_input_is_sorted_before_computing_gaps(self):
        ranges = [{"startMs": 5000, "endMs": 6000}, {"startMs": 1000, "endMs": 2000}]
        assert _kept_segments(ranges) == [(0, 1000), (2000, 5000), (6000, None)]


class TestEscapeConcatValue:
    """The ffconcat format only treats backslash as an escape character
    inside a quoted token (not the POSIX shell '\\'' trick)."""

    def test_escapes_single_quotes(self):
        assert _escape_concat_value("it's/a/path.mp4") == "it\\'s/a/path.mp4"

    def test_escapes_backslashes(self):
        assert _escape_concat_value("a\\b") == "a\\\\b"


class TestRemoveRangesConcatFile:
    def test_writes_kept_segments_as_an_ffconcat_file(self):
        """Regression test for the WinError 206 bug: a long sermon's many
        silence ranges used to blow past Windows' ~32K CreateProcess
        command-line limit when passed inline via -vf/-af. remove_ranges
        now lists the kept spans in a file instead, referenced by a short
        -i path, so this must never touch the command line's own length."""
        captured = {}

        def fake_run(args, **kwargs):
            concat_path = args[args.index("-i") + 1]
            captured["content"] = Path(concat_path).read_text()
            result = MagicMock()
            result.returncode = 0
            return result

        with patch("app.services.ffmpeg_client.subprocess.run", side_effect=fake_run):
            remove_ranges(
                source_path="in.mp4",
                output_path="out.mp4",
                ranges_to_remove=[{"startMs": 1145, "endMs": 2300}],
            )

        lines = captured["content"].splitlines()
        assert lines[0] == "ffconcat version 1.0"
        assert lines[1].startswith("file '")
        assert lines[1].endswith("in.mp4'")
        assert lines[2] == "inpoint 0.000"
        assert lines[3] == "outpoint 1.145"
        assert lines[5] == "inpoint 2.300"
        # trailing segment (no known end) must not get an outpoint line
        assert len(lines) == 6
