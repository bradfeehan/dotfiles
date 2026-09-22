from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field, replace
from typing import Protocol

from babysit.decide import decide
from babysit.model import Config, DecisionKind, PullRequest, Worktree


class GitHub(Protocol):
    def base_sha(self, ref: str) -> str: ...

    def inspect(self, number: int, base_sha: str | None = None) -> PullRequest: ...

    def rerun_failed(self, run_id: int) -> None: ...


class Git(Protocol):
    def worktree(self, head_ref: str) -> Worktree | None: ...

    def prepare(self, prs: tuple[PullRequest, ...]) -> RebaseResult | None: ...

    def rebase(self, pr: PullRequest, commands: tuple[str, ...]) -> RebaseResult: ...

    def preserved_worktrees(self) -> tuple[str, ...]: ...


class Clock(Protocol):
    def monotonic(self) -> float: ...

    def sleep(self, seconds: float) -> None: ...


class Reporter(Protocol):
    def emit(self, message: str) -> None: ...


class StopSignal(Protocol):
    def is_set(self) -> bool: ...


@dataclass(frozen=True, slots=True)
class RebaseResult:
    status: str
    detail: str = ""
    worktree: str | None = None


@dataclass(frozen=True, slots=True)
class Session:
    prs: tuple[int, ...]
    duration: float = 7200
    poll_interval: float = 10
    heartbeat_interval: float = 30
    base_ref: str = "master"
    bot_logins: frozenset[str] = frozenset()
    verify: dict[int, tuple[str, ...]] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class SessionResult:
    exit_code: int
    remaining: int
    states: dict[int, str]
    worktrees: tuple[str, ...] = ()


