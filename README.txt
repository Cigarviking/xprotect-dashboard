============================================
XProtect Dashboard
Offline Installation Guide
============================================

FORBEREDELSE (pa uppkopplad dator)
============================================

1. Kopiera denna mapp till en dator med internet

2. Oppna PowerShell som administrator och kor:
   .\prepare-offline.ps1

3. Zippa paketet:
   Compress-Archive -Path ".\xprotect-dashboard-package" -DestinationPath ".\xprotect-dashboard.zip"

4. Kopiera zip-filen till servern


INSTALLATION PA SERVER (offline)
============================================

1. Packa upp zip-filen:
   Expand-Archive -Path "xprotect-dashboard.zip" -DestinationPath "C:\xprotect-dashboard"

2. Installera MilestonePSTools (om inte redan installerat):
   Install-Module -Name MilestonePSTools -Force

   OBS: Detta kraver internet. Om servern ar helt offline,
   kan du kopiera modulen manuellt fra en annan server:
   Copy-Item -Path "C:\Program Files\WindowsPowerShell\Modules\MilestonePSTools" -Destination "C:\Program Files\WindowsPowerShell\Modules\" -Recurse

3. Starta applikationen:
   cd C:\xprotect-dashboard\xprotect-dashboard-package
   .\START.bat

4. Oppna webblasare och ga till:
   http://localhost:5000


SCHEMALAGGNING AV RAPPORTER
============================================

Anvand Windows Task Scheduler for att automatiskt generera rapporter:

1. Oppna Task Scheduler (schtasks.msc)

2. Skapa ny uppgift med foljande inställningar:
   - Namn: XProtectDailyReport
   - Trigger: Dagligen kl 04:00
   - Atgard: powershell.exe
   - Argument: -ExecutionPolicy Bypass -File "C:\xprotect-dashboard\xprotect-dashboard-package\app\scripts\schedule_report.py daily"

Exempel via PowerShell:
schtasks /create /tn "XProtectDailyReport" /tr "powershell -ExecutionPolicy Bypass -File \"C:\xprotect-dashboard\xprotect-dashboard-package\app\scripts\schedule_report.py\" daily" /sc daily /st 04:00


KRAV
============================================

- Windows Server med Milestone XProtect VMS
- MilestonePSTools modul installerad
- PowerShell 5.1 eller senare
- Webblasare (Chrome, Firefox, Edge)


FUNKTIONER
============================================

1. OVERSIKT
   - Dashboard med statistik over kameror, anvandare och regler
   - Snabbaccess till vanliga atgarder

2. KAMEROR
   - Lista alla kameror med status
   - Importera kameror fra Excel/CSV
   - Kamera-rapport (PDF/HTML)

3. BEST PRACTICE AUDIT
   - Automatisk kontroll av 15+ saakerhetsregler:
     * Firmware-versioner
     * Kamera-status (online/offline)
     * Inspelningsstatus
     * Krypterade streams
     * Lagringsutrymme
     * Licensstatus
     * MFA-krav
     * Och mer...
   - Ackvisitionsfunktion for kanda problem
   - Detaljerad rapport med atgardsforslag

4. ANVANDARE OCH ROLLER
   - Lista alla anvandare och deras roller
   - Granska behörigheter
   - Rapport over anvandaratkomst

5. REGLER
   - Lista alla automationsregler
   - Aktivera/inaktivera regler
   - Oversikt av trigger och atgardstyper

6. RAPPORTER
   - Generera rapporter pa begaran (PDF/HTML)
   - Schemalagda rapporter via Windows Task Scheduler
   - Sparade rapporter for nedladdning


FELSOKNING
============================================

Problem: "MilestonePSTools kunde inte hittas"
Losning: Kör Install-Module -Name MilestonePSTools -Force

Problem: "localhost:5000 fungerar inte"
Losning: Kontrollera att applikationen kor
         Prova http://127.0.0.1:5000 istallet

Problem: "Ingen data visas"
Losning: Kontrollera att Milestone XProtect tjant kor
         Kontrollera att du har atkomst till servern

Problem: "Import av Excel misslyckas"
Losning: Se till att ImportExcel-modulen ar installerad:
         Install-Module -Name ImportExcel -Force


KONTAKT OCH SUPPORT
============================================

MilestonePSTools: https://www.milestonepstools.com/
PowerShell Gallery: https://www.powershellgallery.com/packages/MilestonePSTools/

============================================
