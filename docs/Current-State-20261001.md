# Current State — 1 October 2026

Alignment implementation: ce8c09d, verified on both Macs.
Both canonical repositories were clean and aligned with GitHub.
Both machine profiles passed brew bundle check --no-upgrade --verbose.

COMPLETE:
- Controlled refresh of all 12 named shared font casks on both Macs.
- Shared Aptos, Roboto and Roboto Flex baseline.
- Separate common, Shannon and PHL Brewfile profiles.
- Intentional Shannon NVM / PHL Homebrew Node distinction preserved.
- Shannon standard FFmpeg and subtitle-capable ffmpeg@7 preserved.
- Historical Brewfile retained; Code2002 retired.
- Stale duplicate clone archived intact.

Archive: /Users/sthanrahan/Projects/Archive/macos-brew-setup-20261001-114446
Archived HEAD: 1d6d26c; clean main, no unique commits, nine commits behind
the canonical repository at review.

Canonical repository: git@github.com:sthanrahan/macos-brew-setup.git
Canonical clone on both Macs: ~/.dotfiles
Branch: main

Future review:
- Fresh-machine restoration and complete third-party tap discovery.
- Two retained Shannon Pages App Store IDs.
- Persistent greedy latest-to-latest font reports: upgrades succeeded;
  do not repeat refreshes solely because those reports persist.

No further work is required for the verified current alignment.
The original pre-refresh handover is historical.

## Post-alignment change

Telegram Desktop beta was uninstalled from Shannon MBP 13 - M1 (2020).
Its declaration moved from shared baseline to the phl profile.
The other Mac retains its installation.

## Telegram CLI-only decision

GUI declarations removed from both active machine profiles.
Shannon app removal verified; both CLI tools retained.
PHL local app removal remains to be verified.
