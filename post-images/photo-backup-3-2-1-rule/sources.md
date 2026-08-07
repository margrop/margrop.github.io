# Photo backup article sources and evidence

Accessed July 29, 2026. Links below are public references; screenshots in the article are sanitized local experiment outputs, not copies of private systems.

- Backblaze, “The 3-2-1 Backup Strategy”: https://www.backblaze.com/blog/the-3-2-1-backup-strategy/
- Veeam, “The 3-2-1-1-0 Backup Rule”: https://www.veeam.com/blog/321-backup-rule.html
- CISA, “StopRansomware Guide”: https://www.cisa.gov/stopransomware/ransomware-guide
- PhotoPrism documentation, “Backups”: https://docs.photoprism.app/user-guide/backups/
- SiYuan official project: https://github.com/siyuan-note/siyuan
- Microsoft Learn, `robocopy`: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy
- Microsoft Learn, `Get-FileHash`: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash
- Apple Support, “Back up your Mac with Time Machine”: https://support.apple.com/en-us/104984

## Local evidence

- Source corpus: six synthetic JPEGs and one text file.
- Copy method: native `rsync` for the experiment, with dated target directories.
- Integrity method: SHA-256 manifest and verification.
- Fault injection: append test bytes to one copied JPEG.
- Recovery: restore the damaged JPEG from the offsite simulation and rerun the manifest check.
