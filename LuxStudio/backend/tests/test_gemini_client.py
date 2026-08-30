"""Ports test/services/gemini_service_test.dart's pure-helper coverage."""

import pytest

from app.services.gemini_client import (
    GeminiError,
    ai_clip_from_json,
    decode_json_array,
    social_copy_from_json,
    transcript_segment_from_json,
)


class TestDecodeJsonArray:
    def test_decodes_a_plain_json_array(self):
        decoded = decode_json_array('[{"a": 1}, {"a": 2}]')
        assert len(decoded) == 2

    def test_strips_a_markdown_code_fence(self):
        raw = '```json\n[{"a": 1}]\n```'
        decoded = decode_json_array(raw)
        assert len(decoded) == 1
        assert decoded[0]["a"] == 1

    def test_strips_a_bare_code_fence_with_no_language_tag(self):
        raw = "```\n[1, 2, 3]\n```"
        assert decode_json_array(raw) == [1, 2, 3]

    def test_raises_when_response_is_not_a_json_array(self):
        with pytest.raises(GeminiError):
            decode_json_array('{"not": "an array"}')


class TestTranscriptSegmentFromJson:
    def test_converts_fractional_seconds_to_ms_and_trims_text(self):
        segment = transcript_segment_from_json(
            {"startSeconds": 1.5, "endSeconds": 3.25, "text": "  hello there  "},
            7,
        )
        assert segment["id"] == "t7"
        assert segment["startMs"] == 1500
        assert segment["endMs"] == 3250
        assert segment["text"] == "hello there"


class TestAiClipFromJson:
    def test_maps_fields_and_rounds_seconds(self):
        clip = ai_clip_from_json(
            {
                "title": "  Great moment  ",
                "startSeconds": 10,
                "endSeconds": 45,
                "viralScore": 87,
                "reason": "  quotable line  ",
            },
            "clip-id",
        )
        assert clip["id"] == "clip-id"
        assert clip["title"] == "Great moment"
        assert clip["startMs"] == 10_000
        assert clip["endMs"] == 45_000
        assert clip["viralScore"] == 87
        assert clip["reason"] == "quotable line"
        assert clip["category"] == ""

    def test_maps_category_when_present(self):
        clip = ai_clip_from_json(
            {
                "title": "t",
                "startSeconds": 0,
                "endSeconds": 1,
                "viralScore": 50,
                "reason": "r",
                "category": " Strong Hook ",
            },
            "id",
        )
        assert clip["category"] == "Strong Hook"

    def test_clamps_an_out_of_range_viral_score_into_0_100(self):
        too_high = ai_clip_from_json(
            {"title": "t", "startSeconds": 0, "endSeconds": 1, "viralScore": 150, "reason": "r"},
            "id",
        )
        assert too_high["viralScore"] == 100

        too_low = ai_clip_from_json(
            {"title": "t", "startSeconds": 0, "endSeconds": 1, "viralScore": -20, "reason": "r"},
            "id",
        )
        assert too_low["viralScore"] == 0


class TestSocialCopyFromJson:
    def test_maps_fields_trims_text_and_strips_leading_hash_from_hashtags(self):
        copy = social_copy_from_json(
            {
                "title": "  Big moment  ",
                "summary": "  a summary  ",
                "description": "  a longer description  ",
                "hashtags": ["#faith", "hope", "#love"],
            }
        )
        assert copy["title"] == "Big moment"
        assert copy["summary"] == "a summary"
        assert copy["description"] == "a longer description"
        assert copy["hashtags"] == ["faith", "hope", "love"]

    def test_defaults_missing_fields_to_empty(self):
        copy = social_copy_from_json({})
        assert copy["title"] == ""
        assert copy["summary"] == ""
        assert copy["description"] == ""
        assert copy["hashtags"] == []
