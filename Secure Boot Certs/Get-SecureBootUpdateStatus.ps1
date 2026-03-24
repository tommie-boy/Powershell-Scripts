$result = $null
$computerInfo = Get-ComputerInfo | select-object BiosFirmwareType, CsManufacturer, CsModel, WindowsProductName
$secureBoot = if(confirm-securebootuefi -ea SilentlyContinue) { "Enabled" } else { "Disabled" } 
$bitlockerInfo = if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                    Get-BitLockerVolume -ErrorAction SilentlyContinue 
                } else { 
                   $null 
                }
$bitlockerActive = if($bitlockerInfo.ProtectionStatus -match 'On') { $true } else { $false } 
$kekCertificate = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI KEK).bytes)
$dbdefaultCertificate = if(-not($($computerInfo.CsManufacturer) -match 'Microsoft Corporation' -and $($computerInfo.CsModel) -match 'Virtual Machine')) { 
                            [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbdefault).bytes)
                        } else {
                            $null   # or "N/a"
                        }
$dbCertificate = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)

$regKey1 = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$regKey2 = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'

if(test-path $regKey1) {
    $secureBootUpdateAvailableRaw = (Get-ItemProperty $regKey1 -ErrorAction SilentlyContinue).AvailableUpdates
    $secureBootUpdateAvailable = if($secureBootUpdateAvailableRaw -eq 1) { $true } else { $false } 
} else {
    $secureBootUpdateAvailable = 'N/a'
}

if(test-path $regKey2) {
    $secureBootUpdateServicingRaw = get-itemproperty $regKey2 | select UEFICA2023Status, WindowsUEFICA2023Capable, UEFICA2023Error, UEFICA2023ErrorEvent  
    $secureBootUpdateServicingWindowsUEFICA2023Capable = if($secureBootUpdateServicingRaw.WindowsUEFICA2023Capable -eq 1) { $true } else { $false } 
    $secureBootUpdateServicingUEFICA2023Status = $secureBootUpdateServicingRaw.UEFICA2023Status
    $secureBootUpdateServicingUEFICA2023Error =  if($secureBootUpdateServicingRaw.UEFICA2023Error -eq 1) { $true } else { $false }
    $secureBootUpdateServicingUEFICA2023ErrorEvent = $secureBootUpdateServicingRaw.UEFICA2023ErrorEvent  
} else {
    $secureBootUpdateServicingWindowsUEFICA2023Capable = 'N/a'
    $secureBootUpdateServicingUEFICA2023Status = 'N/a'
    $secureBootUpdateServicingUEFICA2023Error = 'N/a'
    $secureBootUpdateServicingUEFICA2023ErrorEvent = 'N/a'
}

$allEventIds = @(1801,1808)
$events = @(Get-WinEvent -FilterHashtable @{LogName='System'; ID=$allEventIds} -MaxEvents 2000 -ErrorAction SilentlyContinue)
$latest_1801_Event = $events | Where-Object {$_.Id -eq 1801} | Sort-Object TimeCreated -Descending | Select-Object -First 1
$latest_1808_Event = $events | Where-Object {$_.Id -eq 1808} | Sort-Object TimeCreated -Descending | Select-Object -First 1

$kekUpdated = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI KEK).bytes)
$dbdefaultCertUpdated = if(-not($($computerInfo.CsManufacturer) -match 'Microsoft Corporation' -and $($computerInfo.CsModel) -match 'Virtual Machine')) { 
                            [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbdefault).bytes)
                        } else {
                            $null   # or "N/a"
                        }

$dbCertUpdated = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)


