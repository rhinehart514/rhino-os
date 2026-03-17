# Assertion Gotchas

- **File-check only**: `file_check` assertions only verify existence. A file can exist and be completely broken. Mix assertion types.
- **Assertion without evidence**: An assertion should test something that would break if the feature regressed. If it can't fail, it's not testing anything.
- **Coverage theater**: 20 assertions that all pass but only test file existence = 0 signal. 5 assertions with content_check and command_check = high signal.
- **Ideal distribution**: 30% mechanical (file_check/content_check), 50% behavioral (command_check), 20% judgment (llm_judge). Most projects are 90% file_check.
- **LLM judge variance**: llm_judge assertions produce different results across runs. Use sparingly and for things that can't be checked mechanically.
- **Assertion gaming**: Builder agents can make assertions pass by testing the wrong thing. Review assertion quality, not just pass rate.
- **Orphaned assertions**: Assertions for killed features still count toward pass rate. Clean up after /feature kill.
- **Block vs warn severity**: Block-severity failures halt /go. Warn-severity just flag. Choose carefully — too many blocks = /go never runs.
