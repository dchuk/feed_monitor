## Relevant Files

- `lib/feed_monitor/opml/parser.rb` - Normalizes OPML 1.0/2.0 outlines into FeedMonitor-ready hashes.
- `lib/feed_monitor/opml/outline.rb` - Optional helper struct encapsulating outline metadata for reuse across importer/exporter.
- `lib/feed_monitor/importing/opml_import_service.rb` - Applies per-source decisions (create/update/skip) during OPML imports.
- `lib/feed_monitor/importing/opml_import_progress.rb` - Tracks per-token import progress and stores interim results for Turbo updates.
- `app/jobs/feed_monitor/opml_import_job.rb` - Background job executing the import service and reporting progress.
- `app/controllers/feed_monitor/opml_imports_controller.rb` - Turbo wizard endpoints for upload, preview, and confirmation.
- `app/views/feed_monitor/opml_imports/*.html.erb` - Import wizard templates using existing admin components.
- `app/views/feed_monitor/opml_imports/_progress_results.html.erb` - Turbo partial for live progress rows, audit summaries, and health check messaging.
- `lib/feed_monitor/configuration.rb` - Defines queue names/concurrency for fetch, scrape, and import roles.
- `lib/feed_monitor/importing/opml_import_progress.rb` - Persists progress state and broadcasts Turbo updates, including health check metadata.
- `lib/feed_monitor/exporting/opml_export_service.rb` - Streams OPML XML documents honoring scope filters.
- `app/controllers/feed_monitor/opml_exports_controller.rb` - Handles export request modal, progress, and download responses.
- `app/jobs/feed_monitor/opml_export_job.rb` - Background exporter tying into Turbo progress updates.
- `test/system/opml_imports_test.rb` & `test/system/opml_exports_test.rb` - End-to-end specs covering admin workflows.
- `test/lib/feed_monitor/opml/parser_test.rb` - Unit coverage for OPML parsing normalization and error handling.
- `test/lib/feed_monitor/importing/opml_import_service_test.rb` - Unit coverage for per-source import decisions and duplicate safeguards.
- `test/jobs/feed_monitor/opml_import_job_test.rb` - Job specs for queue selection, idempotency, and progress broadcasting.
- `test/lib/feed_monitor/importing/opml_import_progress_test.rb` - Ensures progress tracking serializes health check metadata.
- `test/jobs/feed_monitor/opml_export_job_test.rb` - Future job behavior and Solid Queue integration checks.
- `test/controllers/feed_monitor/opml_imports_controller_test.rb` & `test/controllers/feed_monitor/opml_exports_controller_test.rb` - Controller/Turbo response assertions.
- `test/fixtures/files/opml/*.opml` - Sample OPML fixtures for parsing/import/export scenarios.
- `test/fixtures/files/opml/import_happy_path.opml` - OPML 2.0 sample with nested categories and mixed feed types for happy path parsing coverage.
- `test/fixtures/files/opml/import_duplicates.opml` - OPML 1.0 sample exercising duplicate feed URL normalization (scheme, trailing slash variations).
- `test/fixtures/files/opml/import_malformed_missing_url.opml` - OPML 2.0 sample with outlines missing required attributes to cover parser error handling scenarios.
- `.ai/project_overview.md` - Document finalized OPML mapping, duplicate rules, and export naming conventions.

### Notes

- Follow strict TDD: add or update failing tests (unit, job, system) before implementing the production code they describe.
- Use `rbenv exec bundle exec` for Ruby commands; prefer `bin/rails test` targeted paths during feedback loops.
- Reuse existing Tailwind/Turbo admin patterns; keep controller namespacing under `FeedMonitor::`.
- Capture duplicate detection logic in dedicated service objects to preserve SRP and minimize coupling.
- Update instrumentation expectations alongside code so telemetry assertions remain accurate.
- Normalization audit (2025-10-24): `FeedMonitor::Source` sanitizes strings/hashes via `FeedMonitor::Models::Sanitizable`, canonicalizes `feed_url`/`website_url` through `FeedMonitor::Models::UrlNormalizable` (lowercase scheme/host, ensure trailing slash, drop fragments), and enforces a unique index plus case-insensitive validation on the normalized `feed_url`. OPML parser output should at minimum provide `name`, canonical `feed_url`, and optional `website_url`, with duplicate detection keyed off the normalized `feed_url`.

