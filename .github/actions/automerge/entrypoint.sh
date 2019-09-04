#!/bin/bash

set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi


# See: https://developer.github.com/actions/creating-github-actions/accessing-the-runtime-environment/#exit-codes-and-statuses
NEUTRAL_EXIT_CODE=78

# FIXME these should be configurable
STABLE_BRANCH=master
DEVELOPMENT_BRANCH=devel




REPO_FULLNAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")

# FIXME: check that this is the main repository and not a fork

echo "https://x-access-token:GITHUB_TOKEN@github.com/$REPO_FULLNAME.git"

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$REPO_FULLNAME.git
git config --global user.email "actions@github.com"
git config --global user.name "GitHub Merge Action"

set -o xtrace

echo $GITHUB_TOKEN
echo $HOME
echo $GITHUB_REF
echo $GITHUB_SHA
echo $GITHUB_REPOSITORY
echo $GITHUB_ACTOR
echo $GITHUB_WORKFLOW
echo $GITHUB_HEAD_REF
echo $GITHUB_BASE_REF
echo $GITHUB_EVENT_NAME
echo $GITHUB_WORKSPACE
echo $GITHUB_ACTION
echo $GITHUB_EVENT_PATH
echo $RUNNER_OS
echo $RUNNER_TOOL_CACHE
echo $RUNNER_TEMP
echo $RUNNER_WORKSPACE


git fetch origin $STABLE_BRANCH
git fetch origin $DEVELOPMENT_BRANCH

# do the merge
git checkout -b $DEVELOPMENT_BRANCH $DEVELOPMENT_BRANCH

if ! git merge-base --is-ancestor $STABLE_BRANCH $DEVELOPMENT_BRANCH; then
  echo "No merge is necessary"
  exit $NEUTRAL_EXIT_CODE
fi;

git merge --no-edit $STABLE_BRANCH
git push --force-with-lease origin $DEVELOPMENT_BRANCH
