from __future__ import annotations

import argparse
import os
import re
import shlex
import signal
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Never

from babysit.adapters import GitAdapter, GitHubAdapter, ProcessRunner
from babysit.coordinator import Coordinator, Session, SessionResult

_DURATION = re.compile(r"(?:(?P<hours>\d+)h)?(?:(?P<minutes>\d+)m)?(?:(?P<seconds>\d+)s)?")


def parse_duration(value: str) -> int:
    match = _DURATION.fullmatch(value)
    if match is None or not any(match.groupdict().values()):
        raise ValueError("duration must look like 2h, 15m, or 1h30m")
    seconds = (
        int(match.group("hours") or 0) * 3600
        + int(match.group("minutes") or 0) * 60
        + int(match.group("seconds") or 0)
    )
    if seconds <= 0:
        raise ValueError("duration must be positive")
    return seconds


def format_duration(seconds: int) -> str:
    parts: list[str] = []
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    if seconds or not parts:
        parts.append(f"{seconds}s")
    return "".join(parts)


def continuation_command(session: Session, result: SessionResult, repo_dir: str) -> str | None:
    active = tuple(
        number
        for number in session.prs
        if result.states.get(number) != "merge-ready"
        and not result.states.get(number, "").startswith("blocked:")
    )
    if not active or result.remaining <= 0:
        return None

    argv = ["babysit", *(str(number) for number in active)]
    argv.extend(("--for", format_duration(result.remaining), "--repo-dir", repo_dir))
    for login in sorted(session.bot_logins):
        argv.extend(("--bot", login))
    for number in active:
        for command in session.verify.get(number, ()):
            argv.extend(("--verify", str(number), command))
    return shlex.join(argv)


class SystemClock:
    def monotonic(self) -> float:
        return time.monotonic()

    def sleep(self, seconds: float) -> None:
        time.sleep(seconds)


