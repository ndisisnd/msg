# Acceptance Criteria — 5-msg-insights

1. Selecting "Insights" from the `/msg` menu executes the insights report inline without requiring a separate command.
2. If rtk is installed, `rtk gain --history` is run and its output is parsed — not emitted raw.
3. The report shows at least the top 5 commands by frequency in a readable table.
4. The report includes total tokens saved as a number.
5. The report includes the date range covered by the history.
6. If rtk is not installed or exits non-zero, the skill emits `[WARN] rtk not available — insights unavailable` and exits cleanly.
7. If rtk is installed but history is empty, the skill emits "No usage history recorded yet." rather than an error or empty output.
