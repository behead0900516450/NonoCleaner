# Contributing to Nono Cleaner

Thank you for helping improve Nono Cleaner. This is a safety-focused filesystem utility, so conservative behavior and reproducible evidence are more important than maximizing the amount of storage marked for cleanup.

By contributing, you agree that accepted contributions may be distributed under the project's [Source-Available Beta License](LICENSE). Only submit work that you have the right to contribute.

## Reporting a Bug

Use the GitHub bug report template and include:

- Nono Cleaner version
- macOS version and Mac chip
- Clear reproduction steps
- Expected and actual behavior
- A sanitized screenshot or minimal report excerpt when useful

Do not attach files that Nono Cleaner scanned.

## Identifying an Unknown Cache

Use the cache-identification template. Provide a generalized path, suspected source application, typical file types, and evidence explaining how the data is created and whether it can be regenerated.

Documentation from the application vendor or a repeatable local test is preferred over assumptions based only on a folder name.

## Reporting a Misclassification

Use the misclassification template and include:

- Original path, with the username and private components masked
- Current classification
- Expected classification
- Source application or tool
- The matched rule
- Evidence explaining why the current classification is wrong

## Pull Request Principles

- Keep each pull request focused and explain its user-visible impact.
- Preserve the default of no automatic deletion and Trash-only cleanup.
- Do not weaken macOS permission boundaries.
- Add or update regression tests for behavior changes.
- Changes to `SafetyClassifier` require regression tests covering both the intended case and nearby cases that must not change.
- Moving an item from Review to Low Risk requires explicit, reproducible evidence that the content can be regenerated and is not user work.
- Changes whose main purpose is to classify more storage as Low Risk without stronger safety evidence will not be accepted.
- Unknown or ambiguous cases should remain Review.

## Privacy and Repository Hygiene

Never submit:

- Private or unredacted scan reports
- Personal filenames or project names
- Real home-directory paths or usernames
- API keys, access tokens, passwords, or secrets
- Customer data or file contents
- Signing certificates, provisioning profiles, or notarization credentials
- Build output or crash reports containing personal information

Use placeholders such as `/Users/test/` or `~/Library/Caches/com.example.app/` in tests and documentation.

Before opening a pull request, inspect the changed files and run the available regression tests.
