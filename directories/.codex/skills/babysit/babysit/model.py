from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field, replace
from enum import StrEnum
from types import MappingProxyType


class MergeState(StrEnum):
    CLEAN = "CLEAN"
    BLOCKED = "BLOCKED"
    DIRTY = "DIRTY"
    UNKNOWN = "UNKNOWN"


class ReviewDecision(StrEnum):
    APPROVED = "APPROVED"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    CHANGES_REQUESTED = "CHANGES_REQUESTED"
    UNKNOWN = "UNKNOWN"


class CheckState(StrEnum):
    SUCCESS = "success"
    PENDING = "pending"
    FAILURE = "failure"


class DecisionKind(StrEnum):
    MERGE_READY = "merge-ready"
    BLOCKED = "blocked"
    REBASE = "rebase"
    AGENT_REQUIRED = "agent-required"
    RERUN_CI = "rerun-ci"
    WAIT = "wait"
    READY_FOR_REVIEW = "ready-for-review"


@dataclass(frozen=True, slots=True)
class Config:
    bot_logins: frozenset[str] = frozenset()
    max_reruns: int = 2


@dataclass(frozen=True, slots=True)
class Check:
    name: str
    state: CheckState
    run_id: int | None = None
    url: str | None = None


@dataclass(frozen=True, slots=True)
class Feedback:
    author: str
    actor_type: str = "User"
    url: str | None = None

    def is_bot(self, configured_bots: frozenset[str]) -> bool:
        return self.actor_type == "Bot" or self.author.casefold() in {
            login.casefold() for login in configured_bots
        }


@dataclass(frozen=True, slots=True)
class Worktree:
    path: str
    clean: bool
    temporary: bool = False


@dataclass(frozen=True, slots=True)
class PullRequest:
    number: int
    url: str
    repo: str
    base_ref: str
    base_sha: str
    head_ref: str
    head_sha: str
    open: bool
    draft: bool
    mergeable: bool | None
    merge_state: MergeState
    behind_by: int
    review_decision: ReviewDecision
    checks: tuple[Check, ...]
    feedback: tuple[Feedback, ...] = ()
    worktree: Worktree | None = None
    reruns: Mapping[int, int] = field(default_factory=lambda: MappingProxyType({}))

    def with_reruns(self, reruns: Mapping[int, int]) -> PullRequest:
        return replace(self, reruns=MappingProxyType(dict(reruns)))


@dataclass(frozen=True, slots=True)
class Decision:
    kind: DecisionKind
    reason: str
    run_ids: tuple[int, ...] = ()