$result += 1 | select-object @{n='computerName';e={ "$($env:computername)" }}, `
                                @{n='Manufacturer';e={ "$($computerInfo.CsManufacturer)" }}, `
                                @{n='Model';e={ if($($computerInfo.CsManufacturer) -match 'Microsoft Corporation' -and $($computerInfo.CsModel) -match 'Virtual Machine') { 
                                                     if( "$($computerInfo.BiosFirmwareType)" -match 'uefi') {
                                                        "$($computerInfo.CsModel) (Gen2)" }
                                                     elseif("$($computerInfo.BiosFirmwareType)" -match 'bios') {
                                                        "$($computerInfo.CsModel) (Gen1)" }
                                                } else {
                                                    $($computerInfo.CsModel) } }}, `
                                @{n='biosConfiguration';e={ "$($computerInfo.BiosFirmwareType)" }}, `
                                @{n='secureboot';e={ "$secureBoot" }}, `
                                @{n='operatingSystem';e={ "$($computerInfo.WindowsProductName)" }}, 
                                @{n='bitlockerActive';e={ "$bitlockerActive" }}, `
                                @{n='SecureBootUpdateAvailable';e={ "$secureBootUpdateAvailable" }}, `
                                @{n='WindowsUEFICA2023Capable';e={ "$secureBootUpdateServicingWindowsUEFICA2023Capable" }}, `
                                @{n='UEFICA2023Status';e={ "$secureBootUpdateServicingUEFICA2023Status" }}, `
                                @{n='UEFICA2023Error';e={ "$secureBootUpdateServicingUEFICA2023Error" }}, `
                                @{n='UEFICA2023ErrorEvent';e={ "$secureBootUpdateServicingUEFICA2023ErrorEvent" }}, `
                                @{n='Event1801Time';e={ if($latest_1801_Event) { $($latest_1801_Event.TimeCreated) } else { "N/a" } }}, `
                                @{n='Event1801Status';e={ if($latest_1801_Event) { $latest_1801_Event.LevelDisplayName } else { "N/a" } }}, `
                                @{n='Secure Boot KEK Certificate';e={ if($kekUpdated -match 'Microsoft Corporation KEK 2K CA 2023') { 'Microsoft Corporation KEK 2K CA 2023' } elseif($kekUpdated -match 'Microsoft Corporation KEK CA 2011') { 'Microsoft Corporation KEK 2K CA 2011' } else { "N/a" } }}, `
                                @{n='Secure Boot DBDefault Cert PCA 2011';e={ if($dbdefaultCertUpdated -match 'Windows UEFI CA 2023') { 'Updated to Windows UEFI CA 2023' } elseif($dbdefaultCertUpdated -match 'Microsoft Windows Production PCA 2011') { 'Microsoft Windows Production PCA 2011' } else { "N/a" } }}, `
                                @{n='Secure Boot DBDefault Cert CA 2011';e={ if($dbdefaultCertUpdated -match 'Windows UEFI CA 2023') { 'Updated to Windows UEFI CA 2023' } elseif($dbdefaultCertUpdated -match 'Microsoft Corporation UEFI CA 2011') { 'Microsoft Corporation UEFI CA 2011' } else { "N/a" } }}, `
                                @{n='Secure Boot DB Cert PCA 2011';e={ if($dbCertUpdated -match 'Windows UEFI CA 2023') { 'Updated to Windows UEFI CA 2023' } elseif($dbCertUpdated -match 'Microsoft Windows Production PCA 2011') { 'Microsoft Windows Production PCA 2011' } else { "N/a" } }}, `
                                @{n='Secure Boot DB Cert CA 2011';e={ if($dbCertUpdated -match 'Windows UEFI CA 2023') { 'Updated to Windows UEFI CA 2023' } elseif($dbCertUpdated -match 'Microsoft Corporation UEFI CA 2011') { 'Microsoft Corporation UEFI CA 2011' } else { "N/a" } }}, `
                                @{n='Event1808Time';e={ if($latest_1808_Event) { $($latest_1808_Event.TimeCreated) } else { "N/a" } }}, `
                                @{n='Event1808Status';e={ if($latest_1808_Event) { $latest_1808_Event.LevelDisplayName } else { "N/a" } }}


$result