class Coordinator:
    def __init__(
        self,
        github: GitHub,
        git: Git,
        clock: Clock,
        reporter: Reporter,
        stop: StopSignal | None = None,
    ) -> None:
        self.github = github
        self.git = git
        self.clock = clock
        self.reporter = reporter
        self.stop = stop

    def run(self, session: Session) -> SessionResult:
        if not session.prs or len(session.prs) > 32 or len(set(session.prs)) != len(session.prs):
            raise ValueError("provide between 1 and 32 unique PR numbers")

        started = self.clock.monotonic()
        deadline = started + session.duration
        last_heartbeat = started
        active = set(session.prs)
        states: dict[int, str] = {}
        reruns: dict[tuple[int, str, int], int] = {}
        config = Config(bot_logins=session.bot_logins)
        self.reporter.emit(f"watching {len(active)} PRs for {_duration(session.duration)}")

        while active:
            if self.stop is not None and self.stop.is_set():
                return self._result(130, deadline, states)
            base_sha = self.github.base_sha(session.base_ref)
            snapshots = self._inspect(active, base_sha)
            wrong_base = {
                pr.base_ref for pr in snapshots.values() if pr.base_ref != session.base_ref
            }
            if wrong_base:
                raise ValueError(
                    f"all PRs must target {session.base_ref}; found {', '.join(sorted(wrong_base))}"
                )
            agent_required = False
            rebase_jobs: list[PullRequest] = []
            rerun_jobs: list[tuple[int, int]] = []

            for number in sorted(active):
                pr = snapshots[number]
                counts = {
                    run_id: count
                    for (pr_number, head_sha, run_id), count in reruns.items()
                    if pr_number == number and head_sha == pr.head_sha
                }
                decision = decide(config, pr.with_reruns(counts))
                states[number] = (
                    decision.kind.value
                    if not decision.reason
                    else f"{decision.kind.value}:{decision.reason}"
                )

                if decision.kind is DecisionKind.MERGE_READY:
                    states[number] = "merge-ready"
                    active.remove(number)
                    self.reporter.emit(f"PR {number} merge-ready at {pr.head_sha[:12]}")
                elif decision.kind is DecisionKind.BLOCKED:
                    states[number] = f"blocked:{decision.reason}"
                    active.remove(number)
                    self.reporter.emit(f"PR {number} blocked: {decision.reason}")
                elif decision.kind is DecisionKind.REBASE:
                    states[number] = "rebasing"
                    self.reporter.emit(
                        f"[{pr.base_sha[:12]}] update-base(rebase) PR {number} "
                        f"is behind {pr.behind_by} at {pr.head_sha[:12]}"
                    )
                    rebase_jobs.append(pr)
                elif decision.kind is DecisionKind.RERUN_CI:
                    states[number] = "rerunning-ci"
                    rerun_jobs.extend((number, run_id) for run_id in decision.run_ids)
                elif decision.kind is DecisionKind.AGENT_REQUIRED:
                    states[number] = f"agent-required:{decision.reason}"
                    agent_required = True
                    self.reporter.emit(f"PR {number} needs agent: {decision.reason}")
                    self._report_agent_context(pr, decision.reason)
                elif decision.kind is DecisionKind.READY_FOR_REVIEW:
                    states[number] = "ready-for-review"
                else:
                    states[number] = "waiting"

            if rebase_jobs:
                preparation = self.git.prepare(tuple(rebase_jobs))
                if preparation is not None:
                    for pr in rebase_jobs:
                        states[pr.number] = f"agent-required:{preparation.status}"
                    agent_required = True
                    self.reporter.emit(f"rebase preparation failed: {preparation.detail}")
                else:
                    with ThreadPoolExecutor(max_workers=len(rebase_jobs)) as pool:
                        futures = {
                            pr.number: pool.submit(
                                self.git.rebase, pr, session.verify.get(pr.number, ())
                            )
                            for pr in rebase_jobs
                        }
                        for number, future in futures.items():
                            result = future.result()
                            if result.status in {"success", "stale"}:
                                self.reporter.emit(f"PR {number} rebase {result.status}")
                            else:
                                states[number] = f"agent-required:{result.status}"
                                agent_required = True
                                self.reporter.emit(f"PR {number} needs agent: {result.detail}")

            if rerun_jobs:
                with ThreadPoolExecutor(max_workers=len(rerun_jobs)) as pool:
                    futures = {
                        (number, run_id): pool.submit(self.github.rerun_failed, run_id)
                        for number, run_id in rerun_jobs
                    }
                    for (number, run_id), future in futures.items():
                        future.result()
                        head_sha = snapshots[number].head_sha
                        key = (number, head_sha, run_id)
                        reruns[key] = reruns.get(key, 0) + 1
                        self.reporter.emit(
                            f"PR {number} reran workflow {run_id} "
                            f"({reruns[key]}/{config.max_reruns})"
                        )

            now = self.clock.monotonic()
            if self.stop is not None and self.stop.is_set():
                return self._result(130, deadline, states)
            if agent_required:
                return self._result(2, deadline, states)
            if not active:
                return self._result(0, deadline, states)
            if now >= deadline:
                return self._result(0, deadline, states)
            if now - last_heartbeat >= session.heartbeat_interval:
                self.reporter.emit(_summary(states, active))
                last_heartbeat = now
            self.clock.sleep(min(session.poll_interval, deadline - now))

        return self._result(0, deadline, states)

    def _inspect(self, active: set[int], base_sha: str) -> dict[int, PullRequest]:
        with ThreadPoolExecutor(max_workers=len(active)) as pool:
            futures = {
                number: pool.submit(self.github.inspect, number, base_sha) for number in active
            }
            snapshots = {number: future.result() for number, future in futures.items()}
        return {
            number: replace(pr, worktree=self.git.worktree(pr.head_ref))
            for number, pr in snapshots.items()
        }

    def _result(self, exit_code: int, deadline: float, states: dict[int, str]) -> SessionResult:
        remaining = max(0, round(deadline - self.clock.monotonic()))
        return SessionResult(
            exit_code=exit_code,
            remaining=remaining,
            states=dict(sorted(states.items())),
            worktrees=self.git.preserved_worktrees(),
        )

    def _report_agent_context(self, pr: PullRequest, reason: str) -> None:
        if reason in {"ci-failed", "external-ci-failed"}:
            for check in pr.checks:
                if check.state.value != "failure":
                    continue
                self.reporter.emit(f"check: {check.name} {check.url or '(no URL)'}")
                if check.run_id is not None:
                    self.reporter.emit(
                        f"inspect: gh run view {check.run_id} --log-failed --repo {pr.repo}"
                    )
        elif reason == "automated-feedback":
            for item in pr.feedback:
                self.reporter.emit(f"feedback: {item.author} {item.url or '(no URL)'}")


def _summary(states: dict[int, str], active: set[int]) -> str:
    counts: dict[str, int] = {}
    for number in active:
        label = states.get(number, "waiting").split(":", 1)[0]
        counts[label] = counts.get(label, 0) + 1
    return ", ".join(f"{count} {label}" for label, count in sorted(counts.items()))


def _duration(seconds: float) -> str:
    if seconds % 3600 == 0:
        return f"{int(seconds // 3600)}h"
    if seconds % 60 == 0:
        return f"{int(seconds // 60)}m"
    return f"{int(seconds)}s"
