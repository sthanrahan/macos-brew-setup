# macos-brew-setup

Canonical repository: git@github.com:sthanrahan/macos-brew-setup.git
Canonical clone: ~/.dotfiles on both managed Macs. Branch: main.

## Alignment

The root Brewfile loads brew/Brewfile.common plus Brewfile.shannon or
Brewfile.phl according to ComputerName. Unknown machines require
MAC_ENV_PROFILE=shannon or MAC_ENV_PROFILE=phl explicitly.
Alignment and reproducibility are the goals; identical inventories are not.

Profiles preserve the reviewed top-level software and role differences.
Dependencies are otherwise resolved by Homebrew. Shannon uses NVM Node;
PHL uses Homebrew Node. The active FFmpeg declaration uses the verified Homebrew core source. Historical custom FFmpeg options remain in the legacy reference.

Aptos, Roboto and Roboto Flex belong to the shared font baseline.
Plain Envy Code R and JetBrains Mono Nerd Font remain PHL-specific.
App Store IDs are retained as reported. The two Shannon Pages IDs remain
distinct pending a specific review.

## Verify and restore

Check installed state:
    brew bundle check --no-upgrade --verbose --file="$HOME/.dotfiles/Brewfile"

For an authorised restoration:
    brew bundle install --no-upgrade --file="$HOME/.dotfiles/Brewfile"

On a replacement personal Mac:
    MAC_ENV_PROFILE=shannon brew bundle install --no-upgrade --file="$HOME/.dotfiles/Brewfile"

No-upgrade avoids blanket upgrades; installations can still update required
dependencies. Profiles record intent, not pinned versions. Fresh-machine
restoration and all third-party tap discovery have not been tested.

## npm and shell

npm-global.txt records the shared npm tool outside Homebrew Bundle.
After the appropriate Node environment is active:
    npm install --global @pnp/cli-microsoft365

This avoids introducing Homebrew Node through Bundle on Shannon.
npm package versions may remain different.

Shared shell files remain under shell/. Preserve shellsync safeguards.
Use shellsync status, pull and push for shell work.
For Brewfile-only updates, use git pull --ff-only.

## Maintenance and retained references

Do not use bundle cleanup to enforce parity or overwrite profiles with
brew bundle dump --force.

brew/Brewfile.legacy-20261001 retains the previous Brewfile.
Code2002 is retired. Ark Pixel 16px and ChatGPT Atlas were absent from both
reported cask inventories and are excluded from active profiles.
Historical explicit dependency entries remain available in the legacy file.

The 12 named shared fonts refreshed successfully on both Macs on
1 October 2026. Persistent greedy latest-to-latest reports remain a
verification limitation; do not repeat successful refreshes solely for this.

Shannon's ~/Projects/macos-brew-setup clone remains non-canonical.
Retain it until a separate review authorises archival or removal.
Private SSH keys never belong in this repository.

## Shannon FFmpeg workflow

Standard Homebrew ffmpeg remains the default.
Shannon retains ffmpeg@7 for subtitle burn-in and text rendering.
Invoke /opt/homebrew/opt/ffmpeg@7/bin/ffmpeg directly when needed;
no global unlinking or relinking is required.
