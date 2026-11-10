#!/usr/bin/env python3
"""Validate the Sentinel analytics rule YAML files in detections/sentinel/.

Why this exists: Terraform only finds a bad rule file when it calls the Azure API, which is slow and
happens late (during plan or apply). This script catches the common mistakes in about a second, on every
pull request, before Terraform runs. It's called from .github/workflows/lab-validate.yml.

Usage:
    python3 lab/scripts/validate_detections.py                 # checks detections/sentinel/*.yaml
    python3 lab/scripts/validate_detections.py path/to/rules   # checks another folder

Exit code 0 = all files valid, 1 = at least one error (CI fails), 2 = folder missing or empty.
Only the standard library and PyYAML (pip install pyyaml) are needed.
"""

from __future__ import annotations

import re
import sys
import uuid
from datetime import timedelta
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_RULES_DIR = REPO_ROOT / "detections" / "sentinel"

# Fields every rule file must have (see detections/sentinel/schema.md).
REQUIRED_FIELDS = [
    "id", "name", "description", "severity", "enabled", "queryFrequency", "queryPeriod",
    "triggerOperator", "triggerThreshold", "tactics", "techniques", "entityMappings",
    "requiredDataConnectors", "requiredTables", "sourceRule", "query",
]

# Allowed values below are copied from the azurerm provider / Sentinel API (2023-12-01-preview), so a
# typo fails here instead of at `terraform apply`.
SEVERITIES = {"Informational", "Low", "Medium", "High"}
TRIGGER_OPERATORS = {"GreaterThan", "LessThan", "Equal", "NotEqual"}
TACTICS = {
    "Collection", "CommandAndControl", "CredentialAccess", "DefenseEvasion", "Discovery", "Execution",
    "Exfiltration", "Impact", "ImpairProcessControl", "InhibitResponseFunction", "InitialAccess",
    "LateralMovement", "Persistence", "PreAttack", "PrivilegeEscalation", "Reconnaissance",
    "ResourceDevelopment",
}
ENTITY_TYPES = {
    "Account", "AzureResource", "CloudApplication", "DNS", "File", "FileHash", "Host", "IP", "MailCluster",
    "MailMessage", "Mailbox", "Malware", "Process", "RegistryKey", "RegistryValue", "SecurityGroup",
    "SubmissionMail", "URL",
}
MAX_ENTITY_MAPPINGS = 10      # Sentinel limit per rule
MAX_FIELD_MAPPINGS = 3        # Sentinel limit per entity mapping
MAX_QUERY_LENGTH = 10_000     # Sentinel limit for a scheduled rule query
MIN_DURATION = timedelta(minutes=5)   # PT5M, shortest frequency/period Sentinel allows
MAX_DURATION = timedelta(days=14)     # P14D, longest frequency/period Sentinel allows

# Defender-only tables that must not survive the conversion.
DEFENDER_ONLY_TABLES = {"EntraIdSignInEvents", "AADSignInEventsBeta", "CloudAppEvents", "IdentityLogonEvents"}
# Tables these rules may read. If a query mentions one, it must also be listed in requiredTables,
# otherwise Terraform's "available_tables" gate can't protect the deployment.
KNOWN_TABLES = {
    "SigninLogs", "AADNonInteractiveUserSignInLogs", "OfficeActivity", "EmailEvents", "EmailUrlInfo",
    "EmailAttachmentInfo", "EmailPostDeliveryEvents", "UrlClickEvents", "DeviceProcessEvents",
    "DeviceRegistryEvents", "DeviceNetworkEvents", "DeviceFileEvents", "DeviceEvents", "DeviceLogonEvents",
    "AuditLogs", "SecurityEvent",
}

GUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
TECHNIQUE_RE = re.compile(r"^T\d{4}$")   # parent technique only (no .001)
# ISO 8601 durations as Sentinel uses them: P[nD][T[nH][nM][nS]], e.g. PT1H, PT12H, P1D, P14D.
DURATION_RE = re.compile(r"^P(?:(?P<d>\d+)D)?(?:T(?:(?P<h>\d+)H)?(?:(?P<m>\d+)M)?(?:(?P<s>\d+)S)?)?$")


def parse_duration(value: object) -> timedelta | None:
    """Return the timedelta for an ISO 8601 duration string, or None if it isn't one."""
    if not isinstance(value, str):
        return None
    match = DURATION_RE.match(value)
    if not match or value in ("P", "PT") or value.endswith("T"):
        return None
    parts = {k: int(v) if v else 0 for k, v in match.groupdict().items()}
    return timedelta(days=parts["d"], hours=parts["h"], minutes=parts["m"], seconds=parts["s"])


