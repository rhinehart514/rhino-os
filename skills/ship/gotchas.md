# Shipping Gotchas

- **Pre-flight gate confusion**: Some checks block, some warn. If everything is a warning, nothing stops a bad deploy.
- **Deploy confidence hallucination**: Calculated from assertion pass% x deploy history, but doesn't account for change scope. A 2-line fix and a 500-line rewrite get the same confidence.
- **Feature delta mapping staleness**: If code paths in rhino.yml are outdated, git diff can't map changes to features correctly.
- **Rollback without investigation**: Reverting is fast but skipping root cause analysis means the same bug returns.
- **Secret leak in diff**: Checking for .env and credentials in the diff, not just the files. Newly added secrets in existing files are the real risk.
- **Changelog fiction**: Using roadmap.yml for changelog assumes roadmap is current. Stale roadmap = fictional changelog.
- **Release notes slop**: "Improved performance" and "enhanced user experience" are the release notes equivalent of adjective addiction.
- **Force push to main**: Never. The pre-commit hook should catch this but the skill should refuse too.
