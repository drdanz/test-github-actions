#!/bin/bash

set -e

# Workaround unitl new Actions support neutral strategy
# See how it was before: https://developer.github.com/actions/creating-github-actions/accessing-the-runtime-environment/#exit-codes-and-statuses
NEUTRAL_EXIT_CODE=0

# skip if no /rebase
echo "Checking if comment contains '/rebase' command..."
(jq -r ".comment.body" "$GITHUB_EVENT_PATH" | grep -Fq "/rebase") || exit $NEUTRAL_EXIT_CODE

# skip if not a PR
echo "Checking if issue is a pull request..."
(jq -r ".issue.pull_request.url" "$GITHUB_EVENT_PATH") || exit $NEUTRAL_EXIT_CODE

if [[ "$(jq -r ".action" "$GITHUB_EVENT_PATH")" != "created" ]]; then
	echo "This is not a new comment event!"
	exit $NEUTRAL_EXIT_CODE
fi

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
REPO_FULLNAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")
echo "Collecting information about PR #$PR_NUMBER of $REPO_FULLNAME..."

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set the GITHUB_TOKEN env variable."
	exit 1
fi

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
          "${URI}/repos/$REPO_FULLNAME/pulls/$PR_NUMBER")

BASE_REPO=$(echo "$pr_resp" | jq -r .base.repo.full_name)
BASE_BRANCH=$(echo "$pr_resp" | jq -r .base.ref)

echo "GITHUB_EVENT_PATH ="
cat $GITHUB_EVENT_PATH

USER_LOGIN=$(jq -r ".comment.user.login" "$GITHUB_EVENT_PATH")

echo "USER_LOGIN = $USER_LOGIN"

user_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
            "${URI}/users/${USER_LOGIN}")

echo "user_resp = $user_resp"
            
USER_NAME=$(echo "$user_resp" | jq -r ".name")
if [[ "$USER_NAME" == "null" ]]; then
  USER_NAME=$USER_LOGIN
fi
USER_NAME="${USER_NAME} (Rebase PR Action)"

echo "USER_NAME = $USER_NAME"

USER_EMAIL=$(echo "$user_resp" | jq -r ".email")
if [[ "$USER_EMAIL" == "null" ]]; then
  USER_EMAIL="$USER_LOGIN@users.noreply.github.com"
fi

if [[ "$(echo "$pr_resp" | jq -r .rebaseable)" != "true" ]]; then
	echo "GitHub doesn't think that the PR is rebaseable!"
	exit 1
fi

if [[ -z "$BASE_BRANCH" ]]; then
	echo "Cannot get base branch information for PR #$PR_NUMBER!"
	echo "API response: $pr_resp"
	exit 1
fi

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)

echo "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

if [[ "$BASE_REPO" != "$HEAD_REPO" ]]; then
	echo "PRs from forks are not supported at the moment."
	exit 1
fi

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$REPO_FULLNAME.git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork https://x-access-token:$GITHUB_TOKEN@github.com/$HEAD_REPO.git

set -o xtrace

# make sure branches are up-to-date
git fetch origin $BASE_BRANCH
git fetch fork $HEAD_BRANCH

# do the rebase
git checkout -b $HEAD_BRANCH fork/$HEAD_BRANCH
git rebase origin/$BASE_BRANCH

# push back
git push --force-with-lease fork $HEAD_BRANCH
