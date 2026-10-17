#!/usr/bin/env python3
"""Create a fresh source-publication snapshot without local history or machine paths.
Preserves original working files and verification receipts. Does not build, test,
hash, sign, upload, initialize Git, or publish anything.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else ROOT / 'dist/publication/source'
if DEST.exists():
    raise SystemExit('Destination must be new; refusing to replace existing publication files.')
if ROOT not in DEST.parents:
    raise SystemExit('Publication working files must stay inside this checkout.')
DEST.mkdir(parents=True)
allowed_roots = {'Sources', 'Tests', 'Fixtures', 'script', 'Packaging', '.github', '.codex'}
allowed_files = {'Package.swift', '.gitignore', 'LICENSE', 'README.md'}
allowed_docs = {'DESIGN.md', 'COMPARISON_RULES.md', 'SOURCES.md', 'UI_DESIGN.md', 'RED_TEAM_REVIEW.md'}
receipts = {'33-final-debug-oracle.log', '34-final-release-oracle.log',
            '40-native-debug-tests.log', '41-native-release-tests.log',
            '42-native-repository-check.log', '67-checkpoint-session-tests.log',
            '79-export-acceptance-release-build.log', '82-stale-drop-error-debug-build.log',
            '83-stale-drop-error-release-build.log',
            '87-review-navigation-final-build.log', '89-review-navigation-release-build.log',
            '95-reload-url-green.log', '96-reload-fixed-debug-build.log',
            '97-reload-url-release.log', '98-reload-fixed-release-build.log',
            '101-inspector-debug-build.log', '102-inspector-release-build.log',
            '105-numeric-sort-tests.log', '106-numeric-sort-debug-build.log',
            '107-numeric-sort-release-tests.log', '108-numeric-sort-release-build.log',
            '111-missing-side-debug-build.log', '112-missing-side-release-build.log',
            '115-breakdown-debug-build.log', '116-breakdown-release-build.log',
            '119-filter-layout-debug-build.log', '120-filter-layout-release-build.log',
            '126-reveal-fixed-debug-build.log', '127-reveal-fixed-release-build.log',
            '130-inspector-controls-debug-build.log', '131-inspector-controls-release-build.log',
            '137-export-scope-fixed-debug-build.log', '138-export-scope-fixed-release-build.log',
            '142-row-copy-fixed-debug-build.log', '143-row-copy-release-build.log',
            '146-difference-position-debug-build.log', '147-difference-position-release-build.log',
            '152-reload-both-final-debug-tests.log', '153-reload-both-release-tests.log',
            '155-reload-both-final-debug-build.log', '156-reload-both-final-release-build.log',
            '159-filter-chips-debug-build.log', '160-filter-chips-release-build.log',
            '163-inspector-find-debug-tests.log', '164-inspector-find-debug-build.log',
            '165-inspector-find-release-tests.log', '166-inspector-find-release-build.log',
            '181-inspector-divider-debug-build.log', '182-inspector-divider-release-build.log',
            '188-refresh-feedback-final-debug-build.log', '189-refresh-feedback-final-release-build.log',
            '192-hidden-inspector-debug-build.log', '193-hidden-inspector-release-build.log',
            '196-show-in-table-debug-build.log', '197-show-in-table-release-build.log',
            '200-empty-filter-debug-build.log', '201-empty-filter-release-build.log',
            '206-match-context-final-debug-build.log', '207-match-context-final-release-build.log',
            '210-swap-selection-debug-build.log', '211-swap-selection-release-build.log',
            '214-rule-summary-debug-build.log', '215-rule-summary-release-build.log',
            '218-pointer-debug-build.log', '219-pointer-release-build.log',
            '222-relative-change-debug-tests.log', '223-relative-change-release-tests.log',
            '226-relative-extreme-debug-tests.log', '227-relative-extreme-release-tests.log',
            '228-numeric-summary-final-debug-build.log', '229-numeric-summary-final-release-build.log',
            '234-history-model-check.log', '235-history-final-debug-build.log', '236-history-final-release-build.log',
            '239-field-copy-debug-build.log', '240-field-copy-release-build.log',
            '243-field-header-debug-build.log', '244-field-header-release-build.log',
            '247-collapsible-find-debug-build.log', '248-collapsible-find-release-build.log',
            '252-search-scope-release-tests.log', '253-search-scope-debug-build.log',
            '254-search-scope-release-build.log', '255-search-scope-final-debug-tests.log',
            '259-clear-filters-control-debug-build.log', '260-clear-filters-control-release-build.log',
            '263-search-prompts-debug-build.log', '264-search-prompts-release-build.log',
            '267-history-review-debug-build.log', '268-history-review-release-build.log', '269-history-review-model-check.log',
            '272-value-summary-debug-tests.log', '273-value-summary-release-tests.log',
            '274-value-summary-debug-build.log', '275-value-summary-release-build.log'}
files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
for relative in filter(None, files):
    p = Path(relative)
    include = (p.parts[0] in allowed_roots or relative in allowed_files or
               (p.parts[0] == 'docs' and p.name in allowed_docs) or
               (p.parts[0] == 'evidence' and p.name in receipts))
    if not include:
        continue
    src, dst = ROOT / p, DEST / p
    if src.is_symlink():
        raise SystemExit(f'Refusing symlink in publication: {p}')
    dst.parent.mkdir(parents=True, exist_ok=True)
    data = src.read_bytes()
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        if b'/Users/' in data or b'/home/' in data:
            raise SystemExit(f'Private home path in binary publication input: {p}')
        shutil.copy2(src, dst)
        continue
    text = text.replace(str(ROOT), '<workspace>')
    if p.suffix in {'.md', '.log', '.txt'}:
        text = re.sub(r'/Users/[^/\s"<>]+', '/Users/<user>', text)
        text = re.sub(r'/home/[^/\s"<>]+', '/home/<user>', text)
    if p.name == 'README.md' and p.parts[0] == 'README.md':
        text = text.replace('Begin with [CODEX_HANDOFF.md](CODEX_HANDOFF.md).',
                            'See [verification](docs/VERIFICATION.md) for accepted evidence and scope.')
    if re.search(r'(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)', text):
        raise SystemExit(f'Credential-shaped content in publication input: {p}')
    dst.write_text(text)
    shutil.copymode(src, dst)
print(f'Prepared source snapshot at {DEST}; no original receipts or history changed.')

verification = ROOT / 'docs/PUBLIC_VERIFICATION.md'
if not verification.exists():
    verification = ROOT / 'docs/VERIFICATION.md'
(DEST / 'docs/VERIFICATION.md').write_text(verification.read_text().replace(str(ROOT), '<workspace>'))