## Tasks

- [ ] 1.0 Establish OPML parsing and normalization foundations
  - [x] 1.1 Audit existing source normalization (e.g., `FeedMonitor::Sources::Normalizer`) to define expected parser output and duplicate keys.
  - [x] 1.2 Add OPML fixture files for happy path, duplicates, and malformed outline cases under `test/fixtures/files/opml/`.
  - [x] 1.3 Write failing unit specs in `test/lib/feed_monitor/opml/parser_test.rb` covering OPML 1.0/2.0 parsing, attribute mapping, and error handling.
  - [x] 1.4 Implement `FeedMonitor::OPML::Parser` (and supporting structs) until tests pass, ensuring normalized hashes align with import needs.
  - [x] 1.5 Document field mapping, duplicate logic, and unsupported attributes in `.ai/project_overview.md`.
- [ ] 2.0 Deliver admin wizard interface for OPML imports
  - [x] 2.1 Create failing system test in `test/system/opml_imports_test.rb` that exercises upload → preview filters → confirmation steps.
  - [x] 2.2 Add controller-level tests (Turbo responses, validation messaging) in `test/controllers/feed_monitor/opml_imports_controller_test.rb`.
  - [x] 2.3 Implement `FeedMonitor::OpmlImportsController`, routes, and Turbo wizard views to satisfy the tests, using existing admin layout components.
  - [x] 2.4 Enhance duplicate indicator UI and filter controls in views, covering them with view/component assertions where practical.
  - [x] 2.5 Ensure selections persist between steps via session or temporary models, with regression tests guarding against state loss.
- [ ] 3.0 Implement background import pipeline with duplicate handling
  - [x] 3.1 Author failing unit tests for `FeedMonitor::Importing::OpmlImportService` validating per-source choices (create/update/skip) and duplicate safeguards.
  - [x] 3.2 Add failing job tests in `test/jobs/feed_monitor/opml_import_job_test.rb` asserting Solid Queue queue usage, idempotency, and progress broadcasting.
  - [x] 3.3 Implement the import service, job, and associated models/log records until the tests pass, ensuring individual job execution and failure capture.
  - [x] 3.4 Wire the wizard confirmation step to enqueue import jobs, streaming progress updates via Turbo channels covered by integration tests.
  - [x] 3.5 Repurpose `FeedMonitor::Health` checks inside the import job to run a lightweight post-import health probe per source and return the status to the progress tracker.
  - [x] 3.6 Record audit entries (initiating admin, file metadata, health check results) and expose them in the UI, adding assertions to controller/system specs.
- [ ] 4.0 Ship OPML export scoping and streaming delivery
  - [ ] 4.1 Draft failing unit tests for `FeedMonitor::Exporting::OpmlExportService` covering scope filters, round-trip symmetry, and streaming enumerator behavior.
  - [ ] 4.2 Write failing job tests in `test/jobs/feed_monitor/opml_export_job_test.rb` enforcing Solid Queue usage, file naming, and status transitions.
  - [ ] 4.3 Implement export service/job plus controller endpoints/modal views to satisfy the tests, ensuring streaming download responses.
  - [ ] 4.4 Extend system coverage in `test/system/opml_exports_test.rb` for modal interaction, progress updates, and download link availability.
  - [ ] 4.5 Add regression assertions confirming exported files re-import cleanly via the parser (leveraging fixtures/tests from Task 1).
- [ ] 5.0 Solidify instrumentation, monitoring, and developer workflow support
  - [ ] 5.1 Add failing instrumentation specs (unit or integration) verifying import/export events emit expected payloads for `FeedMonitor::Instrumentation`.
  - [ ] 5.2 Extend logging/audit display tests to capture error states and summarize counts surfaced post-job completion.
  - [ ] 5.3 Update developer documentation (`.ai/project_overview.md`, README snippets) and sample commands, ensuring doc tests or lint checks pass.
  - [ ] 5.4 Run targeted suites (`bin/rails test` paths, `bin/check-diff-coverage`) and update coverage baselines if new code paths reduce diff coverage.
