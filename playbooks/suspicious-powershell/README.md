# Playbook: Suspicious PowerShell Execution

**Platform:** Microsoft Defender XDR Advanced Hunting (Defender for Endpoint)
**Triggers:** *Suspicious PowerShell command line*, *Suspicious process executed PowerShell command*, *Malicious copy and paste (ClickFix)*, AMSI detections, Office apps spawning scripts
**MITRE ATT&CK:** T1059.001 PowerShell · T1027.010 Command Obfuscation · T1105 Ingress Tool Transfer · T1562.001 Impair Defenses · T1204.002 Malicious File · T1204.004 Malicious Copy and Paste

---

## Red flags in a PowerShell command line

| Pattern | Why attackers use it |
|---|---|
| `-enc` / `-e` / `-EncodedCommand` + long Base64 | Hides the real command from casual inspection |
| `IEX` / `Invoke-Expression` + `DownloadString` / `iwr` / `irm` | Downloads and runs code in memory (download cradle) |
| `-w hidden`, `-nop`, `-noni` | Hidden window, skip the profile, no prompts |
| `AmsiUtils`, `amsiInitFailed` | Disables AMSI so Defender can't scan the script |
| `Set-MpPreference` / `Add-MpPreference -ExclusionPath` | Turns off Defender or excludes the malware folder |
| Parent is `winword.exe`, `excel.exe`, `outlook.exe`, `mshta.exe` | Malicious document or HTA launching a script |
| Parent is `explorer.exe` and the command came from the Run dialog | **ClickFix**: a fake CAPTCHA tricked the user into pasting a command |

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Encoded commands (decoded) | [01-encoded-commands.kql](queries/01-encoded-commands.kql) | Base64 commands decoded inline. Check the decoded text for downloads or IEX. |
| 2 | Download cradles | [02-download-cradles.kql](queries/02-download-cradles.kql) | PowerShell downloading and executing content. Rare commands (few devices) first. |
| 3 | Defense evasion | [03-defense-evasion.kql](queries/03-defense-evasion.kql) | AMSI bypasses, Defender tampering, log clearing |
| 4 | Suspicious parent processes | [04-suspicious-parents.kql](queries/04-suspicious-parents.kql) | Office, mail, HTA or script hosts spawning PowerShell or other script engines |
| 5 | ClickFix (Run dialog) | [05-clickfix-run-dialog.kql](queries/05-clickfix-run-dialog.kql) | Commands pasted into Win+R (RunMRU registry key) |
| 6 | Rare network destinations | [06-rare-powershell-network.kql](queries/06-rare-powershell-network.kql) | PowerShell connecting to public domains seen on only 1–2 devices |
| 7 | Device timeline | [07-device-timeline.kql](queries/07-device-timeline.kql) | Everything on the device ±30 minutes around the event: processes, network, files, registry, logons |

## Common false positives

- **IT and management tools** (Intune, SCCM, RMM agents, Defender itself) that run encoded or hidden PowerShell **on many devices** at the same time. Steps 2 and 6 sort rare commands first for this reason.
- **Admin scripts** that download modules from the PowerShell Gallery or GitHub.
- **Developer machines.** Check the account and the device role before escalating.

## Verdict

**Likely malicious** if *any* of these are true:
- The decoded command downloads and executes content from an unknown domain or IP
- PowerShell was launched by an Office app, Outlook, mshta, or from the Run dialog (ClickFix)
- AMSI was bypassed or Defender settings were changed by a non-admin or non-IT process
- The command appears on only one or two devices and the destination domain is new

## Containment

1. [ ] **Isolate the device** (Defender → Device → Isolate device).
2. [ ] **Collect an investigation package** and run a full antivirus scan.
3. [ ] **Block** the downloaded file hashes, domains and IPs with Defender indicators.
4. [ ] **Check the user's account.** ClickFix and info-stealer payloads steal browser cookies and passwords, so revoke sessions and reset the password.
5. [ ] **Hunt the IOCs across all devices** (steps 2 and 6 with the domain or hash).
6. [ ] **Hardening:** Attack Surface Reduction rules (block Office child processes, block obfuscated scripts), Constrained Language Mode, PowerShell script block logging, and restricting the Run dialog for standard users where practical.

## Related detection rules

- [Office, Outlook, HTA or server process spawning PowerShell or another script engine](../../detections/powershell-office-child-process.kql)
- [Encoded PowerShell whose decoded content downloads or executes code](../../detections/powershell-encoded-download.kql)
- [ClickFix: a script or download command typed/pasted into the Windows Run dialog](../../detections/powershell-clickfix-runmru.kql)
- [PowerShell disabling AMSI/Defender, adding exclusions, or clearing event logs](../../detections/powershell-defender-tampering.kql)

## Templates

- [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- [closure-notes.md](../../templates/closure-notes.md)
- [incident-report.md](../../templates/incident-report.md)
