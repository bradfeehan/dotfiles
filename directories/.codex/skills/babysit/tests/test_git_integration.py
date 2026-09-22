from __future__ import annotations

import subprocess
from pathlib import Path

from babysit.adapters import GitAdapter, ProcessRunner
from babysit.model import (
    Check,
    CheckState,
    MergeState,
    PullRequest,
    ReviewDecision,
)


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ("git", *args), cwd=cwd, check=True, text=True, capture_output=True
    ).stdout.strip()


def commit(repo: Path, text: str, message: str) -> str:
    (repo / "value.txt").write_text(text)
    git(repo, "add", "value.txt")
    git(repo, "commit", "-m", message)
    return git(repo, "rev-parse", "HEAD")


def repository(tmp_path: Path, *, conflict: bool) -> tuple[Path, str, str]:
    remote = tmp_path / "remote.git"
    seed = tmp_path / "seed"
    git(tmp_path, "init", "--bare", str(remote))
    git(tmp_path, "clone", str(remote), str(seed))
    git(seed, "config", "user.name", "Tests")
    git(seed, "config", "user.email", "tests@example.test")
    commit(seed, "start\n", "start")
    git(seed, "branch", "-M", "master")
    git(seed, "push", "-u", "origin", "master:refs/heads/master")

    git(seed, "switch", "-c", "feature")
    feature = commit(seed, "feature\n", "feature")
    git(seed, "push", "-u", "origin", "feature:refs/heads/feature")

    git(seed, "switch", "master")
    if conflict:
        base = commit(seed, "base\n", "base")
    else:
        (seed / "other.txt").write_text("base\n")
        git(seed, "add", "other.txt")
        git(seed, "commit", "-m", "base")
        base = git(seed, "rev-parse", "HEAD")
    git(seed, "push", "origin", "master:refs/heads/master")
    return seed, feature, base


class GitHubState:
    def __init__(self, head: str, base: str, *, latest_base: str | None = None) -> None:
        self.head = head
        self.base = base
        self.latest_base = latest_base or base

    def head_sha(self, number: int) -> str:
        assert number == 7
        return self.head

    def base_sha(self, ref: str) -> str:
        assert ref == "master"
        return self.latest_base


class Lines:
    def emit(self, message: str) -> None:
        pass


def pr(head: str, base: str) -> PullRequest:
    return PullRequest(
        number=7,
        url="https://github.com/acme/widgets/pull/7",
        repo="acme/widgets",
        base_ref="master",
        base_sha=base,
        head_ref="feature",
        head_sha=head,
        open=True,
        draft=False,
        mergeable=True,
        merge_state=MergeState.BLOCKED,
        behind_by=1,
        review_decision=ReviewDecision.REVIEW_REQUIRED,
        checks=(Check("tests", CheckState.SUCCESS),),
    )


def test_rebase_runs_verification_and_pushes_with_exact_lease(tmp_path: Path) -> None:
    repo, head, base = repository(tmp_path, conflict=False)
    adapter = GitAdapter(repo, ProcessRunner(), GitHubState(head, base), Lines())

    result = adapter.rebase(pr(head, base), ("test -f other.txt",))

    assert result.status == "success"
    remote_head = git(repo, "ls-remote", "origin", "refs/heads/feature").split()[0]
    assert git(repo, "merge-base", remote_head, base) == base
    assert adapter.preserved_worktrees() == ()


def test_conflict_on_obsolete_base_is_aborted_and_temporary_worktree_removed(
    tmp_path: Path,
) -> None:
    repo, head, base = repository(tmp_path, conflict=True)
    adapter = GitAdapter(
        repo,
        ProcessRunner(),
        GitHubState(head, base, latest_base="newer-base"),
        Lines(),
    )

    result = adapter.rebase(pr(head, base), ())

    assert result.status == "stale"
    assert adapter.preserved_worktrees() == ()
    assert len(git(repo, "worktree", "list", "--porcelain").split("worktree ")) == 2
