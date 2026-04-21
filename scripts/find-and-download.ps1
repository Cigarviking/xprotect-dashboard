# scripts/find-and-download.ps1
# Kör från repo-roten: .\scripts\find-and-download.ps1
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $repoRoot

# Skapa mappar
$dirs = @("static\css","static\js","static\fonts","static\vendor","static\img","scripts")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# Sök efter externa URL:er
Write-Host "Söker efter externa URL:er i repo..."
$patterns = "https?://"
$files = Get-ChildItem -Recurse -File -Exclude *.png,*.jpg,*.jpeg,*.gif,*.woff,*.woff2,*.ttf
$matches = @()
foreach ($f in $files) {
  $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
  if ($content -match $patterns) {
    $lines = Select-String -Path $f.FullName -Pattern "https?://" -AllMatches
    foreach ($m in $lines) {
      $matches += [PSCustomObject]@{ File = $f.FullName; Line = $m.LineNumber; Text = $m.Line }
    }
  }
}
if ($matches.Count -eq 0) {
  Write-Host "Inga externa URL:er hittades."
} else {
  Write-Host "Externa URL:er hittade (fil, rad, utdrag):"
  $matches | Format-Table -AutoSize
  $matches | Out-File -FilePath scripts\external-urls.txt -Encoding utf8
  Write-Host "Lista sparad i scripts\external-urls.txt"
}

# Vanliga bibliotek att ladda ner (lägg till/ta bort efter behov)
$downloadList = @(
  @{ url="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css"; out="static/css/bootstrap.min.css" },
  @{ url="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"; out="static/js/bootstrap.bundle.min.js" },
  @{ url="https://code.jquery.com/jquery-3.6.0.min.js"; out="static/js/jquery.min.js" },
  @{ url="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"; out="static/css/fontawesome.min.css" },
  @{ url="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap"; out="static/css/googlefonts-inter.css" }
)

Write-Host "`nFörsöker ladda ner vanliga bibliotek/fonter..."
foreach ($item in $downloadList) {
  $url = $item.url
  $out = $item.out
  try {
    Write-Host "Laddar ner $url -> $out"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Warning "Misslyckades att ladda ner $url. Kontrollera manuellt."
  }
}

Write-Host "`nKlar. Kontrollera static/ för nedladdade filer."
Write-Host "OBS: Google Fonts CSS som laddas ner innehåller referenser till fonts.gstatic.com. Du måste ladda ner fontfilerna separat och uppdatera paths i css."

