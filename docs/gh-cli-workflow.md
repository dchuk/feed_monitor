# GitHub CLI Workflow for Branches & Pull Requests

Use this checklist whenever you create or land a slice. It keeps `gh` commands predictable and avoids redo steps.

## 1. Prep local branch
1. `git checkout main && git fetch origin && git reset --hard origin/main`
2. `git checkout -b <feature|bugfix>/<description>`
3. Do the work, run tests/lint, then `git commit -am "scope: summary"`
4. Run the coverage gate locally before pushing:
   - `bin/test-coverage`
   - `bin/check-diff-coverage`
   - If new code is intentionally uncovered, refresh the baseline with `bin/update-coverage-baseline` and commit the updated `config/coverage_baseline.json`.
5. Push: `git push -u origin <branch>`

## 2. Open a PR (as draft)
1. `gh pr create --base main --head <branch> --title "scope: summary" --body "## Summary\n..." --draft`
2. `gh pr view --json url,isDraft` (confirm association & draft status)

## 3. Iterate on the PR
1. Additional commits → `git push`
2. `gh pr status` shows open PRs for the current branch.

## 4. Move PR out of draft
1. Check draft flag: `gh pr view <number> --json isDraft`
2. If true, run `gh pr ready <number>`.
3. Request reviews: `gh pr ready <number> --reviewer user1,user2`

## 5. Merge steps
1. Ensure PR is not draft & CI green: `gh pr checks <number>`
2. Merge via GitHub (avoids local fast-forward issues):
   ```bash
   gh pr merge <number> --squash --delete-branch --auto
   ```
   `--auto` queues the merge once requirements are satisfied. Drop `--auto` only if you intend to merge immediately and have maintainer privileges.

## 6. Local cleanup
1. `git checkout main`
2. `git pull --ff-only origin main`
3. Delete local branch: `git branch -d <branch>`
4. Optional: `git remote prune origin`

## 7. Handy status commands
- `gh pr status` – current branch PR state
- `gh pr view <number> --json url,state,isDraft` – PR summary
- `gh pr checks <number>` – CI state
- `gh pr list --author @me` – open PRs authored by you

Keep this document in `docs/gh-cli-workflow.md` and update it as our process evolves.
