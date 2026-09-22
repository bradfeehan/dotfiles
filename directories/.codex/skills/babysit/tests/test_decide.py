from dataclasses import replace

from babysit.decide import decide
from babysit.model import (
    Check,
    CheckState,
    Config,
    DecisionKind,
    Feedback,
    MergeState,
    PullRequest,
    ReviewDecision,
    Worktree,
)


def pr(**changes: object) -> PullRequest:
    value = PullRequest(
        number=456,
        url="https://github.com/acme/widgets/pull/456",
        repo="acme/widgets",
        base_ref="master",
        base_sha="base123",
        head_ref="feature",
        head_sha="head123",
        open=True,
        draft=False,
        mergeable=True,
        merge_state=MergeState.BLOCKED,
        behind_by=0,
        review_decision=ReviewDecision.REVIEW_REQUIRED,
        checks=(Check("tests", CheckState.SUCCESS),),
    )
    return replace(value, **changes)


def test_merge_ready_is_left_untouched_even_when_behind() -> None:
    result = decide(
        Config(),
        pr(
            merge_state=MergeState.CLEAN,
            review_decision=ReviewDecision.APPROVED,
            behind_by=4,
        ),
    )

    assert result.kind is DecisionKind.MERGE_READY


def test_dirty_existing_worktree_blocks_before_rebase() -> None:
    result = decide(Config(), pr(behind_by=2, worktree=Worktree("/repo", clean=False)))

    assert result.kind is DecisionKind.BLOCKED
    assert result.reason == "dirty-worktree"


def test_human_feedback_blocks_but_known_bot_feedback_needs_agent_triage() -> None:
    human = decide(Config(bot_logins=frozenset({"review-bot"})), pr(feedback=(Feedback("sam"),)))
    bot = decide(
        Config(bot_logins=frozenset({"review-bot"})),
        pr(feedback=(Feedback("review-bot"),)),
    )

    assert human.kind is DecisionKind.BLOCKED
    assert human.reason == "human-feedback"
    assert bot.kind is DecisionKind.AGENT_REQUIRED
    assert bot.reason == "automated-feedback"


def test_behind_pr_rebases_before_failed_ci_is_retried() -> None:
    result = decide(
        Config(),
        pr(
            behind_by=1,
            checks=(Check("tests", CheckState.FAILURE, run_id=99),),
        ),
    )

    assert result.kind is DecisionKind.REBASE


def test_failed_github_actions_runs_are_grouped_and_retried_twice() -> None:
    failing = pr(
        checks=(
            Check("unit", CheckState.FAILURE, run_id=99),
            Check("lint", CheckState.FAILURE, run_id=99),
            Check("docs", CheckState.FAILURE, run_id=100),
        )
    )

    first = decide(Config(), failing)
    exhausted = decide(Config(), failing.with_reruns({99: 2, 100: 2}))

    assert first.kind is DecisionKind.RERUN_CI
    assert first.run_ids == (99, 100)
    assert exhausted.kind is DecisionKind.AGENT_REQUIRED
    assert exhausted.reason == "ci-failed"


def test_external_failed_check_returns_for_agent() -> None:
    result = decide(Config(), pr(checks=(Check("external", CheckState.FAILURE),)))

    assert result.kind is DecisionKind.AGENT_REQUIRED
    assert result.reason == "external-ci-failed"


def test_pending_checks_wait_and_green_unapproved_pr_is_ready_for_review() -> None:
    pending = decide(Config(), pr(checks=(Check("tests", CheckState.PENDING),)))
    ready = decide(Config(), pr())

    assert pending.kind is DecisionKind.WAIT
    assert ready.kind is DecisionKind.READY_FOR_REVIEW
