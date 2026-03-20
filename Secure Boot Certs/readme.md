
This PowerShell script collects endpoint inventory data related to **Secure Boot readiness** and the **Windows UEFI CA 2023** certificate transition.

It outputs a single structured object containing:
- Device identity and platform info (computer name, manufacturer, model, firmware type, OS)
- Secure Boot state (`Confirm-SecureBootUEFI`)
- BitLocker protection status (when `Get-BitLockerVolume` is available)
- Secure Boot certificate presence indicators from UEFI variables (`KEK`, `dbdefault`, `db`)
- Servicing and eligibility signals from registry keys:
  - `HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot`
  - `HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`
- Latest relevant Windows event log entries for Secure Boot certificate processing (IDs **1801** and **1808**)

Use this script to quickly identify machines that are **ready**, **not ready**, or **reporting errors** for Secure Boot certificate updates June 2026 certificate rollover planning).
> Output is designed for easy export to CSV/JSON and ingestion into reporting (e.g., MECM/SCCM, log collection, dashboards).
