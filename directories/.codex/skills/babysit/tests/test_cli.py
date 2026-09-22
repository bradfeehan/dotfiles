import re

import pytest

from babysit.cli import StdoutReporter, _parser, continuation_command, parse_duration
from babysit.coordinator import Session, SessionResult


@pytest.mark.parametrize(
    ("value", "seconds"),
    [("90s", 90), ("15m", 900), ("2h", 7200), ("1h30m", 5400)],
)
def test_duration_parser_accepts_compact_values(value: str, seconds: int) -> None:
    assert parse_duration(value) == seconds


def test_continuation_is_shell_quoted_and_reduces_the_pr_set() -> None:
    session = Session(
        prs=(1, 2, 3),
        duration=7200,
        bot_logins=frozenset({"bug bot"}),
        verify={2: ("pytest tests/widget", "ruff check 'odd path'")},
    )
    result = SessionResult(
        exit_code=2,
        remaining=3670,
        states={1: "merge-ready", 2: "agent-required:ci-failed", 3: "blocked:human-feedback"},
    )

    command = continuation_command(session, result, "/repo with spaces")

    assert command == (
        "babysit 2 --for 1h1m10s --repo-dir '/repo with spaces' "
        "--bot 'bug bot' --verify 2 'pytest tests/widget' "
        "--verify 2 'ruff check '\"'\"'odd path'\"'\"''"
    )


def test_no_continuation_when_no_active_prs_remain() -> None:
    result = SessionResult(0, 50, {1: "merge-ready", 2: "blocked:human-feedback"})

    assert continuation_command(Session(prs=(1, 2)), result, "/repo") is None


@pytest.mark.parametrize("value", ["", "0m", "2", "-1h", "1d"])
def test_duration_parser_rejects_ambiguous_or_nonpositive_values(value: str) -> None:
    with pytest.raises(ValueError):
        parse_duration(value)


def test_invalid_cli_usage_does_not_use_agent_intervention_exit_code() -> None:
    with pytest.raises(SystemExit) as error:
        _parser().parse_args([])

    assert error.value.code == 64


def test_stdout_reporter_prefixes_each_line_with_a_timestamp(
    capsys: pytest.CaptureFixture[str],
) -> None:
    StdoutReporter().emit("hello")

    assert re.fullmatch(r"\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] hello\n", capsys.readouterr().out)
