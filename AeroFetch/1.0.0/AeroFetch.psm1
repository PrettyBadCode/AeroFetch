#region Configuration

$Global:AeroFetchConfiguration = Get-Content -Path "$PSScriptRoot\Data\Configuration\settings.json" | ConvertFrom-Json -Depth 100
$Global:AeroFetchUserSettings = $Global:AeroFetchConfiguration.UserSettings

#endregion



#region Functions

function Get-AeroFetchAssets {
    <#
        .SYNOPSIS
            Returns a list of ASCII Art Assets registered with AeroFetch.
    #>
    $AssetList = (Get-ChildItem -Path "$PSScriptRoot\Data\Assets" -File).BaseName

    return $AssetList
}


function Get-AeroFetchColorThemes {
    $ThemeList = (Get-ChildItem -Path "$PSScriptRoot\Data\ColorThemes\" -Directory).Name

    return $ThemeList
}


function Get-AeroFetchSettings {
    return $Global:AeroFetchUserSettings
}


function Set-AeroFetchSetting {
    param(
        [string]$DefaultAsciiArtLogo = $Global:AeroFetchUserSettings.DefaultAsciiArtLogo,
        [string]$DefaultColorTheme = $Global:AeroFetchUserSettings.DefaultColorTheme
    )

    $Global:AeroFetchUserSettings.DefaultAsciiArtLogo = $DefaultAsciiArtLogo
    $Global:AeroFetchUserSettings.DefaultColorTheme = $DefaultColorTheme

    $Global:AeroFetchConfiguration | ConvertTo-Json | Out-File -FilePath "$PSScriptRoot\Data\Configuration\settings.json" -Force 
}


function AeroFetch {
    <#
        .SYNOPSIS
            AeroFetch is the System Information Screenshot Utility, for Windows Operating Systems!

        .DESCRIPTION

    #>

    begin {

        [System.Console]::Clear()

        Write-Host "AeroFetch - Version 1.0.0"
        # Fetch System Information from CimInstances/Other Sources
        $SysQuery = [PSCustomObject]@{
            ComputerSystem  = Get-CimInstance Win32_ComputerSystem
            OperatingSystem = Get-CimInstance Win32_OperatingSystem 
            BaseBoard       = Get-CimInstance Win32_BaseBoard
            VideoController = Get-CimInstance Win32_VideoController
            CPU             = Get-CimInstance Win32_Processor 
            GPU             = Get-CimInstance Win32_DisplayConfiguration
            LogicalDisk     = Get-CimInstance Win32_LogicalDisk
            Network         = Get-NetConnectionProfile
            Battery         = Get-CimInstance Win32_Battery
            TImezone        = Get-CimInstance Win32_Timezone
        }

        [System.Console]::Clear()

        # Classes for modularizing and formatting data
        Class AFSystemUptime {
            [object]$LocalDateTime = $SysQuery.OperatingSystem.LocalDateTime
            [object]$LastBootUpTime = $SysQuery.OperatingSystem.LastBootUpTime

            SystemUptime() {}

            [string]GetUptime() {
                $UpTime = ($this.LocalDateTime - $this.LastBootUpTime)

                $UpTime = $UpTime.Days.ToString() + ' Days ' + $UpTime.Hours.ToString() + ' Hours ' + $UpTime.Minutes.ToString() + ' Minutes ' + $UpTime.Seconds.ToString() + ' Seconds'

                return $UpTime
            }
        }


        Class AFSystemRAM {
            [object]$AvailableRAM
            [object]$TotalRAM 
            
            AFSystemRAM() {}

            [string]GetRAMInfo() {
                $this.AvailableRAM = ([math]::Truncate((Get-CimInstance Win32_ComputerSystem).FreePhysicalMemory / 1KB))
                $this.TotalRAM = ([math]::Truncate((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB))
                $UsedRAM = $this.TotalRAM - $this.AvailableRAM
                $AvailableRAMPercent = ($this.AvailableRAM / $this.TotalRAM) * 100
                $AvailableRAMPercent = "{0:N0}" -f $AvailableRAMPercent
                $UsedRamPercent = ($UsedRam / $this.TotalRAM) * 100
                $UsedRamPercent = "{0:N0}" -f $UsedRamPercent
                $RAMInfo = $UsedRAM.ToString() + "MB / " + $this.TotalRAM.ToString() + " MB " + "(" + $UsedRamPercent.ToString() + "%" + ")"

                return $RamInfo
            }
        }

        Class AFDiskInfo {
            [object]$Disk = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$Env:SystemDrive'" -ErrorAction Stop | Select-Object Size, FreeSpace)

            AFDiskInfo() {}

            [string]GetDiskInfo() {
                $DiskTotal = [Math]::Round($this.Disk.Size / 1GB, 2)
                $DiskFree = [Math]::Round($this.Disk.FreeSpace / 1GB, 2)
                $DiskUsed = [Math]::Round($DiskTotal - $DiskFree, 2)
                $DiskPercent = [Math]::Round(($DiskUsed / $DiskTotal) * 100)

                $DiskInfo = "[$($Env:SystemDrive)\] $($DiskUsed)GB / $($DiskTotal)GB ($($DiskPercent)%)"

                return $DiskInfo
            }
        }

        Class AFBattery {
            [object]$Battery = $SysQuery.Battery

            AFBattery() {}

            [string]GetBatteryInfo() {
                $Charge = "$($this.Battery.EstimatedChargeRemaining)% Remaining"
                $Status = switch ($this.Battery.BatteryStatus) {
                    1 { "Discharging" }
                    2 { "AC Power" }
                    3 { "Fully Charged" }
                    4 { "Low" }
                    5 { "Critical" }
                    6 { "Charging" }
                    7 { "Charging and High" }
                    8 { "Charging and Low" }
                    9 { "Charging and Critical" }
                    10 { "Undefined" }
                    11 { "Partially Charged" }
                    default { "Unknown" }
                }

                if ($this.Battery) {
                    $BatteryInfo = "$Charge [Status: $Status]"
                }
                else {
                    $BatteryInfo = "No Battery Detected."
                }

                return $BatteryInfo
            }
        }

        Class AFNetwork {
            $Network = $SysQuery.Network

            AFNetwork(){}

            [string]GetNetworkStatusInfo(){
                if ($null -eq $this.Network.Name)
                {
                    $NetworkInfo = "OFFLINE"
                } else {
                    $NetworkInfo = "$($this.Network.Name) | [$($this.Network.NetworkCategory) $($this.Network.InterfaceAlias)]"
                }
                return $NetworkInfo
            }
        }

        # Finally, collect all information into a single, dedicated PSCustomObject
        $AeroFetchInfo = [PSCustomObject]@{
         
            User                 = "$($Env:USERNAME)\$($Env:USERDOMAIN) - $($SysQuery.ComputerSystem.Workgroup)"
            OS                   = "$($SysQuery.OperatingSystem.Caption) ($($SysQuery.OperatingSystem.OSArchitecture))"
            Kernel               = (Get-ItemProperty -Path "$($Env:SystemRoot)\System32\ntoskrnl.exe").VersionInfo.FileVersion
            SystemUptime         = [AFSystemUptime]::new().GetUptime()
            BaseBoard            = "$($SysQuery.BaseBoard.Manufacturer) $($SysQuery.BaseBoard.Product)"
            PowerShellVersion    = "Microsoft PowerShell | Version $($PSVersionTable.PSVersion.ToString()) | $($Host.Name)"
            WindowManager        = 'Windows Explorer (explorer.exe)'
            DisplayResolution    = $SysQuery.VideoController.CurrentHorizontalResolution.ToString() + " x " + $SysQuery.VideoController.CurrentVerticalResolution.ToString() + " (" + $SysQuery.   VideoController.CurrentRefreshRate.ToString() + "Hz)"
            CPU                  = $SysQuery.CPU.Name
            GPU                  = $SysQuery.GPU.DeviceName
            ActiveProcessCounter = $(Get-Process).Count
            MemoryStatus         = [AFSystemRAM]::new()
            StorageStatus        = [AFDiskInfo]::new().GetDiskInfo()
            NetworkStatus        = [AFNetwork]::new().GetNetworkStatusInfo()
            BatteryStatus        = [AFBattery]::new().GetBatteryInfo() 
            TimezoneInfo         = $(Get-CimInstance Win32_Timezone).Caption
        }
    }

    process {
        # Final formatting for System Information text strings
        $ColorThemeName = $Global:AeroFetchUserSettings.DefaultColorTheme

        $ColorTheme = Import-PowerShellDataFile -Path "$PSScriptRoot\Data\ColorThemes\$ColorThemeName\$ColorThemeName`Color.psd1"

        $ColorTheme = $ColorTheme.ThemeData

        $InfoCaption = @(
            "$($ColorTheme.UserInfoColor)$($ColorTheme.UserInfoFormat)   $($AeroFetchInfo.User)$($ColorTheme.Reset)",
            "$($ColorTheme.SystemInfoCaptionColor) OS:$($ColorTheme.Reset)$($ColorTheme.SystemInfoTextColor) $($AeroFetchInfo.OS)",
            "$($ColorTheme.SystemInfoCaptionColor) Kernel:$($ColorTheme.Reset)$($ColorTheme.SystemInfoTextColor) $($AeroFetchInfo.Kernel)",
            "$($ColorTheme.SystemInfoCaptionColor) System Uptime:$($ColorTheme.Reset)$($ColorTheme.SystemInfoTextColor) $($AeroFetchInfo.SystemUptime)",
            "$($ColorTheme.SystemInfoCaptionColor) System TimeZone:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.TimezoneInfo)$($ColorTheme.Reset)",
            "$($ColorTheme.SystemInfoCaptionColor) Motherboard:$($ColorTheme.Reset)$($ColorTheme.SystemInfoTextColor) $($AeroFetchInfo.BaseBoard)",
            "$($ColorTheme.SystemInfoCaptionColor) Shell:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.PowerShellVersion)",
            "$($ColorTheme.SystemInfoCaptionColor) Window Manager:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)explorer.exe",
            "$($ColorTheme.SystemInfoCaptionColor) Display:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.DisplayResolution)",
            "$($ColorTheme.SystemInfoCaptionColor) CPU:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.CPU)",
            "$($ColorTheme.SystemInfoCaptionColor) GPU:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.GPU)",
            "$($ColorTheme.SystemInfoCaptionColor) Processes:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.ActiveProcessCounter)",
            "$($ColorTheme.SystemInfoCaptionColor) Memory:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.MemoryStatus.GetRAMInfo())",
            "$($ColorTheme.SystemInfoCaptionColor) Drive:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.StorageStatus)",
            "$($ColorTheme.SystemInfoCaptionColor) Network:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.NetworkStatus)",
            "$($ColorTheme.SystemInfoCaptionColor) Battery:$($ColorTheme.Reset) $($ColorTheme.SystemInfoTextColor)$($AeroFetchInfo.BatteryStatus)$($ColorTheme.Reset)"
        )

        

        # Locate current Logo Setting
        $LogoName = "$($Global:AeroFetchUserSettings.DefaultAsciiArtLogo)"
        # Get RAW contents of Ascii Art Resource File
        $Logo = Get-Content "$PSScriptRoot\Data\Assets\$LogoName.af" -Raw
        
        $Info = $InfoCaption
        # Use string formatting to format and render the Logo and Information
        $Logo -f $ColorTheme.Reset, $ColorTheme.LogoColor0, $ColorTheme.LogoColor1, $ColorTheme.LogoColor2, $ColorTheme.LogoColor3, $Info[0], $Info[1], $Info[2], $Info[3], $Info[4], $Info[5], $Info[6], $Info[7], $Info[8], $Info[9], $Info[10], $Info[11], $Info[12], $Info[13], $Info[14], $Info[15], $Info[16]
    }
}


#endregion