PhET offline classroom kit
==========================
Downloads official PhET HTML5 simulations (single-file HTML) from phet.colorado.edu,
then writes index.html (a launcher page) and SHA256SUMS.txt. After that, the whole
folder runs offline in any modern browser and can be copied to USB sticks or lab PCs.

Windows 11 : powershell -NoProfile -ExecutionPolicy Bypass -File .\phet-offline-windows.ps1
Ubuntu 26.04: bash phet-offline-ubuntu.sh
macOS 27   : zsh phet-offline-macos.zsh

Options: --lang zh_CN | --sims a,b,c | --all | --out DIR | --open | --allow-stats
(PowerShell: -Lang -Sims -All -Out -Open -AllowStats)

Launcher links add ?yotta=false, PhET's own switch that turns off usage pings,
the tag-manager script and the update check. Use --allow-stats to keep them.

Simulations: PhET Interactive Simulations, University of Colorado Boulder,
licensed under CC BY-NC 4.0 (https://phet.colorado.edu). Non-commercial use only.
