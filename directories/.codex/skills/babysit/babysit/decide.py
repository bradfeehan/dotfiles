from babysit.model import (
    CheckState,
    Config,
    Decision,
    DecisionKind,
    MergeState,
    PullRequest,
    ReviewDecision,
)


def decide(config: Config, pr: PullRequest) -> Decision:
    """Return the next semantic action for one fresh PR snapshot."""
    checks_green = all(check.state is CheckState.SUCCESS for check in pr.checks)
    no_feedback = not pr.feedback
    merge_ready = (
        pr.open
        and not pr.draft
        and pr.mergeable is True
        and pr.merge_state is MergeState.CLEAN
        and pr.review_decision is ReviewDecision.APPROVED
        and checks_green
        and no_feedback
    )
    if merge_ready:
        return Decision(DecisionKind.MERGE_READY, "approved-clean-green")

    if not pr.open:
        return Decision(DecisionKind.BLOCKED, "closed")
    if pr.draft:
        return Decision(DecisionKind.BLOCKED, "draft")
    if pr.worktree is not None and not pr.worktree.clean:
        return Decision(DecisionKind.BLOCKED, "dirty-worktree")

    human_feedback = tuple(item for item in pr.feedback if not item.is_bot(config.bot_logins))
    if human_feedback or pr.review_decision is ReviewDecision.CHANGES_REQUESTED:
        return Decision(DecisionKind.BLOCKED, "human-feedback")

    if pr.behind_by > 0 or pr.mergeable is False or pr.merge_state is MergeState.DIRTY:
        return Decision(DecisionKind.REBASE, "base-drift")

    if pr.feedback:
        return Decision(DecisionKind.AGENT_REQUIRED, "automated-feedback")

    failed = tuple(check for check in pr.checks if check.state is CheckState.FAILURE)
    if failed:
        if any(check.run_id is None for check in failed):
            return Decision(DecisionKind.AGENT_REQUIRED, "external-ci-failed")
        run_ids = tuple(sorted({check.run_id for check in failed if check.run_id is not None}))
        retryable = tuple(
            run_id for run_id in run_ids if pr.reruns.get(run_id, 0) < config.max_reruns
        )
        if retryable:
            return Decision(DecisionKind.RERUN_CI, "github-actions-failed", retryable)
        return Decision(DecisionKind.AGENT_REQUIRED, "ci-failed")

    if pr.mergeable is None or any(check.state is CheckState.PENDING for check in pr.checks):
        return Decision(DecisionKind.WAIT, "pending")

    if checks_green and pr.mergeable is True and pr.behind_by == 0:
        return Decision(DecisionKind.READY_FOR_REVIEW, "green-current")

    return Decision(DecisionKind.WAIT, "github-calculating")
