#region load config
    if ( (Test-Path ".\watchdog_config.cfg") -ne $True ) {
        Write-Host -ForegroundColor Yellow "watchdog_config.cfg missing! Loading defaults"

        $Text = 
@"
[SRCDS]
Hostname   = "Garrysmod Server"
MaxPlayers = 10
Workshop   = 0
Map        = "gm_construct"
Port       = 27015
Threads    = 1,2

[Watchdog]
Timeout    = 3
Heartbeat  = 5
"@

        New-Item -Path . -Name "watchdog_config.cfg" -Value $Text
    }

    foreach ( $Line in Get-Content ".\watchdog_config.cfg" ) {
        $k = [regex]::split($Line, '=')
            
        if ( ( $k[0].CompareTo("") -ne 0) -and ( $k[0].StartsWith("[") -ne $True ) ) {          
            $k[0] = $k[0].Trim()
            $k[1] = $k[1].Trim()

            if ( $k[0] -eq "Threads") {
                Set-Variable -Name "Threads" -Value ($k[1] -split ",") -Visibility Public -Scope Script
            }
            else {
                Set-Variable -Name ($k[0]).Trim() -Value ($k[1]).Trim() -Visibility Public -Scope Script
            }
        }
    }
#endregion

#region calculate processor affinity
    [int]$Affinity    = 0 
    [int]$MaxThreads  = 0; gwmi -class win32_processor | foreach { $MaxThreads += $_.NumberOfLogicalProcessors} 
    [int]$MaxAffinity = [math]::pow(2, $MaxThreads-1)

    for ( $I = 0; $I -lt $Threads.Count; $I++) { $Affinity = $Affinity + [math]::Pow(2, $Threads[$I]-1) }
        
    if ( ($Affinity -gt $MaxAffinity) -or ($Affinity -lt 1) ) { $Affinity = $MaxAffinity }

    function Write-Prefix {
        $Str = "[" + (Get-Date)  + "] "
        $Str = $Str.PadRight(22, " ")

        Write-Host -NoNewline $Str
    }
    function Reset-Process {
        #region Terminate process        
            if ( $ExecID -and (Get-Process -Id $ExecID -ErrorAction SilentlyContinue) ) {
                Write-Prefix
                Write-Host -Nonewline "Terminating process. . ."
                
                Stop-Process -Id $ExecID -Force

                Write-Host -ForegroundColor Green " Done"
            }
        #endregion

        #region Update addons
            Write-Prefix
            Write-Host -Nonewline "Updating addons. . ."

            foreach ( $Dir in Get-ChildItem -Directory "$PSScriptRoot\garrysmod\addons" ) {
                if ( Test-Path "$PSScriptRoot\garrysmod\addons\$Dir\.github" ) {
                    Set-Location "$PSScriptRoot\garrysmod\addons\$Dir"
                    git pull --quiet *> $null
                }
            }

            Set-Location $PSScriptRoot

            Write-Host -ForegroundColor Green " Done"
        #endregion

        #region Start new process
            Write-Prefix
            Write-Host -NoNewline "Starting SRCDS. . ."

            $script:Exec   = Start-Process -FilePath "$PSScriptRoot\srcds.exe" -ArgumentList "-port $Port +ip $IP -console +hostname `"$Hostname`" +maxplayers $MaxPlayers +host_workshop_collection $Workshop +gamemode sandbox +map $Map" -PassThru
            $script:ExecID = $Exec.Id
            
            $Exec.PriorityClass     = 'High'
            $Exec.ProcessorAffinity = $Affinity

            Write-Host -ForegroundColor Green " Done"
        #endregion
    }
#endregion

#region main
    try {
        Write-Host -ForegroundColor Green "------- $Hostname -------"
        Write-Host -ForegroundColor Green "> Path   : $PSScriptRoot"
        Write-Host -ForegroundColor Green "> IP     : $IP`:$Port"
        Write-Host -ForegroundColor Green "> Threads: $Threads"
        Write-Host -ForegroundColor Green ("-" * ($Hostname.Length + 16))
        Write-Host
        
        Reset-Process

        for ( ;; ) {
            if ( -not $Exec.Id ) { Reset-Process }
            elseif ( -not $Exec.Responding ) {
                Write-Prefix
                Write-Host -ForegroundColor Yellow -Nonewline "Server not responding. . ."

                Start-Sleep $Timeout

                if ( -not $Exec.Responding ) {
                    Write-Host -ForegroundColor Red " Timeout!"
                    Reset-Process
                }
                else {
                    Write-Host -ForegroundColor Green " Resumed."
                }
            }

            Start-Sleep $Heartbeat
        }
    }
    catch {
        $_

        Start-Sleep -Seconds 9999
    }
    finally {
        Write-Prefix
        Write-Host -ForegroundColor Red "Script halted!"
    }
#endregion