class StdoutReporter:
    def emit(self, message: str) -> None:
        timestamp = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}", flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    try:
        prs, url_repos = _pull_requests(args.prs)
        if not 1 <= len(prs) <= 32:
            raise ValueError("provide between 1 and 32 PRs")
        if len(set(prs)) != len(prs):
            raise ValueError("PR numbers must be unique")
        duration = parse_duration(args.duration)
        poll = parse_duration(args.poll)
        heartbeat = parse_duration(args.heartbeat)
        if heartbeat > 30:
            raise ValueError("heartbeat must be at most 30s")
        repo_dir = Path(args.repo_dir).expanduser().resolve()
        runner = ProcessRunner()
        repo_dir = Path(
            runner.run(("git", "-C", str(repo_dir), "rev-parse", "--show-toplevel")).stdout.strip()
        )
        repo = _repository(repo_dir, runner)
        if url_repos and {value.casefold() for value in url_repos} != {repo.casefold()}:
            raise ValueError(f"PR URL repository does not match checkout {repo}")
        reporter = StdoutReporter()
        github = GitHubAdapter(repo, runner, reporter)
        base_ref = github.base_ref(prs[0])
        verify = _verify(args.verify, prs)
        session = Session(
            prs=prs,
            duration=duration,
            poll_interval=poll,
            heartbeat_interval=heartbeat,
            base_ref=base_ref,
            bot_logins=frozenset(args.bot),
            verify=verify,
        )
        stop = threading.Event()
        git = GitAdapter(repo_dir, runner, github, reporter)
        _install_interrupts(stop, git, reporter)
        result = Coordinator(github, git, SystemClock(), reporter, stop).run(session)
        _report_result(result, session, repo_dir, reporter)
        return result.exit_code
    except (OSError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    return 64


def _parser() -> argparse.ArgumentParser:
    parser = CLIParser(
        prog="babysit",
        description="Keep a fixed set of GitHub PRs ready for review.",
    )
    parser.add_argument("prs", nargs="+", help="PR numbers or GitHub PR URLs (maximum 32)")
    parser.add_argument("--for", dest="duration", default="2h", help="watch duration (default: 2h)")
    parser.add_argument(
        "--repo-dir",
        default=os.environ.get("BABYSIT_REPO_DIR", "."),
        help="existing repository checkout (default: caller's directory)",
    )
    parser.add_argument("--bot", action="append", default=[], help="additional bot login")
    parser.add_argument(
        "--verify",
        nargs=2,
        action="append",
        metavar=("PR", "COMMAND"),
        default=[],
        help="verification command for one PR; repeat as needed",
    )
    parser.add_argument("--poll", default="10s", help="poll interval (default: 10s)")
    parser.add_argument("--heartbeat", default="30s", help="maximum quiet interval (default: 30s)")
    return parser


class CLIParser(argparse.ArgumentParser):
    def error(self, message: str) -> Never:
        self.print_usage(sys.stderr)
        self.exit(64, f"{self.prog}: error: {message}\n")


def _pull_requests(values: list[str]) -> tuple[tuple[int, ...], set[str]]:
    numbers: list[int] = []
    repos: set[str] = set()
    pattern = re.compile(r"https?://[^/]+/([^/]+/[^/]+)/pull/(\d+)(?:/.*)?$")
    for value in values:
        if value.isdecimal():
            numbers.append(int(value))
            continue
        match = pattern.fullmatch(value)
        if match is None:
            raise ValueError(f"invalid PR number or URL: {value}")
        repos.add(match.group(1))
        numbers.append(int(match.group(2)))
    return tuple(numbers), repos


def _verify(values: list[list[str]], prs: tuple[int, ...]) -> dict[int, tuple[str, ...]]:
    commands: dict[int, list[str]] = {}
    for raw_number, command in values:
        if not raw_number.isdecimal() or int(raw_number) not in prs:
            raise ValueError(f"--verify references unselected PR {raw_number}")
        commands.setdefault(int(raw_number), []).append(command)
    return {number: tuple(items) for number, items in commands.items()}


def _repository(repo_dir: Path, runner: ProcessRunner) -> str:
    remote = runner.run(("git", "-C", str(repo_dir), "remote", "get-url", "origin")).stdout.strip()
    remote_path = remote.removesuffix(".git").replace(":", "/")
    remote_parts = remote_path.rstrip("/").split("/")
    if len(remote_parts) < 2:
        raise ValueError(f"cannot parse origin URL: {remote}")
    remote_repo = "/".join(remote_parts[-2:])
    gh_repo = runner.run(
        ("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"),
        cwd=repo_dir,
    ).stdout.strip()
    if remote_repo.casefold() != gh_repo.casefold():
        raise ValueError(f"origin is {remote_repo}, but gh resolved {gh_repo}")
    return gh_repo


def _install_interrupts(stop: threading.Event, git: GitAdapter, reporter: StdoutReporter) -> None:
    interrupts = 0

    def handle(_signum: int, _frame: object) -> None:
        nonlocal interrupts
        interrupts += 1
        if interrupts == 1:
            reporter.emit("interrupt received; stopping scheduling and waiting for active work")
            stop.set()
            return
        paths = git.preserved_worktrees()
        reporter.emit(
            "second interrupt; abandoning cleanup"
            + (f": {', '.join(paths)}" if paths else " (no preserved worktrees known)")
        )
        os._exit(130)

    signal.signal(signal.SIGINT, handle)


def _report_result(
    result: SessionResult,
    session: Session,
    repo_dir: Path,
    reporter: StdoutReporter,
) -> None:
    for number in session.prs:
        reporter.emit(f"PR {number}: {result.states.get(number, 'not-inspected')}")
    for path in result.worktrees:
        reporter.emit(f"preserved worktree: {path}")
    command = continuation_command(session, result, str(repo_dir))
    if command is not None:
        reporter.emit(f"continue: {command}")
    reporter.emit(
        f"done: {len(session.prs)} PRs, {format_duration(result.remaining)} remaining, "
        f"exit {result.exit_code}"
    )


if __name__ == "__main__":
    sys.exit(main())
