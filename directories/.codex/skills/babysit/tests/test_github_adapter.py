import json

import pytest

from babysit.adapters import (
    CommandError,
    GitHubAdapter,
    ProcessRunner,
    RunResult,
    _retryable_github_failure,
)
from babysit.model import CheckState, ReviewDecision


class FakeRunner:
    def __init__(self, outputs: list[dict[str, object]]) -> None:
        self.outputs = outputs
        self.calls: list[tuple[str, ...]] = []

    def run(self, args: tuple[str, ...], **_: object) -> RunResult:
        self.calls.append(args)
        return RunResult(json.dumps(self.outputs.pop(0)), "", 0)


def test_github_inspection_normalizes_checks_base_distance_and_bot_feedback() -> None:
    runner = FakeRunner(
        [
            {
                "number": 456,
                "url": "https://github.com/acme/widgets/pull/456",
                "state": "OPEN",
                "isDraft": False,
                "headRefName": "feature",
                "headRefOid": "head123",
                "headRepository": {"nameWithOwner": "acme/widgets"},
                "baseRefName": "master",
                "mergeable": "MERGEABLE",
                "mergeStateStatus": "BLOCKED",
                "reviewDecision": "REVIEW_REQUIRED",
                "statusCheckRollup": [
                    {
                        "__typename": "CheckRun",
                        "name": "unit",
                        "status": "COMPLETED",
                        "conclusion": "FAILURE",
                        "detailsUrl": "https://github.com/acme/widgets/actions/runs/99/job/100",
                    },
                    {
                        "__typename": "StatusContext",
                        "context": "license",
                        "state": "SUCCESS",
                        "targetUrl": "https://checks.example/1",
                    },
                ],
            },
            {"object": {"sha": "base123"}},
            {"behind_by": 2},
            {
                "data": {
                    "repository": {
                        "pullRequest": {
                            "reviewThreads": {
                                "nodes": [
                                    {
                                        "isResolved": False,
                                        "comments": {
                                            "nodes": [
                                                {
                                                    "author": {
                                                        "login": "review-bot",
                                                        "__typename": "Bot",
                                                    },
                                                    "url": "https://github.com/acme/widgets/pull/456#discussion_r1",
                                                }
                                            ]
                                        },
                                    }
                                ]
                            }
                        }
                    }
                }
            },
        ]
    )

    pr = GitHubAdapter("acme/widgets", runner).inspect(456)

    assert pr.base_sha == "base123"
    assert pr.behind_by == 2
    assert pr.review_decision is ReviewDecision.REVIEW_REQUIRED
    assert [(check.name, check.state, check.run_id) for check in pr.checks] == [
        ("unit", CheckState.FAILURE, 99),
        ("license", CheckState.SUCCESS, None),
    ]
    assert pr.feedback[0].actor_type == "Bot"


def test_fork_pr_is_rejected() -> None:
    runner = FakeRunner(
        [
            {
                "number": 9,
                "url": "https://github.com/acme/widgets/pull/9",
                "state": "OPEN",
                "isDraft": False,
                "headRefName": "feature",
                "headRefOid": "abc",
                "headRepository": {"nameWithOwner": "somebody/widgets"},
                "baseRefName": "master",
                "mergeable": "MERGEABLE",
                "mergeStateStatus": "BLOCKED",
                "reviewDecision": "REVIEW_REQUIRED",
                "statusCheckRollup": [],
            }
        ]
    )

    try:
        GitHubAdapter("acme/widgets", runner).inspect(9)
    except ValueError as error:
        assert str(error) == "PR 9 is from fork somebody/widgets"
    else:
        raise AssertionError("fork PR was accepted")


@pytest.mark.parametrize("status", [502, 503, 504])
def test_transient_github_status_is_retryable(status: int) -> None:
    result = RunResult("", f"HTTP {status}: Service Unavailable", 1)

    assert _retryable_github_failure(("gh", "api", "graphql"), result)


def test_process_runner_retries_transient_github_failures(monkeypatch: pytest.MonkeyPatch) -> None:
    results = iter(
        [
            RunResult("", "HTTP 503: Service Unavailable", 1),
            RunResult("", "HTTP 503: Service Unavailable", 1),
            RunResult("{}", "", 0),
        ]
    )
    delays: list[float] = []
    events: list[str] = []
    runner = ProcessRunner()
    monkeypatch.setattr(runner, "_run_once", lambda *_args, **_kwargs: next(results))
    monkeypatch.setattr("babysit.adapters.time.sleep", delays.append)

    result = runner.run(("gh", "api", "graphql"), heartbeat=events.append)

    assert result.stdout == "{}"
    assert delays == [1.0, 2.0]
    assert len(events) == 2


def test_process_runner_stops_after_three_transient_failures(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = ProcessRunner()
    monkeypatch.setattr(
        runner,
        "_run_once",
        lambda *_args, **_kwargs: RunResult("", "HTTP 503: Service Unavailable", 1),
    )
    monkeypatch.setattr("babysit.adapters.time.sleep", lambda _delay: None)

    with pytest.raises(CommandError):
        runner.run(("gh", "api", "graphql"))
