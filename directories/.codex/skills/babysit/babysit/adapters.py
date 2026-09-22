from __future__ import annotations

import json
import re
import subprocess
import tempfile
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol

from babysit.coordinator import RebaseResult
from babysit.model import (
    Check,
    CheckState,
    Feedback,
    MergeState,
    PullRequest,
    ReviewDecision,
    Worktree,
)


@dataclass(frozen=True, slots=True)
class RunResult:
    stdout: str
    stderr: str
    returncode: int


class Runner(Protocol):
    def run(
        self,
        args: tuple[str, ...],
        *,
        cwd: str | Path | None = None,
        timeout: float = 120,
        heartbeat: Callable[[str], None] | None = None,
    ) -> RunResult: ...


class CommandError(RuntimeError):
    def __init__(self, args: tuple[str, ...], result: RunResult) -> None:
        detail = result.stderr.strip() or result.stdout.strip() or "command failed"
        super().__init__(f"{args[0]} exited {result.returncode}: {detail}")
        self.args_run = args
        self.result = result


class ProcessRunner:
    _GITHUB_RETRY_ATTEMPTS = 3
    _GITHUB_RETRY_DELAYS = (1.0, 2.0)

    def run(
        self,
        args: tuple[str, ...],
        *,
        cwd: str | Path | None = None,
        timeout: float = 120,
        heartbeat: Callable[[str], None] | None = None,
    ) -> RunResult:
        for attempt in range(1, self._GITHUB_RETRY_ATTEMPTS + 1):
            result = self._run_once(args, cwd=cwd, timeout=timeout, heartbeat=heartbeat)
            if result.returncode == 0:
                return result
            if (
                not _retryable_github_failure(args, result)
                or attempt == self._GITHUB_RETRY_ATTEMPTS
            ):
                raise CommandError(args, result)
            delay = self._GITHUB_RETRY_DELAYS[attempt - 1]
            if heartbeat is not None:
                command = args[1] if len(args) > 1 else "command"
                heartbeat(
                    f"GitHub transient failure for {command} "
                    f"(attempt {attempt}/{self._GITHUB_RETRY_ATTEMPTS}); retrying in {delay:g}s"
                )
            time.sleep(delay)
        raise AssertionError("unreachable")

    def _run_once(
        self,
        args: tuple[str, ...],
        *,
        cwd: str | Path | None,
        timeout: float,
        heartbeat: Callable[[str], None] | None,
    ) -> RunResult:
        process = subprocess.Popen(
            args,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        started = time.monotonic()
        while True:
            remaining = timeout - (time.monotonic() - started)
            if remaining <= 0:
                process.terminate()
                stdout, stderr = process.communicate()
                raise TimeoutError(f"{args[0]} timed out after {timeout:g}s: {stderr.strip()}")
            try:
                stdout, stderr = process.communicate(timeout=min(30, remaining))
                break
            except subprocess.TimeoutExpired:
                if heartbeat is not None:
                    heartbeat(f"still running: {args[0]}")
        result = RunResult(stdout, stderr, process.returncode)
        return result


_RUN_ID = re.compile(r"/actions/runs/(\d+)(?:/|$)")
_REVIEW_THREADS_QUERY = """
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      reviewThreads(first:100){nodes{
        isResolved comments(first:100){nodes{author{login __typename} url}}
      }}
    }
  }
}
""".strip()


class GitHubAdapter:
    def __init__(self, repo: str, runner: Runner, reporter: EventReporter | None = None) -> None:
        self.repo = repo
        self.runner = runner
        self.reporter = reporter
        self.owner, self.name = repo.split("/", 1)

    def base_sha(self, ref: str) -> str:
        data = self._json(("gh", "api", f"repos/{self.repo}/git/ref/heads/{ref}"))
        return str(data["object"]["sha"])

    def base_ref(self, number: int) -> str:
        data = self._json(
            (
                "gh",
                "pr",
                "view",
                str(number),
                "--repo",
                self.repo,
                "--json",
                "baseRefName,headRepository",
            )
        )
        head_repo = str((data.get("headRepository") or {}).get("nameWithOwner") or "")
        if head_repo.casefold() != self.repo.casefold():
            raise ValueError(f"PR {number} is from fork {head_repo or 'unknown'}")
        return str(data["baseRefName"])

    def inspect(self, number: int, base_sha: str | None = None) -> PullRequest:
        fields = (
            "number,url,state,isDraft,headRefName,headRefOid,headRepository,"
            "baseRefName,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup"
        )
        raw = self._json(("gh", "pr", "view", str(number), "--repo", self.repo, "--json", fields))
        head_repo = str((raw.get("headRepository") or {}).get("nameWithOwner") or "")
        if head_repo.casefold() != self.repo.casefold():
            raise ValueError(f"PR {number} is from fork {head_repo or 'unknown'}")

        base_ref = str(raw["baseRefName"])
        observed_base = base_sha or self.base_sha(base_ref)
        head_sha = str(raw["headRefOid"])
        comparison = self._json(
            ("gh", "api", f"repos/{self.repo}/compare/{observed_base}...{head_sha}")
        )
        threads = self._json(
            (
                "gh",
                "api",
                "graphql",
                "-f",
                f"query={_REVIEW_THREADS_QUERY}",
                "-F",
                f"owner={self.owner}",
                "-F",
                f"name={self.name}",
                "-F",
                f"number={number}",
            )
        )
        return PullRequest(
            number=number,
            url=str(raw["url"]),
            repo=self.repo,
            base_ref=base_ref,
            base_sha=observed_base,
            head_ref=str(raw["headRefName"]),
            head_sha=head_sha,
            open=raw.get("state") == "OPEN",
            draft=bool(raw.get("isDraft")),
            mergeable=_mergeable(raw.get("mergeable")),
            merge_state=_merge_state(raw.get("mergeStateStatus")),
            behind_by=int(comparison.get("behind_by", 0)),
            review_decision=_review_decision(raw.get("reviewDecision")),
            checks=tuple(_check(item) for item in raw.get("statusCheckRollup") or ()),
            feedback=_feedback(threads),
        )

    def rerun_failed(self, run_id: int) -> None:
        self.runner.run(
            ("gh", "run", "rerun", str(run_id), "--failed", "--repo", self.repo),
            timeout=120,
        )

    def head_sha(self, number: int) -> str:
        data = self._json(
            ("gh", "pr", "view", str(number), "--repo", self.repo, "--json", "headRefOid")
        )
        return str(data["headRefOid"])

    def _json(self, args: tuple[str, ...]) -> dict[str, Any]:
        heartbeat = self.reporter.emit if self.reporter is not None else None
        return json.loads(self.runner.run(args, heartbeat=heartbeat).stdout)


class GitState(Protocol):
    def base_sha(self, ref: str) -> str: ...

    def head_sha(self, number: int) -> str: ...


class EventReporter(Protocol):
    def emit(self, message: str) -> None: ...


def _retryable_github_failure(args: tuple[str, ...], result: RunResult) -> bool:
    if not args or args[0] != "gh" or result.returncode == 0:
        return False
    output = f"{result.stderr}\n{result.stdout}"
    return bool(re.search(r"(?:HTTP\s+)?(?:502|503|504)\b", output, re.IGNORECASE))


class GitAdapter:
    """Own guarded Git mutations while leaving policy to the planner."""

    def __init__(
        self,
        repo_dir: str | Path,
        runner: Runner,
        github: GitState,
        reporter: EventReporter,
    ) -> None:
        self.repo_dir = Path(repo_dir).resolve()
        self.runner = runner
        self.github = github
        self.reporter = reporter
        self._admin_lock = threading.Lock()
        self._preserved_lock = threading.Lock()
        self._preserved: set[str] = set()
        self._active_temporary: set[str] = set()

    def worktree(self, head_ref: str) -> Worktree | None:
        output = self._git("worktree", "list", "--porcelain").stdout
        for entry in output.strip().split("\n\n"):
            values: dict[str, str] = {}
            for line in entry.splitlines():
                key, _, value = line.partition(" ")
                values[key] = value
            if values.get("branch") != f"refs/heads/{head_ref}":
                continue
            path = values["worktree"]
            clean = not self._git("status", "--porcelain", cwd=path).stdout.strip()
            return Worktree(path=path, clean=clean)
        return None

    def preserved_worktrees(self) -> tuple[str, ...]:
        with self._preserved_lock:
            return tuple(sorted(self._preserved | self._active_temporary))

    def rebase(self, pr: PullRequest, commands: tuple[str, ...]) -> RebaseResult:
        temporary = False
        temp_parent: Path | None = None
        with self._admin_lock:
            existing = self.worktree(pr.head_ref)
            if existing is not None and not existing.clean:
                return RebaseResult("dirty-worktree", existing.path, existing.path)
            if not self._objects_ready(pr):
                fetch_error = self._prepare_unlocked((pr,))
                if fetch_error is not None:
                    return fetch_error
            fetched_head = self._git(
                "rev-parse", f"refs/remotes/origin/{pr.head_ref}"
            ).stdout.strip()
            if fetched_head != pr.head_sha:
                return RebaseResult("stale", "remote head changed before rebase")
            if existing is not None:
                worktree = Path(existing.path)
                local_head = self._git("rev-parse", "HEAD", cwd=worktree).stdout.strip()
                if local_head != pr.head_sha:
                    self._preserve(worktree)
                    return RebaseResult(
                        "local-head-diverged",
                        "clean worktree HEAD "
                        f"{local_head[:12]} differs from remote {pr.head_sha[:12]}",
                        str(worktree),
                    )
            else:
                temp_parent = Path(tempfile.mkdtemp(prefix=f"babysit-pr-{pr.number}-"))
                worktree = temp_parent / "worktree"
                self._git("worktree", "add", "--detach", str(worktree), pr.head_sha)
                temporary = True
                with self._preserved_lock:
                    self._active_temporary.add(str(worktree))

        self.reporter.emit(f"PR {pr.number} rebasing {pr.head_sha[:12]} onto {pr.base_sha[:12]}")
        try:
            self._git("rebase", pr.base_sha, cwd=worktree, timeout=1800)
        except (CommandError, TimeoutError) as error:
            if self.github.base_sha(pr.base_ref) != pr.base_sha:
                self._git("rebase", "--abort", cwd=worktree)
                self._git("reset", "--hard", pr.head_sha, cwd=worktree)
                self._cleanup(worktree, temp_parent, temporary)
                return RebaseResult("stale", "obsolete conflict was aborted")
            self._preserve(worktree)
            verify = " && ".join(commands) if commands else "git diff --check"
            return RebaseResult(
                "conflict",
                f"{error}; worktree {worktree}; resolve and git rebase --continue; "
                f"verify: {verify}; push: git push "
                f"--force-with-lease=refs/heads/{pr.head_ref}:{pr.head_sha} "
                f"origin HEAD:refs/heads/{pr.head_ref}",
                str(worktree),
            )

        try:
            self._git("diff", "--check", f"{pr.base_sha}...HEAD", cwd=worktree)
            for command in commands:
                self.reporter.emit(f"PR {pr.number} verifying: {command}")
                try:
                    self.runner.run(
                        ("/bin/zsh", "-lc", command),
                        cwd=worktree,
                        timeout=3600,
                        heartbeat=self.reporter.emit,
                    )
                except (CommandError, TimeoutError) as error:
                    raise VerificationError(command, error) from error
        except (CommandError, TimeoutError) as error:
            self._preserve(worktree)
            return RebaseResult("verification-failed", str(error), str(worktree))
        except VerificationError as error:
            self._preserve(worktree)
            return RebaseResult(
                "verification-failed",
                f"{error.command}: {error.cause}; worktree {worktree}",
                str(worktree),
            )

        if self.github.base_sha(pr.base_ref) != pr.base_sha:
            self._git("reset", "--hard", pr.head_sha, cwd=worktree)
            self._cleanup(worktree, temp_parent, temporary)
            return RebaseResult("stale", "base advanced during rebase or verification")
        if self.github.head_sha(pr.number) != pr.head_sha:
            self._git("reset", "--hard", pr.head_sha, cwd=worktree)
            self._cleanup(worktree, temp_parent, temporary)
            return RebaseResult("stale", "remote head changed before push")

        try:
            self._git(
                "push",
                f"--force-with-lease=refs/heads/{pr.head_ref}:{pr.head_sha}",
                "origin",
                f"HEAD:refs/heads/{pr.head_ref}",
                cwd=worktree,
                timeout=300,
            )
        except (CommandError, TimeoutError) as error:
            if self.github.head_sha(pr.number) != pr.head_sha:
                self._git("reset", "--hard", pr.head_sha, cwd=worktree)
                self._cleanup(worktree, temp_parent, temporary)
                return RebaseResult("stale", "lease rejected after remote head changed")
            self._preserve(worktree)
            return RebaseResult("push-failed", str(error), str(worktree))

        self._cleanup(worktree, temp_parent, temporary)
        return RebaseResult("success", "rebased, verified, and pushed")

    def prepare(self, prs: tuple[PullRequest, ...]) -> RebaseResult | None:
        if not prs:
            return None
        with self._admin_lock:
            return self._prepare_unlocked(prs)

    def _prepare_unlocked(self, prs: tuple[PullRequest, ...]) -> RebaseResult | None:
        base_refs = {pr.base_ref for pr in prs}
        if len(base_refs) != 1:
            return RebaseResult("fetch-failed", "rebase batch contains different base branches")
        base_ref = prs[0].base_ref
        refspecs = [f"+refs/heads/{base_ref}:refs/remotes/origin/{base_ref}"]
        refspecs.extend(
            f"+refs/heads/{pr.head_ref}:refs/remotes/origin/{pr.head_ref}"
            for pr in sorted(prs, key=lambda value: value.number)
        )
        args = ("fetch", "origin", *refspecs)
        error: Exception | None = None
        for attempt in range(1, 4):
            try:
                self._git(*args, timeout=120)
                return None
            except (CommandError, TimeoutError) as caught:
                error = caught
                self.reporter.emit(f"fetch authentication attempt {attempt}/3 failed")
        return RebaseResult("fetch-failed", str(error))

    def _objects_ready(self, pr: PullRequest) -> bool:
        try:
            self._git("cat-file", "-e", f"{pr.base_sha}^{{commit}}")
            fetched_head = self._git(
                "rev-parse", f"refs/remotes/origin/{pr.head_ref}"
            ).stdout.strip()
        except CommandError:
            return False
        return fetched_head == pr.head_sha

    def _cleanup(self, worktree: Path, temp_parent: Path | None, temporary: bool) -> None:
        if not temporary:
            return
        with self._admin_lock:
            self._git("worktree", "remove", "--force", str(worktree))
            with self._preserved_lock:
                self._active_temporary.discard(str(worktree))
                self._preserved.discard(str(worktree))
            if temp_parent is not None:
                temp_parent.rmdir()

    def _preserve(self, worktree: Path) -> None:
        with self._preserved_lock:
            self._preserved.add(str(worktree))

    def _git(
        self,
        *args: str,
        cwd: str | Path | None = None,
        timeout: float = 120,
    ) -> RunResult:
        return self.runner.run(
            ("git", *args),
            cwd=cwd or self.repo_dir,
            timeout=timeout,
            heartbeat=self.reporter.emit,
        )


class VerificationError(RuntimeError):
    def __init__(self, command: str, cause: Exception) -> None:
        super().__init__(f"{command}: {cause}")
        self.command = command
        self.cause = cause


def _mergeable(value: object) -> bool | None:
    if value == "MERGEABLE":
        return True
    if value == "CONFLICTING":
        return False
    return None


def _merge_state(value: object) -> MergeState:
    try:
        return MergeState(str(value))
    except ValueError:
        return MergeState.UNKNOWN


def _review_decision(value: object) -> ReviewDecision:
    try:
        return ReviewDecision(str(value))
    except ValueError:
        return ReviewDecision.UNKNOWN


def _check(raw: dict[str, Any]) -> Check:
    is_check_run = raw.get("__typename") == "CheckRun"
    name = str(raw.get("name") if is_check_run else raw.get("context"))
    url_value = raw.get("detailsUrl") if is_check_run else raw.get("targetUrl")
    url = str(url_value) if url_value else None
    raw_state = str(raw.get("conclusion") or raw.get("state") or raw.get("status") or "")
    if raw_state in {"SUCCESS", "NEUTRAL", "SKIPPED"}:
        state = CheckState.SUCCESS
    elif raw_state in {"QUEUED", "IN_PROGRESS", "PENDING", "EXPECTED", "WAITING"}:
        state = CheckState.PENDING
    else:
        state = CheckState.FAILURE
    match = _RUN_ID.search(url or "")
    return Check(name=name, state=state, run_id=int(match.group(1)) if match else None, url=url)


def _feedback(raw: dict[str, Any]) -> tuple[Feedback, ...]:
    repository = (raw.get("data") or {}).get("repository") or {}
    pull_request = repository.get("pullRequest") or {}
    threads = (pull_request.get("reviewThreads") or {}).get("nodes") or ()
    result: list[Feedback] = []
    for thread in threads:
        if thread.get("isResolved"):
            continue
        comments = (thread.get("comments") or {}).get("nodes") or ()
        for comment in comments:
            author = comment.get("author") or {}
            result.append(
                Feedback(
                    author=str(author.get("login") or "unknown"),
                    actor_type=str(author.get("__typename") or "User"),
                    url=str(comment.get("url")) if comment.get("url") else None,
                )
            )
    return tuple(result)
