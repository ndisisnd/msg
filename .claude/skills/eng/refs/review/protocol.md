# eng — Mode: --review

*Protocol TBD — defined in improvement plan 7.3-eng-review.*

This mode reads existing code, runs four checks (test execution, assertion audit, adversarial gap scan, code quality scan), and writes a JSON review file to `features/prd-[n]/reviews/`. It never writes or modifies code.

It follows the shared spine in `SKILL.md`: input validation, PRD + devkit read, summary + approval gate, codebase scan, platform + coding standards, and continuous scope enforcement. The review-specific checks, verdict logic, and the output template (`refs/review/template-review-output.json`, per plan 7.3-eng-review) will be filled in here.
