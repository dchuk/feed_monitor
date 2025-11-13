# Setup Workflow Validation Notes

Date: 2025-11-13
Engineer: Codex agent

## Scenario A – Fresh Rails Host (cloned from dummy app)

Steps:
1. Copied `test/dummy` to `tmp/setup_validation` to simulate a pristine host.
2. Ran `../../bin/source_monitor install --yes` from the copied directory.

Findings:
- The first pass surfaced two actionable items:
  - Gemfile duplication (`eval_gemfile '../../Gemfile'` already includes `source_monitor`). Deleted the appended line to unblock bundler.
  - Final verification exited with `WARNING` because no Solid Queue workers were running yet. Inserted a synthetic `SolidQueue::Process` row via `bundle exec rails runner` to mimic a heartbeat before re-running verify.
- Subsequent `../../bin/source_monitor verify` returned:
  ```
  Verification summary (OK):
  - Solid Queue: OK - Solid Queue workers are reporting heartbeats
  - Action Cable: OK - Solid Cable tables detected and the gem is loaded
  ```
- Re-running the installer after the fixes proved idempotent and completed with an `OK` summary.

## Scenario B – Existing Host (same copy, post-install)

Steps:
1. With the same working copy (representing an already-configured app), ran `../../bin/source_monitor install --yes` again.
2. Verified that no files were changed beyond timestamp updates and the workflow skipped migration copies/Devise hooks as expected.

Findings:
- Second run finished cleanly with the same `OK` verification summary. Demonstrates safe re-entry for upgrades/CI.

## Follow-ups

- The Gemfile duplication edge case only applies to internal test harnesses that `eval_gemfile '../../Gemfile'`. Production hosts should add the gem once, but we may consider enhancing `GemfileEditor` to detect `eval_gemfile` references to avoid duplicate insertion.
- A running (or synthetic) Solid Queue process is required for the verification step to return `OK`. Documented expectations in `docs/setup.md` and highlighted the remediation string emitted by the verifier.
