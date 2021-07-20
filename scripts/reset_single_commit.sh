#!/usr/bin/env bash
#
# reset_single_commit.sh
#
# Rewrites the git repository history to contain only 1 single initial commit
# with a date in the year 2021.
#

set -euo pipefail

# Find repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "Error: Not inside a Git repository." >&2
    exit 1
fi

cd "$REPO_ROOT"

# Default settings
COMMIT_MSG="Initial commit"
DO_PUSH=false
CUSTOM_DATE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--message)
            COMMIT_MSG="$2"
            shift 2
            ;;
        -p|--push|--force-push)
            DO_PUSH=true
            shift
            ;;
        -d|--date)
            CUSTOM_DATE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [options] [commit_message]"
            echo ""
            echo "Options:"
            echo "  -m, --message <msg>     Set custom commit message (default: 'Initial commit')"
            echo "  -d, --date <date>       Set specific date in 2021 (e.g. '2021-05-18 14:30:00')"
            echo "  -p, --push              Force push to origin after rewriting"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            COMMIT_MSG="$1"
            shift
            ;;
    esac
done

# Get current branch name (fallback to main)
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "main")"
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main"
fi

# Determine commit date in 2021
if [ -n "$CUSTOM_DATE" ]; then
    COMMIT_DATE="$CUSTOM_DATE"
else
    # Generate random date and time in 2021
    RAND_MONTH=$(printf "%02d" $((1 + RANDOM % 12)))
    RAND_DAY=$(printf "%02d" $((1 + RANDOM % 28)))
    RAND_HOUR=$(printf "%02d" $((RANDOM % 24)))
    RAND_MIN=$(printf "%02d" $((RANDOM % 60)))
    RAND_SEC=$(printf "%02d" $((RANDOM % 60)))
    COMMIT_DATE="2021-${RAND_MONTH}-${RAND_DAY} ${RAND_HOUR}:${RAND_MIN}:${RAND_SEC}"
fi

echo "==> Rewriting repository to a single commit..."
echo "  • Branch:      $CURRENT_BRANCH"
echo "  • Commit Date: $COMMIT_DATE"
echo "  • Message:     $COMMIT_MSG"

# Create a temporary orphan branch
TEMP_BRANCH="temp_single_commit_$$"
git checkout --orphan "$TEMP_BRANCH" >/dev/null 2>&1

# Stage all files
git add -A

# Commit with both author and committer dates in 2021
GIT_AUTHOR_DATE="$COMMIT_DATE" GIT_COMMITTER_DATE="$COMMIT_DATE" git commit -m "$COMMIT_MSG"

# Replace the current branch with this orphan branch
git branch -D "$CURRENT_BRANCH" >/dev/null 2>&1 || true
git branch -m "$CURRENT_BRANCH"

# Prune old reflogs and unreferenced git objects locally
git reflog expire --expire=now --all >/dev/null 2>&1 || true
git gc --prune=now >/dev/null 2>&1 || true

echo "==> Done! Repository has been rewritten to 1 single commit."
echo ""
git log --format="Commit: %h%nDate:   %ad%nMsg:    %s" -1
echo ""

if [ "$DO_PUSH" = true ]; then
    echo "==> Force pushing to origin/$CURRENT_BRANCH..."
    git push -f origin "$CURRENT_BRANCH"
else
    echo "To force push this to remote, run:"
    echo "  git push -f origin $CURRENT_BRANCH"
    echo "Or run:"
    echo "  ./scripts/reset_single_commit.sh --push"
fi
