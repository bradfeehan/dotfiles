from __future__ import annotations

from collections import defaultdict
from dataclasses import replace
from threading import Barrier

from babysit.coordinator import Coordinator, RebaseResult, Session
from babysit.model import (
    Check,
    CheckState,
    MergeState,
    PullRequest,
    ReviewDecision,
)


def snapshot(number: int, **changes: object) -> PullRequest:
    value = PullRequest(
        number=number,
        url=f"https://github.com/acme/widgets/pull/{number}",
        repo="acme/widgets",
        base_ref="master",
        base_sha="base",
        head_ref=f"pr-{number}",
        head_sha=f"head-{number}",
        open=True,
        draft=False,
        mergeable=True,
        merge_state=MergeState.BLOCKED,
        behind_by=0,
        review_decision=ReviewDecision.REVIEW_REQUIRED,
        checks=(Check("tests", CheckState.SUCCESS),),
    )
    return replace(value, **changes)


class FakeGitHub:
    def __init__(self, timelines: dict[int, list[PullRequest]]) -> None:
        self.timelines = timelines
        self.reads: defaultdict[int, int] = defaultdict(int)
        self.reruns: list[int] = []
        self.base_reads = 0

    def base_sha(self, ref: str) -> str:
        assert ref == "master"
        self.base_reads += 1
        return "base"

    def inspect(self, number: int, base_sha: str | None = None) -> PullRequest:
        assert base_sha == "base"
        index = self.reads[number]
        self.reads[number] += 1
        timeline = self.timelines[number]
        return timeline[min(index, len(timeline) - 1)]

    def rerun_failed(self, run_id: int) -> None:
        self.reruns.append(run_id)


class FakeGit:
    def __init__(self) -> None:
        self.prepared: list[tuple[int, ...]] = []

    def worktree(self, head_ref: str) -> None:
        return None

    def prepare(self, prs: tuple[PullRequest, ...]) -> None:
        self.prepared.append(tuple(pr.number for pr in prs))

    def rebase(self, pr: PullRequest, commands: tuple[str, ...]) -> RebaseResult:
        raise AssertionError(f"unexpected rebase for PR {pr.number}: {commands}")

    def preserved_worktrees(self) -> tuple[str, ...]:
        return ()


class ConcurrentRebaseGit(FakeGit):
    def __init__(self) -> None:
        super().__init__()
        self.barrier = Barrier(2, timeout=1)

    def rebase(self, pr: PullRequest, commands: tuple[str, ...]) -> RebaseResult:
        self.barrier.wait()
        return RebaseResult("success")


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


class Lines:
    def __init__(self) -> None:
        self.values: list[str] = []

    def emit(self, message: str) -> None:
        self.values.append(message)


def test_pending_pr_is_polled_until_it_becomes_merge_ready() -> None:
    pending = snapshot(1, checks=(Check("tests", CheckState.PENDING),))
    done = snapshot(
        1,
        merge_state=MergeState.CLEAN,
        review_decision=ReviewDecision.APPROVED,
    )
    github = FakeGitHub({1: [pending, done]})
    clock = FakeClock()

    result = Coordinator(github, FakeGit(), clock, Lines()).run(
        Session(prs=(1,), duration=120, poll_interval=10)
    )

    assert result.exit_code == 0
    assert result.states == {1: "merge-ready"}
    assert github.reads[1] == 2
    assert clock.now == 10


def test_failed_workflow_is_rerun_twice_then_returned_to_agent() -> None:
    failed = snapshot(1, checks=(Check("tests", CheckState.FAILURE, run_id=99),))
    github = FakeGitHub({1: [failed]})
    clock = FakeClock()

    result = Coordinator(github, FakeGit(), clock, Lines()).run(
        Session(prs=(1,), duration=120, poll_interval=10)
    )

    assert result.exit_code == 2
    assert github.reruns == [99, 99]
    assert result.states == {1: "agent-required:ci-failed"}
    assert result.remaining == 100


def test_human_block_on_one_pr_does_not_stop_monitoring_the_rest() -> None:
    from babysit.model import Feedback

    blocked = snapshot(1, feedback=(Feedback("human"),))
    ready = snapshot(
        2,
        merge_state=MergeState.CLEAN,
        review_decision=ReviewDecision.APPROVED,
    )
    github = FakeGitHub({1: [blocked], 2: [ready]})

    result = Coordinator(github, FakeGit(), FakeClock(), Lines()).run(
        Session(prs=(1, 2), duration=120, poll_interval=10)
    )

    assert result.exit_code == 0
    assert result.states == {1: "blocked:human-feedback", 2: "merge-ready"}
    assert github.base_reads == 1


def test_deadline_keeps_ready_for_review_pr_active() -> None:
    github = FakeGitHub({1: [snapshot(1)]})

    result = Coordinator(github, FakeGit(), FakeClock(), Lines()).run(
        Session(prs=(1,), duration=20, poll_interval=10)
    )

    assert result.exit_code == 0
    assert result.states == {1: "ready-for-review"}
    assert result.remaining == 0
    assert github.reads[1] == 3


def test_rebases_share_one_preparation_batch_and_run_concurrently() -> None:
    behind_1 = snapshot(1, behind_by=1)
    behind_2 = snapshot(2, behind_by=1)
    done_1 = snapshot(1, merge_state=MergeState.CLEAN, review_decision=ReviewDecision.APPROVED)
    done_2 = snapshot(2, merge_state=MergeState.CLEAN, review_decision=ReviewDecision.APPROVED)
    github = FakeGitHub({1: [behind_1, done_1], 2: [behind_2, done_2]})
    git_adapter = ConcurrentRebaseGit()

    result = Coordinator(github, git_adapter, FakeClock(), Lines()).run(
        Session(prs=(1, 2), duration=120, poll_interval=10)
    )

    assert result.exit_code == 0
    assert git_adapter.prepared == [(1, 2)]
