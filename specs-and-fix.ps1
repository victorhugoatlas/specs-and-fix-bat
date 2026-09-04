$ErrorActionPreference = "SilentlyContinue"

function Get-SpecsEye {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $board = Get-CimInstance Win32_BaseBoard
    $chipset = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match "Chipset|LPC Controller" } | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    
    $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq "0" }
    $diskType = $physicalDisk.BusType 
    $mediaType = $physicalDisk.MediaType 
    $diskModel = $physicalDisk.FriendlyName
    $diskSize = [math]::Round($physicalDisk.Size / 1GB)

    try {
        $storageStatus = Get-StorageReliabilityCounter -PhysicalDisk $physicalDisk -ErrorAction SilentlyContinue
        if ($storageStatus -and $storageStatus.Wear -ne $null) {
            $health = "$(100 - $storageStatus.Wear)%"
        } else { $health = $physicalDisk.HealthStatus }
    } catch { $health = "N/A" }

    $ramSlots = Get-CimInstance Win32_PhysicalMemory
    $ramTotal = [math]::Round(($ramSlots | Measure-Object Capacity -Sum).Sum / 1GB)
    $ramDetails = ($ramSlots | ForEach-Object { "1 x $([math]::Round($_.Capacity / 1GB))GB $($_.Speed)MHz" }) -join " + "
    
    $chassis = Get-CimInstance Win32_SystemEnclosure
    $type = if ($chassis.ChassisTypes -contains 9 -or $chassis.ChassisTypes -contains 10) { "NOTEBOOK" } else { "DESKTOP" }

    return [PSCustomObject]@{
        OS = $os.Caption; CPU = $cpu.Name; Board = $board.Product; Chipset = $chipset.Name
        RAM = $ramTotal; RAMDet = $ramDetails; Disk = "$diskType $mediaType $diskModel ($diskSize GB)"
        Health = $health; GPU = ($gpu -join ' / '); Type = $type
    }
}

function Invoke-Limpeza {
    Write-Host "`n[>>>] MODULO 1: LIMPEZA DE TEMPORARIOS" -ForegroundColor Yellow
    $paths = @(
        "C:\Windows\Temp\*", "$env:TEMP\*", "C:\Windows\Prefetch\*",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
        "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
    )
    foreach ($path in $paths) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Limpeza concluída com sucesso!" -ForegroundColor Green
}

function Invoke-Reparo {
    Write-Host "`n[>>>] MODULO 2: REPARO DO SISTEMA" -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth
    sfc /scannow
    Write-Host "[+] Rotinas de reparo finalizadas!" -ForegroundColor Green
}

$specs = Get-SpecsEye
$report = @"
==========================================================
HOSTNAME               | $($env:COMPUTERNAME)
SISTEMA OPERACIONAL    | $($specs.OS)
PROCESSADOR            | $($specs.CPU)
PLACA-MAE / CHIPSET    | $($specs.Board) / $($specs.Chipset)
RAM TOTAL              | $($specs.RAM)GB ($($specs.RAMDet))
DISCO E SAUDE          | $($specs.Disk) - SAUDE: $($specs.Health)
PLACA DE VIDEO         | $($specs.GPU)
TIPO                   | $($specs.Type)
==========================================================
"@

$filename = "SPECS_AND_FIX_$($env:COMPUTERNAME).txt"
$report | Out-File -FilePath "$PSScriptRoot\$filename" -Encoding utf8

do {
    Clear-Host
    Write-Host $report -ForegroundColor Cyan
    Write-Host "        MENU DE MANUTENCAO - BY VICTOR HUGO" -ForegroundColor Yellow
    Write-Host "=========================================================="
    Write-Host "[1] Limpeza de Temporarios"
    Write-Host "[2] Reparo do Sistema (DISM + SFC)"
    Write-Host "[3] Executar Tudo (Limpeza + Reparo)"
    Write-Host "[0] Sair"
    Write-Host "=========================================================="
    
    $opt = Read-Host "Digite a opcao"

    switch ($opt) {
        "1" { 
            Invoke-Limpeza 
            Pause 
        }
        "2" { 
            Invoke-Reparo 
            Pause 
        }
        "3" { 
            Invoke-Limpeza 
            Invoke-Reparo 
            Pause 
        }
        "0" { 
            Write-Host "Saindo... Relatório salvo em: $filename" -ForegroundColor Magenta
            exit 
        }
        default { 
            Write-Host "Opção inválida!" -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
} while ($true)