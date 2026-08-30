"""Ports test/services/ffmpeg_service_test.dart's parseSilenceLog coverage."""

from app.services.ffmpeg_client import parse_silence_log


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
