# SourceMonitor Setup Workflow

This guide consolidates the new guided installer, verification commands, and rollback steps so teams can onboard the engine into either a fresh Rails host or an existing application without missing prerequisites.

## Prerequisites

| Requirement | Minimum | Notes |
| --- | --- | --- |
| Ruby | 3.4.4 | Use rbenv and match the engine's `.ruby-version`. |
| Rails | 8.0.2.1 | Run `bin/rails about` inside the host to confirm. |
| PostgreSQL | 14+ | Required for Solid Queue tables and item storage. |
| Node.js | 18+ | Needed for Tailwind/esbuild assets when the host owns node tooling. |
| Background jobs | Solid Queue (>= 0.3, < 3.0) | Add `solid_queue` to the host Gemfile if not present. |
| Realtime | Solid Cable (>= 3.0) or Redis | Solid Cable is the default; Redis requires `config.realtime.adapter = :redis`. |

## Guided Setup (Recommended)

1. **Check prerequisites** (optional but fast):
   ```bash
   bin/rails source_monitor:setup:check
   ```
   This invokes the dependency checker added in Phase 10.04 and surfaces remediation text when versions or adapters are missing.

2. **Run the guided installer:**
   ```bash
   bin/source_monitor install
   ```
   - Prompts for the mount path (defaults to `/source_monitor`).
   - Ensures `gem "source_monitor"` is in the host Gemfile and runs `bundle install` via rbenv shims.
   - Runs `npm install` when `package.json` exists.
   - Executes `bin/rails generate source_monitor:install --mount-path=...`.
   - Copies migrations, deduplicates duplicate Solid Queue migrations, and reruns `bin/rails db:migrate`.
   - Updates `config/initializers/source_monitor.rb` with a navigation hint and, when desired, Devise hooks.
   - Writes a verification report at the end (same as `bin/source_monitor verify`).

3. **Start background workers:**
   ```bash
   bin/rails solid_queue:start
   bin/jobs --recurring_schedule_file=config/recurring.yml # optional recurring scheduler
   ```

4. **Visit the dashboard** at the chosen mount path, create a source, and trigger “Fetch Now” to validate realtime updates and Solid Queue processing.

### Fully Non-Interactive Install

Use `--yes` to accept defaults (mount path `/source_monitor`, Devise hooks enabled if Devise detected):
```bash
bin/source_monitor install --yes
```

### Verification & Telemetry

- Re-run verification anytime:
  ```bash
  bin/source_monitor verify
  ```
  or
  ```bash
  bin/rails source_monitor:setup:verify
  ```
- Results show human-friendly lines plus a JSON blob; exit status is non-zero when any check fails.
- To persist telemetry for support, set `SOURCE_MONITOR_SETUP_TELEMETRY=true`. Logs append to `log/source_monitor_setup.log`.

## Rollback Steps

If you need to revert the integration in a host app:

1. Remove `gem "source_monitor"` from the host Gemfile and rerun `bundle install`.
2. Delete the engine initializer (`config/initializers/source_monitor.rb`) and any navigation links referencing the mount path.
3. Remove the mount entry from `config/routes.rb` (the install generator adds a comment to help locate it).
4. Drop SourceMonitor tables if they are no longer needed:
   ```bash
   bin/rails db:migrate:down VERSION=<timestamp> # repeat for each engine migration
   ```
5. Remove Solid Queue / Solid Cable migrations only if no other components rely on them.

Document each removal in the host application's changelog to keep future upgrades predictable.

## Optional Devise System Test Template

Add a guardrail test in the host app (or dummy) to make sure authentication protects the dashboard after upgrades:

```ruby
# test/system/source_monitor_setup_test.rb
require "application_system_test_case"

class SourceMonitorSetupTest < ApplicationSystemTestCase
  test "signed in admin can reach SourceMonitor" do
    user = users(:admin)
    sign_in user

    visit "/source_monitor"
    assert_text "SourceMonitor Dashboard"
  end
end
```

- Swap `sign_in user` for your Devise helper (`login_as`, etc.).
- Use fixtures or factories that guarantee the user is authorized per the initializer’s `authorize_with` hook.

## Additional Notes

- Re-running `bin/source_monitor install` is idempotent: if migrations already exist or Devise hooks are present, the workflow skips creation and only re-verifies prerequisites.
- The CLI wraps the same services the rake tasks use, so CI can call `bin/source_monitor verify` directly after migrations to catch worker/cable misconfigurations before deploying.
- Keep this document aligned with the PRD (`tasks/prd-setup-workflow-streamlining.md`) and active task list (`tasks/tasks-setup-workflow-streamlining.md`).
