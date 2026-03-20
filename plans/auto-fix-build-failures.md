# Auto-Fix Build Failures - Implementation Plan

## Overview
When a build fails, automatically attempt to fix the issues and retry the build.
Goal: Preserve existing implementation as much as possible while making the build work.

## Trigger
- Only runs AFTER build failure is detected (existing Telegram notification triggers)
- Integrates with existing github-listener server.js build logic

## ☐ Phase 1: Research & Exploration

- [ ] 1.1 Understand Garden Manager architecture
  - [ ] 1.1.1 Find where build commands are executed
  - [ ] 1.1.2 Identify where build output/status is captured
- [ ] 1.2 Study existing error handling patterns
  - [ ] 1.2.1 Look at how other errors are handled in Garden Manager
  - [ ] 1.2.2 Identify logging/output mechanisms
- [ ] 1.3 Find existing build-related code
  - [ ] 1.3.1 Locate build command execution logic
  - [ ] 1.3.2 Find how build results are reported

## ☐ Phase 2: Build Failure Detection

- [ ] 2.1 Detect when a build fails
  - [ ] 2.1.1 Use existing github-listener detection (line 117-118 in server.js)
  - [ ] 2.1.2 Parse build output for error patterns
  - [ ] 2.1.3 Identify error types (compile errors, linker errors, etc.)
- [ ] 2.2 Extract error details
  - [ ] 2.2.1 Parse file paths from error messages
  - [ ] 2.2.2 Extract line numbers
  - [ ] 2.2.3 Extract error descriptions

## ☐ Phase 3: Code Analysis & Auto-Fix

- [ ] 3.1 Analyze error type
  - [ ] 3.1.1 Determine if it's a simple fix (typo, missing import, etc.)
  - [ ] 3.1.2 Categorize: syntax, import, API mismatch, missing file
- [ ] 3.2 Implement fix strategies
  - [ ] 3.2.1 For missing imports: add import statement
  - [ ] 3.2.2 For typos: use Levenshtein distance to find closest match
  - [ ] 3.2.3 For API changes: find correct API from codebase
  - [ ] 3.2.4 For deprecated APIs: suggest replacement
- [ ] 3.3 Apply fixes automatically
  - [ ] 3.3.1 Edit files to apply fixes
  - [ ] 3.3.2 Verify fix doesn't break other code

## ☐ Phase 4: Retry Build

- [ ] 4.1 Re-run build after fixes
- [ ] 4.2 Check if build succeeds
- [ ] 4.3 Report results to user
- [ ] 4.4 Handle repeated failures gracefully

## ☐ Phase 5: User Experience

- [ ] 5.1 Add user preference to enable/disable auto-fix
- [ ] 5.2 Show what changes were made
- [ ] 5.3 Allow user to undo fixes
- [ ] 5.4 Log all auto-fixes for review

## ☐ Phase 6: Testing & Refinement

- [ ] 6.1 Test with various error types
- [ ] 6.2 Test that fixes don't introduce new errors
- [ ] 6.3 Handle edge cases
- [ ] 6.4 Build and verify success
- [ ] 6.5 Push changes

---

## Notes

- **Preserve implementation**: Only change what's absolutely necessary to fix the build
- **Minimal edits**: Prefer smallest possible changes to fix each error
- **Don't rewrite logic**: If code logic is wrong, prefer to comment it out or add TODO rather than rewrite
- Start simple: fix common errors like missing imports, typo fixes
- Use existing codebase patterns for any new code
- Don't try to fix complex logic errors - just simple syntactic issues
- Always verify build succeeds after auto-fix
- Send Telegram message with fix summary (what was changed)
