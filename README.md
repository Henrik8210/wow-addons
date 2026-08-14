# wow-addons

A workspace for World of Warcraft addon development.

## Quick start

1. Copy or symlink addon folders into:
   `%ProgramFiles(x86)%\World of Warcraft\_retail_\Interface\AddOns\`

2. Reload in game with `/reload`

3. The starter addon `HelloWoW` prints a message on login. Try `/hellowow`.

## Create a new addon

Copy `HelloWoW/`, rename the folder and files to match, then update the `.toc` metadata.

## Interface version

Update `## Interface:` in each `.toc` file when WoW patches. Check Blizzard default UI addons for the current number.
