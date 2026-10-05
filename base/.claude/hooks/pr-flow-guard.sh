#!/usr/bin/env bash
# ABOUTME: PreToolUse(Bash) hook: denies pushes to main/master and
# ABOUTME: `gh pr merge --delete-branch`, keeping every change on the PR flow.
set -uo pipefail
# Commands are split into words below; never glob-expand them.
set -f

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
# Relative `git -C` paths and the current-branch lookup resolve from here.
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

deny() {
	jq -nc --arg r "$1" \
		'{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
	exit 0
}

is_protected() { case "$1" in main | master) return 0 ;; *) return 1 ;; esac; }

# Checks one simple command (no ;, &&, ||, |) for a forbidden git push or merge.
check_segment() {
	# shellcheck disable=SC2086  # word splitting into tokens is the point
	set -- $1
	# Drop leading VAR=value assignments.
	while [ $# -gt 0 ] && [[ "$1" == [A-Za-z_]*=* ]]; do shift; done
	[ $# -gt 0 ] || return 0

	case "${1##*/}" in
	gh)
		[ "${2:-}" = pr ] && [ "${3:-}" = merge ] || return 0
		shift 3
		for tok in "$@"; do
			case "$tok" in
			--delete-branch | -d | --delete-branch=true)
				deny "Don't pass --delete-branch to gh pr merge: gh then checks out the default branch, which the main worktree already holds. GitHub auto-deletes the remote branch; the WorktreeRemove hook cleans up locally."
				;;
			esac
		done
		return 0
		;;
	git) shift ;;
	*) return 0 ;;
	esac

	# git's global options before the subcommand; -C retargets the repo.
	local dir=.
	while [ $# -gt 0 ]; do
		case "$1" in
		-C) dir="$2"; shift 2 ;;
		-c) shift 2 ;;
		-*) shift ;;
		*) break ;;
		esac
	done
	[ "${1:-}" = push ] || return 0
	shift

	# Positional args: the remote, then refspecs. Options are skipped, and any
	# option that deletes or mirrors refs is out of scope here.
	local positional=() tok dst
	for tok in "$@"; do
		case "$tok" in -*) ;; *) positional+=("$tok") ;; esac
	done

	local current
	current=$(git -C "$dir" branch --show-current 2>/dev/null)
	if [ "${#positional[@]}" -le 1 ]; then
		# No refspec: push.default=simple pushes the current branch.
		is_protected "$current" && deny "Direct push of $current is blocked: every change goes through a PR. Push a feature branch instead."
		return 0
	fi
	for tok in "${positional[@]:1}"; do
		dst="${tok#+}"
		dst="${dst##*:}"
		dst="${dst#refs/heads/}"
		[ "$dst" = HEAD ] && dst="$current"
		is_protected "$dst" && deny "Direct push to $dst is blocked: every change goes through a PR. Push a feature branch instead."
	done
	return 0
}

# Split compound commands into simple ones; quoting is not parsed, which errs
# on the side of checking more segments, never fewer.
while IFS= read -r seg; do
	check_segment "$seg"
done < <(printf '%s\n' "$CMD" | awk '{ gsub(/&&|\|\||[;|&]/, "\n"); print }')
exit 0
