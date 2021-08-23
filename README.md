# srcds-watchdog
Powershell watchdog script for SRCDS

## Features
Easy to use config file with options for hostname, max players, workshop collection, default map, server port and server thread usage

Assigns high CPU affinity

Automatic detection and reboot of most types of server freeze/crash

Automatic update of git addons before server reboot

## How to use
1. Move watchdog.ps1 to the same directory as srcds.exe
2. Configure watchdog_config.cfg
3. Run watchdog.ps1
