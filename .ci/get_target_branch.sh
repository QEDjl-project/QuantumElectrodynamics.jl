#!/usr/bin/env bash

set -eu

apt update && apt install -y curl jq


# the content of CI_COMMIT_REF_NAME has the following shape
# pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name> 
IFS='/' read -ra splited_commit_ref <<< "$CI_COMMIT_REF_NAME"

PR_NUMBER=${splited_commit_ref[0]}
# the pull request number has the follwing shape: pr-<number>
# therefore remove the 'pr-'
PR_NUMBER=${PR_NUMBER:3}
REPOSITORY_NAME=${splited_commit_ref[2]}

echo "PR number -> $PR_NUMBER"
echo "Repository name -> $REPOSITORY_NAME"

repo_info=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/QEDjl-project/$REPOSITORY_NAME/pulls/$PR_NUMBER 2> /dev/null)

if echo $repo_info | jq -e .base.ref > /dev/null;
then
    TARGET_BRANCH=$(echo $repo_info | jq -r .base.ref)
else
    echo "PR does not exist. Use fallbak dev branch."
    TARGET_BRANCH="dev"
fi

echo "Target branch -> $TARGET_BRANCH"
export TARGET_BRANCH
