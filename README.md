# XProtect Dashboard

En webbaserad dashboard för Milestone XProtect VMS med MilestonePSTools.

## Krav

- Windows Server med Milestone XProtect Management Server
- PowerShell 5.1 eller senare
- MilestonePSTools modul
- Python 3.8 eller senare

## Installation

### 1. Installera Python-beroenden

```powershell
cd C:\xprotect-dashboard
pip install -r requirements.txt
```

### 2. Installera MilestonePSTools

```powershell
Install-Module -Name MilestonePSTools -Force
```

### 3. Starta applikationen

```powershell
python app.py
```

### 4. Öppna i webbläsare

Gå till: http://localhost:5000

## Funktioner

### Dashboard
- Översikt över kameror, användare och systemstatus
- Snabbåtkomst till vanliga åtgärder

### Kamera-hantering
- Lista alla kameror
- Importera kameror från Excel/CSV
- Redigera kamerainställningar
- Kamera-rapport (PDF/HTML)

### Best Practice Audit
- Automatisk kontroll av säkerhetsinställningar
- Ackvisitionsfunktion för att ignorera kända problem
- Detaljerad rapport med åtgärdsförslag

### Användare och Roller
- Lista alla användare och deras roller
- Granska behörigheter
- Rapport över användaråtkomst

### Regler
- Lista alla automationsregler
- Aktivera/inaktivera regler
- Skapa nya regler

### Schemalagda Rapporter
- Ställ in automatiska rapporter
- Rapporter sparas som PDF/HTML

## Schemaläggning av rapporter

Använd Windows Task Scheduler för att köra rapporter automatiskt:

```powershell
# Exempel: Kör rapport varje dag kl 04:00
$action = New-ScheduledTaskAction -Execute "python" -Argument "C:\xprotect-dashboard\scripts\schedule_report.py daily"
$trigger = New-ScheduledTaskTrigger -Daily -At 04:00
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "XProtectDailyReport" -Description "Daglig XProtect-rapport"
```

## Ackvisitioner (Acknowledge)

För att ignorera specifika best practice-problem:
1. Gå till Best Practice Audit
2. Klicka på problemet
3. Lägg till kommentar och klicka "Ackvisera"
4. Problemet markeras som känt och visas inte längre

## Konfiguration

Alla konfigurationsfiler finns i `config.py`. Standardvärden fungerar för de flesta installationer.

## Säkerhet

- Applikationen bör endast köras lokalt eller via VPN
- Windows-brandväggen bör konfigureras för att blockera extern åtkomst
- Använd HTTPS om applikationen exponeras externt

## Licens

Apache 2.0