def strip_kql_comments(query: str) -> str:
    """Remove // comments so words in comments (e.g. 'Timestamp -> TimeGenerated') don't trigger checks.

    Simple on purpose: it ignores // inside string literals, which is fine for these rules (none contain
    URLs inside a quoted string followed by a table name).
    """
    return "\n".join(line.split("//", 1)[0] for line in query.splitlines())


def validate_rule(path: Path, rule: object, seen_ids: dict[str, Path]) -> tuple[list[str], list[str]]:
    """Return (errors, warnings) for one rule file."""
    errors: list[str] = []
    warnings: list[str] = []

    if not isinstance(rule, dict):
        return [f"top level must be a mapping, got {type(rule).__name__}"], warnings

    missing = [f for f in REQUIRED_FIELDS if f not in rule or rule[f] is None or rule[f] == ""]
    if missing:
        errors.append(f"missing required field(s): {', '.join(missing)}")

    # id: a GUID, unique across all files (Sentinel uses it as the rule's resource name).
    rule_id = rule.get("id")
    if rule_id is not None:
        if not isinstance(rule_id, str) or not GUID_RE.match(rule_id):
            errors.append(f"id '{rule_id}' is not a valid GUID")
        else:
            uuid.UUID(rule_id)  # second check: the stdlib parser agrees
            key = rule_id.lower()
            if key in seen_ids:
                errors.append(f"duplicate id {rule_id} (also used by {seen_ids[key].name})")
            else:
                seen_ids[key] = path

    if "severity" in rule and rule["severity"] not in SEVERITIES:
        errors.append(f"severity '{rule['severity']}' must be one of {sorted(SEVERITIES)}")

    if "enabled" in rule and not isinstance(rule["enabled"], bool):
        errors.append("enabled must be true or false")

    # Durations: valid ISO 8601 and inside Sentinel's PT5M..P14D window.
    for field in ("queryFrequency", "queryPeriod"):
        if field not in rule:
            continue
        duration = parse_duration(rule[field])
        if duration is None:
            errors.append(f"{field} '{rule[field]}' is not an ISO 8601 duration (e.g. PT1H, P1D)")
        elif not MIN_DURATION <= duration <= MAX_DURATION:
            errors.append(f"{field} '{rule[field]}' must be between PT5M and P14D")
        elif isinstance(rule[field], str) and rule[field] in ("PT24H", "PT48H"):
            warnings.append(f"{field} '{rule[field]}': write whole days as P1D/P2D to avoid Terraform drift")

    # The azurerm provider refuses a frequency longer than the period (it would leave gaps in coverage).
    freq, period = parse_duration(rule.get("queryFrequency")), parse_duration(rule.get("queryPeriod"))
    if freq and period and freq > period:
        errors.append("queryFrequency must not be longer than queryPeriod (that would leave gaps between runs)")

    if "triggerOperator" in rule and rule["triggerOperator"] not in TRIGGER_OPERATORS:
        errors.append(f"triggerOperator '{rule['triggerOperator']}' must be one of {sorted(TRIGGER_OPERATORS)}")
    if "triggerThreshold" in rule and (
        not isinstance(rule["triggerThreshold"], int) or isinstance(rule["triggerThreshold"], bool)
        or rule["triggerThreshold"] < 0
    ):
        errors.append("triggerThreshold must be a whole number >= 0")

    tactics = rule.get("tactics")
    if tactics is not None:
        if not isinstance(tactics, list) or not tactics:
            errors.append("tactics must be a non-empty list")
        else:
            bad = [t for t in tactics if t not in TACTICS]
            if bad:
                errors.append(f"unknown tactic(s) {bad}; use Sentinel names like InitialAccess")

    techniques = rule.get("techniques")
    if techniques is not None:
        if not isinstance(techniques, list) or not techniques:
            errors.append("techniques must be a non-empty list")
        else:
            bad = [t for t in techniques if not isinstance(t, str) or not TECHNIQUE_RE.match(t)]
            if bad:
                errors.append(f"technique(s) {bad} must be parent IDs like T1078 (put sub-techniques in the description)")

    query = rule.get("query") if isinstance(rule.get("query"), str) else ""
    code = strip_kql_comments(query)
    if len(query) > MAX_QUERY_LENGTH:
        errors.append(f"query is {len(query)} characters; Sentinel allows {MAX_QUERY_LENGTH}")

    # requiredTables: non-empty, and it must cover every known table the query reads.
    tables = rule.get("requiredTables")
    if tables is not None:
        if not isinstance(tables, list) or not tables or not all(isinstance(t, str) and t for t in tables):
            errors.append("requiredTables must be a non-empty list of table names")
        elif query:
            used = {t for t in KNOWN_TABLES if re.search(rf"\b{t}\b", code)}
            not_listed = sorted(used - set(tables))
            if not_listed:
                errors.append(f"query reads {not_listed} but requiredTables doesn't list them")
            unused = sorted(set(tables) - used)
            if unused:
                warnings.append(f"requiredTables lists {unused} but the query doesn't appear to read them")

    connectors = rule.get("requiredDataConnectors")
    if connectors is not None:
        if not isinstance(connectors, list) or not connectors:
            errors.append("requiredDataConnectors must be a non-empty list")
        else:
            for c in connectors:
                if isinstance(c, dict):
                    if not c.get("connectorId"):
                        errors.append("each requiredDataConnectors entry needs a connectorId")
                elif not isinstance(c, str):
                    errors.append("requiredDataConnectors entries must be strings or {connectorId, dataTypes}")

    # Leftovers from the Defender version.
    for table in DEFENDER_ONLY_TABLES:
        if re.search(rf"\b{table}\b", code):
            errors.append(f"query still uses Defender-only table {table}")
    for column in ("Timestamp", "ReportId"):
        if re.search(rf"\b{column}\b", code):
            warnings.append(f"query mentions {column}; Sentinel uses TimeGenerated and doesn't need ReportId")

    # Entity mappings: allowed types, Sentinel limits, and the mapped column must appear in the query.
    mappings = rule.get("entityMappings")
    if mappings is not None:
        if not isinstance(mappings, list) or not mappings:
            errors.append("entityMappings must be a non-empty list")
        else:
            if len(mappings) > MAX_ENTITY_MAPPINGS:
                errors.append(f"{len(mappings)} entity mappings; Sentinel allows {MAX_ENTITY_MAPPINGS}")
            for i, m in enumerate(mappings):
                where = f"entityMappings[{i}]"
                if not isinstance(m, dict):
                    errors.append(f"{where} must be a mapping")
                    continue
                if m.get("entityType") not in ENTITY_TYPES:
                    errors.append(f"{where}.entityType '{m.get('entityType')}' is not a Sentinel entity type")
                fields = m.get("fieldMappings")
                if not isinstance(fields, list) or not fields:
                    errors.append(f"{where}.fieldMappings must be a non-empty list")
                    continue
                if len(fields) > MAX_FIELD_MAPPINGS:
                    errors.append(f"{where} has {len(fields)} field mappings; Sentinel allows {MAX_FIELD_MAPPINGS}")
                for f in fields:
                    if not isinstance(f, dict) or not f.get("identifier") or not f.get("columnName"):
                        errors.append(f"{where}.fieldMappings entries need identifier and columnName")
                    elif query and not re.search(rf"\b{re.escape(str(f['columnName']))}\b", code):
                        errors.append(f"{where} maps column '{f['columnName']}' which the query never mentions")

    # sourceRule must point at an existing Defender .kql file, relative to this YAML.
    source = rule.get("sourceRule")
    if isinstance(source, str) and source:
        target = (path.parent / source).resolve()
        if not target.is_file():
            errors.append(f"sourceRule '{source}' does not exist ({target})")
        elif target.stem != path.stem:
            warnings.append(f"sourceRule '{source}' has a different name from this file")

    return errors, warnings


def main(argv: list[str]) -> int:
    rules_dir = Path(argv[1]).resolve() if len(argv) > 1 else DEFAULT_RULES_DIR
    files = sorted(rules_dir.glob("*.yaml")) + sorted(rules_dir.glob("*.yml"))
    if not files:
        print(f"ERROR: no *.yaml files found in {rules_dir}")
        return 2

    seen_ids: dict[str, Path] = {}
    failed = 0
    warned = 0
    for path in files:
        try:
            rule = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            print(f"FAIL  {path.name}: invalid YAML: {exc}")
            failed += 1
            continue
        errors, warnings = validate_rule(path, rule, seen_ids)
        status = "FAIL" if errors else "ok  "
        print(f"{status}  {path.name}")
        for e in errors:
            print(f"        error:   {e}")
        for w in warnings:
            print(f"        warning: {w}")
        failed += bool(errors)
        warned += bool(warnings)

    print(f"\n{len(files)} rule file(s) checked: {len(files) - failed} passed, {failed} failed, {warned} with warnings.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
