# Public Beta Screenshot Checklist

Screenshots are intentionally not included during repository preparation because real scan results may expose private filenames and local paths.

Before the public beta, capture sanitized examples of:

- Overview
- Low Risk Cleanup
- Review
- Item Detail / Source Explanation
- Large Files
- Time Organized
- Scan Report

Actual screenshots are currently pending. The repository deliberately uses text placeholders so GitHub does not show broken image links.

## Safe Fixture Plan

Do not capture a real user scan. Use a temporary macOS test account and populate only synthetic items such as:

- `/Users/test/Library/Caches/pip/http-v2/example-package.whl`
- `/Users/test/Library/Caches/pnpm/metadata/example.json`
- `/Users/test/Library/Caches/ExampleApp/Cache.db`
- `/Users/test/Downloads/ExampleProject/demo-video.mov`
- `/Users/test/Desktop/ExampleDesign.psd`
- `/private/var/folders/.../T/codex-file-preview-DEMO/ExampleReport.pdf`

Names, sizes, dates, source descriptions, and report text must be fabricated. Never copy a real scan report and redact it after capture.

The app does not include a demo-data mode in the production target. Adding one solely for screenshots would risk shipping test data or changing scan behavior, so screenshots should be prepared in an isolated test account instead.

## Capture Flow

1. Create or use an isolated test account with no personal documents.
2. Build and launch the exact Release candidate.
3. Create only the synthetic files required for the screen being captured.
4. Capture the seven screens at a consistent window size and appearance.
5. Inspect every visible path, filename, menu-bar item, window title, and background app.
6. Remove the synthetic data after capture.
7. Have a second reviewer verify that every image is free of personal information before committing it.

## Capture Guidelines

- Use synthetic or fully sanitized scan data.
- Hide usernames, home-directory names, filenames, client names, and project names.
- Do not show an unredacted scan report.
- Check Finder paths, window titles, menu bar extras, and background windows.
- Prefer consistent window dimensions and appearance across the set.
- Do not include desktop wallpaper, other app windows, account avatars, or menu-bar identifiers.
- Do not commit screenshots until the second-person privacy review passes.

## Required Files

- `overview.png`
- `low-risk-cleanup.png`
- `review-required.png`
- `source-explanation-detail.png`
- `large-files.png`
- `time-organized.png`
- `scan-report.png`
