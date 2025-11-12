## Relevant Files

- `lib/source_monitor/setup` - Entry point for setup orchestration services/Thor commands.
- `lib/tasks/source_monitor.rake` - Rake interfaces for setup/verification tasks.
- `bin/source_monitor` - CLI wrapper for invoking setup workflow.
- `config/initializers/source_monitor.rb` - Installer-generated initializer that may need automated edits.
- `docs/setup.md` - Developer-facing setup checklist documentation.
- `test/lib/source_monitor/setup` - Unit tests for setup orchestration services.
- `test/tasks/source_monitor_setup_test.rb` - Tests covering rake task behavior.

### Notes

- Add/adjust unit tests alongside new services and rake tasks to keep coverage high.
- Prefer Thor/Rails generator patterns already used in the engine for consistent prompts.

## Instructions for Completing Tasks

IMPORTANT: As you complete each task, check it off by changing `- [ ]` to `- [x]`. Update after every sub-task once they are added.

## Tasks

- [ ] 0.0 Create feature branch
  - [ ] 0.1 Create and checkout `feature/setup-workflow-streamlining`
- [ ] 1.0 Build prerequisite detection and dependency helpers
  - [ ] 1.1 Design dependency checker interface (Ruby/Rails/Postgres/Node/Solid Queue)
  - [ ] 1.2 Implement version detection services with unit tests (TDD)
  - [ ] 1.3 Add remediation guidance mapping (error messages) with tests
  - [ ] 1.4 Wire helpers into CLI task to block/skip steps appropriately
- [ ] 2.0 Implement guided setup command/workflow
  - [ ] 2.1 Scaffold Thor/Rails task entry point with prompts, ensuring specs cover CLI flow
  - [ ] 2.2 Automate Gemfile injection + `bundle install` and cover via integration-style tests/mocks
  - [ ] 2.3 Automate `npm install` detection/execution with tests for both asset pipeline modes
  - [ ] 2.4 Invoke install generator + mount path confirmation, validated by tests against dummy app
  - [ ] 2.5 Copy migrations and deduplicate Solid Queue tables with regression tests
  - [ ] 2.6 Automate initializer patching (Devise hooks optional) with unit tests covering idempotency
  - [ ] 2.7 Provide guided prompts for Devise wiring and ensure tests cover conditional behavior
- [ ] 3.0 Add verification and telemetry tooling
  - [ ] 3.1 Implement Solid Queue worker verification service with tests simulating worker availability
  - [ ] 3.2 Implement Action Cable adapter verification (Solid Cable default, Redis optional) with tests
  - [ ] 3.3 Add reusable `source_monitor:verify_install` task leveraging verification services with coverage
  - [ ] 3.4 Emit structured JSON + human-readable summaries; test serialization and logging
  - [ ] 3.5 Optional telemetry output (file/webhook) guarded by feature flag with tests
- [ ] 4.0 Refresh documentation and onboarding assets
  - [ ] 4.1 Update `docs/setup.md` to mirror automated workflow, referencing new commands
  - [ ] 4.2 Document rollback steps and optional Devise system test template
  - [ ] 4.3 Ensure `.ai/tasks.md` references this slice and link to PRD/tasks documents
- [ ] 5.0 Validate workflow end-to-end and define rollout
  - [ ] 5.1 Run setup workflow inside fresh Rails dummy app; record findings/logs
  - [ ] 5.2 Run workflow inside existing host scenario (dummy app variations); capture diffs
  - [ ] 5.3 Execute full test suite (`bin/rails test`, targeted setup tests, linters) and document results
  - [ ] 5.4 Draft release notes + rollout checklist (include CI verification task adoption plan)
