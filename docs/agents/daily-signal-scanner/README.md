# Daily Signal Scanner

Automated buying signal detection for Surfaced GTM. Scans Reddit and web sources for GEO/AI search signals every weekday morning, scores them against the ICP, and produces a daily brief with draft outreach messages.

## Prerequisites

- `bash` (macOS default)
- `python3` (macOS default, or install via Homebrew)
- `curl` (macOS default)
- `claude` CLI installed and authenticated ([install guide](https://docs.anthropic.com/en/docs/claude-code))
- No API keys needed — uses Reddit's public JSON API and Claude's built-in WebSearch

## Quick Start

1. Make the script executable:
   ```bash
   chmod +x docs/agents/daily-signal-scanner/run.sh
   ```

2. Test with a manual run:
   ```bash
   ./docs/agents/daily-signal-scanner/run.sh
   ```

3. Check the output:
   ```bash
   cat docs/reports/daily/$(date +%Y-%m-%d).md
   ```

4. If it looks good, install the schedule:
   ```bash
   cp docs/agents/daily-signal-scanner/schedule.plist ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
   launchctl load ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
   ```

5. Verify it's loaded:
   ```bash
   launchctl list | grep daily-signal-scanner
   ```

## Files

| File | Purpose |
|---|---|
| `run.sh` | Shell wrapper — scrapes Reddit, deduplicates, invokes Claude |
| `prompt.md` | System prompt — tells Claude how to score signals and draft messages |
| `config.yaml` | Configuration — subreddits, keywords, budget, schedule |
| `schedule.plist` | macOS launchd config — fires weekdays at 08:00 |
| `architecture.md` | Architecture doc — pattern diagram, data flow, cost estimate |
| `logs/` | Created on first run — stores run logs, processed IDs, gate file |

## Output

Daily briefs are written to `docs/reports/daily/YYYY-MM-DD.md`. Each brief contains:

- **HOT leads** (score 12-15/15) with draft outreach messages ready to personalize and send
- **WARM leads** (score 8-11/15) with monitoring notes
- **Skip summary** explaining what was filtered out

## Daily Workflow

1. Agent runs automatically at 08:00 on weekdays
2. Open `docs/reports/daily/today's-date.md`
3. Review HOT leads — personalize the draft messages and send
4. Scan WARM leads — add any to your watch list
5. Total time: 10-15 minutes

## Customization

### Adding subreddits or keywords
Edit `config.yaml` → `data_sources[0].subreddits` and `data_sources[0].keywords`. Also update `run.sh` → the `SUBREDDITS` and `KEYWORDS` arrays.

### Changing the scoring threshold
Edit `config.yaml` → `filters.hot_threshold` (default: 12) and `filters.min_score` (default: 8).

### Adjusting the schedule
Edit `schedule.plist` → `StartCalendarInterval` → `Hour` and `Minute`. Reload after editing:
```bash
launchctl unload ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
launchctl load ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
```

### Changing what Claude does
Edit `prompt.md`. The shell script does not need to change unless you're adding new data sources.

## Cost

~$0.23/run, ~$5/month (22 weekday runs). Well under any reasonable budget.

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Script exits with "Gate check" | Ran less than 20 hours ago | Wait, or delete `logs/daily-signal-scanner_last_run.txt` |
| "No new signals found" | All posts were already processed | Normal — means no new GEO content was posted since last run |
| Reddit returns HTTP 429 | Rate limited | Increase the `sleep` between requests in `run.sh` (currently 1s) |
| Claude produces no output | Prompt too large | Check the temp files in `$TMPDIR` — reduce `max_items` in config |
| Empty daily brief | No signals scored above threshold | Lower `filters.min_score` in config, or add more keywords |

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
rm ~/Library/LaunchAgents/com.surfaced.daily-signal-scanner.plist
```
