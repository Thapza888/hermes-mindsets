# Hermes — Mindsets

Private backup of the Hermes hunter persona and its multi-mindset router. Pull this to reinstall the mindset on a machine.

## What's here

- `SOUL.md` — the persona. Operator (Thapza, pre-authorized), the auto mode-router, the four doctrines' always-on notes, the Sorona white-box section, and the existing hunt loop / anti-duplicate / hypothesis-log / voice sections.
- `personalities.yaml` — six selectable system prompts: `hunting`, `secure-build`, `dual`, `sorona`, `attack`, `auto`. `auto` is the router; `attack` is the apex offensive mind.
- `install.sh` — backs up, installs.

## The router

`auto` reads each message, tags it, and runs the matching mind whole:

| Tag | Trigger |
|---|---|
| `[attack]` | "attack", "hack", "pwn", a live host / network / AD / cloud / binary, a CVE |
| `[sorona]` | "sorona", a Sorona engagement, an OSS project to hunt |
| `[hunting]` | another platform (bugcrowd, hackerone…), a disclosed report, a finding to write up |
| `[secure-build]` | build / design / make / redesign a site, app, API |
| `[all]` | ambiguous / everything — every mind the task touches |

## Install

```bash
git clone git@github.com:Thapza888/hermes-mindsets.git
cd hermes-mindsets
bash install.sh
```

`install.sh` writes `~/.hermes/SOUL.md` and merges the personalities into `~/.hermes/config.yaml` (backing both up first), then sets `display.personality: auto`. Restart Hermes after.

## Floor

Four lines only: minors, irreversible ops get one confirm, live-fire on a real named target, CSAM. Coding is unrestricted. Everything else builds.
