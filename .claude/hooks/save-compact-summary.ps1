param()
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$ts = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$dateDisplay = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$inboxDir = 'D:\Obsidian\30-项目\大周天\08-开发日志\收件箱'
if (-not (Test-Path $inboxDir)) { New-Item -ItemType Directory -Force -Path $inboxDir | Out-Null }
$outPath = Join-Path $inboxDir "context-inbox-$ts.md"

try {
  $d = $raw | ConvertFrom-Json
  $trigger = $d.trigger
  $sessionId = $d.session_id

  # Build markdown
  $text = '# Context Inbox ' + $dateDisplay + [Environment]::NewLine + [Environment]::NewLine
  $text = $text + '**Trigger**: ' + $trigger + [Environment]::NewLine
  $text = $text + '**Session**: ' + $sessionId + [Environment]::NewLine
  $text = $text + [Environment]::NewLine + '---' + [Environment]::NewLine + [Environment]::NewLine

  # Try known summary fields
  $summary = $d.summary
  if (-not $summary) { $summary = $d.compacted_summary }
  if (-not $summary) { $summary = $d.content }
  if (-not $summary) { $summary = $d.text }
  if ($summary) {
    $text = $text + $summary + [Environment]::NewLine
  } else {
    $text = $text + '`json' + [Environment]::NewLine + $raw + [Environment]::NewLine + '`' + [Environment]::NewLine
  }

  $text | Out-File -Encoding utf8 -FilePath $outPath

  # Output JSON to stdout -> hook system injects additionalContext into Claude
  $instruction = '[SYSTEM INSTRUCTION] Your context was just compacted (trigger: ' + $trigger + '). A conversation summary has been saved to: ' + $outPath.replace('\', '\\') + '. Please IMMEDIATELY do the following: 1) Read the summary file at that path 2) Analyze which project modules (M0: core data, M1: meridian/qi, M2: battle, M3: run/flow, M4: artifacts, M5: UI, M6: game state) were discussed 3) Identify key decisions, code changes, design updates, and bugs 4) Update the corresponding Obsidian documentation files under D:\\Obsidian\\30-项目\\大周天\\ (01-架构设计 through 08-开发日志) with the new information 5) If a topic spans multiple modules, update all relevant files. This is CRITICAL for maintaining project knowledge continuity.'
  $output = @{
    systemMessage = 'Context compacted. Summary saved to Obsidian inbox: ' + $outPath
    hookSpecificOutput = @{
      hookEventName = 'PostCompact'
      additionalContext = $instruction
    }
  }
  $output | ConvertTo-Json -Depth 3 -Compress

} catch {
  $raw | Out-File -Encoding utf8 -FilePath $outPath
  $output = @{
    systemMessage = 'Compaction summary saved (raw) to: ' + $outPath
    hookSpecificOutput = @{
      hookEventName = 'PostCompact'
      additionalContext = '[SYSTEM] Context compacted. Raw summary at: ' + $outPath.replace('\', '\\') + '. Read it and organize into project docs.'
    }
  }
  $output | ConvertTo-Json -Depth 3 -Compress
}
