"""Ports test/services/ffmpeg_service_test.dart's parseSilenceLog coverage."""

from unittest.mock import patch

from app.services.ffmpeg_client import parse_silence_log, remove_ranges


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


class TestRemoveRangesFilterQuoting:
    def test_single_quotes_the_between_expression(self):
        """The between(t,start,end) expression contains commas, which
        ffmpeg's filtergraph parser reads as filter separators unless the
        whole expression is quoted — regression test for the bug where
        `select=not(between(t,1.145,2.3))` (unquoted) made ffmpeg treat
        "1.145" as a bogus filter name and fail with "Filter not found"."""
        with patch("app.services.ffmpeg_client.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            remove_ranges(
                source_path="in.mp4",
                output_path="out.mp4",
                ranges_to_remove=[{"startMs": 1145, "endMs": 2300}],
            )

        args = mock_run.call_args[0][0]
        vf = args[args.index("-vf") + 1]
        af = args[args.index("-af") + 1]
        assert vf == "select='not(between(t,1.145,2.300))',setpts=N/FRAME_RATE/TB"
        assert af == "aselect='not(between(t,1.145,2.300))',asetpts=N/SR/TB"
