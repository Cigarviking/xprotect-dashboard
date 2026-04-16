# ============================================================
# XProtect Dashboard - Offline Preparation Script
# Kor denna PA EN UPPKOPPLAD DATOR
# Allt paketeras sa det fungerar helt offline
# ============================================================

param(
    [string]$OutputPath = ".\xprotect-dashboard-package"
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  XProtect Dashboard - Offline Preparation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# STEG 1: Skapa mappstruktur
Write-Host "[1/6] Skapar mappstruktur..." -ForegroundColor Yellow
$folders = @(
    "$OutputPath",
    "$OutputPath\python",
    "$OutputPath\packages",
    "$OutputPath\app",
    "$OutputPath\app\scripts",
    "$OutputPath\app\templates",
    "$OutputPath\app\static",
    "$OutputPath\app\data",
    "$OutputPath\app\reports"
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}
Write-Host "   Klart!" -ForegroundColor Green

# STEG 2: Ladda ner Python
Write-Host "[2/6] Laddar ner Python 3.12..." -ForegroundColor Yellow
$pythonUrl = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip"
$pythonZip = "$env:TEMP\python-embed.zip"

Write-Host "   Laddar..." -ForegroundColor Gray
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing

Write-Host "   Extraherar..." -ForegroundColor Gray
Expand-Archive -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
Remove-Item $pythonZip

# Aktivera site-packages i python312._pth
$pythFile = "$OutputPath\python\python312._pth"
if (Test-Path $pythFile) {
    $content = Get-Content $pythFile
    $newContent = $content -replace "#import site", "import site"
    $newContent = $newContent -replace "#import site-packages", "import site-packages"
    Set-Content -Path $pythFile -Value $newContent
}
Write-Host "   Klart!" -ForegroundColor Green

# STEG 3: Installera pip
Write-Host "[3/6] Installerar pip..." -ForegroundColor Yellow
$pipUrl = "https://bootstrap.pypa.io/get-pip.py"
$pipScript = "$env:TEMP\get-pip.py"
Invoke-WebRequest -Uri $pipUrl -OutFile $pipScript -UseBasicParsing

$pythonExe = "$OutputPath\python\python.exe"
Write-Host "   Installerar..." -ForegroundColor Gray
Start-Process -FilePath $pythonExe -ArgumentList $pipScript -Wait -NoNewWindow -RedirectStandardOutput "$env:TEMP\pip_out.txt" -RedirectStandardError "$env:TEMP\pip_err.txt"
Remove-Item $pipScript -ErrorAction SilentlyContinue
Write-Host "   Klart!" -ForegroundColor Green

# STEG 4: Ladda ner OCH installera paket (med offline-kopior)
Write-Host "[4/6] Laddar ner Python-paket..." -ForegroundColor Yellow

$packages = @(
    "flask==3.0.0",
    "reportlab==4.0.7",
    "jinja2==3.1.2",
    "markupsafe==2.1.3",
    "werkzeug==3.0.1",
    "itsdangerous==2.1.2",
    "pyyaml==6.0.1",
    "Pillow==10.1.0",
    "click==8.1.7"
)

# Ladda ner paketen till local mapp
$pipExe = "$OutputPath\python\Scripts\pip.exe"
Write-Host "   Laddar ner till packages-mapp..." -ForegroundColor Gray
$pkgList = $packages -join " "
Start-Process -FilePath $pipExe -ArgumentList "download $pkgList -d $OutputPath\packages" -Wait -NoNewWindow -RedirectStandardOutput "$env:TEMP\pip_dl.txt" -RedirectStandardError "$env:TEMP\pip_dl_err.txt"

# Installera fran lokala kopior (ingen internet kravs)
Write-Host "   Installerar fran lokala filer..." -ForegroundColor Gray
Start-Process -FilePath $pipExe -ArgumentList "install $pkgList --no-index --find-links=$OutputPath\packages" -Wait -NoNewWindow -RedirectStandardOutput "$env:TEMP\pip_inst.txt" -RedirectStandardError "$env:TEMP\pip_inst_err.txt"

Write-Host "   Klart!" -ForegroundColor Green

# STEG 5: Kopiera appfiler
Write-Host "[5/6] Kopierar applikationsfiler..." -ForegroundColor Yellow
$sourcePath = $PSScriptRoot

# PowerShell scripts
$scriptFiles = @("get_status.ps1", "get_cameras.ps1", "get_users.ps1", "get_rules.ps1", "audit.ps1", "import_cameras.ps1", "toggle_rule.ps1", "schedule_report.py")
foreach ($file in $scriptFiles) {
    $src = Join-Path $sourcePath "scripts\$file"
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination "$OutputPath\app\scripts\" -Force
    }
}

# HTML templates
$templateFiles = @("base.html", "dashboard.html", "cameras.html", "import_cameras.html", "audit.html", "users.html", "rules.html", "reports.html")
foreach ($file in $templateFiles) {
    $src = Join-Path $sourcePath "templates\$file"
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination "$OutputPath\app\templates\" -Force
    }
}

# Static CSS
$srcCss = Join-Path $sourcePath "static\style.css"
if (Test-Path $srcCss) {
    Copy-Item -Path $srcCss -Destination "$OutputPath\app\static\" -Force
}

# Skapa config.py
$configContent = @'
import os

class Config:
    SECRET_KEY = "xprotect-dashboard-secret-key-2024"
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DATA_DIR = os.path.join(BASE_DIR, "data")
    REPORTS_DIR = os.path.join(BASE_DIR, "reports")
    SCRIPTS_DIR = os.path.join(BASE_DIR, "scripts")
    DATABASE = os.path.join(DATA_DIR, "audit.db")
    POWERSHELL_PATH = "powershell.exe"
    ALLOWED_EXTENSIONS = {"xlsx", "xls", "csv"}
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024
'@
Set-Content -Path "$OutputPath\app\config.py" -Value $configContent -Encoding UTF8

# Skapa report_generator.py
$reportGen = @'
import os
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.enums import TA_CENTER

def generate_pdf_report(data, filepath, title):
    doc = SimpleDocTemplate(filepath, pagesize=A4, rightMargin=20*mm, leftMargin=20*mm, topMargin=20*mm, bottomMargin=20*mm)
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="CustomTitle", parent=styles["Heading1"], fontSize=24, spaceAfter=30, alignment=TA_CENTER, textColor=colors.HexColor("#003d6e")))
    styles.add(ParagraphStyle(name="CustomSubtitle", parent=styles["Normal"], fontSize=10, textColor=colors.gray, alignment=TA_CENTER, spaceAfter=20))
    styles.add(ParagraphStyle(name="SectionHeader", parent=styles["Heading2"], fontSize=14, spaceBefore=20, spaceAfter=10, textColor=colors.HexColor("#003d6e")))
    story = []
    story.append(Paragraph(title, styles["CustomTitle"]))
    story.append(Paragraph("Genererad: " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"), styles["CustomSubtitle"]))
    story.append(Spacer(1, 10))
    if isinstance(data, dict) and "users" in data:
        data = data["users"]
    if isinstance(data, list) and len(data) > 0:
        first_item = data[0]
        if "name" in first_item and "hardware_name" in first_item:
            story.append(Paragraph("Kameror", styles["SectionHeader"]))
            table_data = [["Namn", "IP-adress", "Status", "Inspelning"]]
            for item in data:
                status = "Online" if item.get("is_connected", False) else "Offline"
                recording = "Ja" if item.get("is_recording", False) else "Nej"
                table_data.append([item.get("name", ""), item.get("ip_address", ""), status, recording])
            table = Table(table_data, colWidths=[60*mm, 40*mm, 30*mm, 25*mm])
            table.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#003d6e")), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white), ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 9), ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#c1c7d2")), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f1f4f6")])]))
            story.append(table)
        elif "rule_name" in first_item:
            story.append(Paragraph("Best Practice Audit Resultat", styles["SectionHeader"]))
            table_data = [["Regel", "Enhet", "Severity"]]
            for item in data:
                table_data.append([item.get("rule_name", "")[:40], item.get("device_name", "")[:25], item.get("severity", "")])
            table = Table(table_data, colWidths=[60*mm, 50*mm, 25*mm])
            table.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#003d6e")), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white), ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 9), ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#c1c7d2")), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f1f4f6")])]))
            story.append(table)
        elif "roles" in first_item or "email" in first_item:
            story.append(Paragraph("Anvandare och Roller", styles["SectionHeader"]))
            table_data = [["Anvandare", "E-post", "Status"]]
            for item in data:
                status = "Aktiv" if item.get("is_enabled", True) else "Inaktiv"
                table_data.append([item.get("name", ""), item.get("email", ""), status])
            table = Table(table_data, colWidths=[50*mm, 60*mm, 30*mm])
            table.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#003d6e")), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white), ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 9), ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#c1c7d2")), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f1f4f6")])]))
            story.append(table)
    doc.build(story)

def generate_html_report(data, filepath, title):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(data, dict) and "users" in data:
        data = data["users"]
    html = "<!DOCTYPE html><html lang=\"sv\"><head><meta charset=\"UTF-8\"><title>" + title + "</title><style>body{font-family:Segoe UI,sans-serif;background:#f7fafc;color:#181c1e;padding:40px;max-width:1200px;margin:0 auto;}.header{background:linear-gradient(135deg,#003d6e,#005495);color:white;padding:40px;border-radius:16px;margin-bottom:30px;}.header h1{margin:0 0 10px 0;font-size:28px;}.card{background:white;border-radius:16px;padding:24px;margin-bottom:20px;box-shadow:0 1px 3px rgba(0,0,0,0.1);}.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-bottom:30px;}.stat{background:white;padding:20px;border-radius:12px;text-align:center;}.stat-value{font-size:32px;font-weight:700;color:#003d6e;}.stat-label{font-size:12px;color:#727781;text-transform:uppercase;}table{width:100%;border-collapse:collapse;}th{background:#003d6e;color:white;padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase;}td{padding:12px 16px;border-bottom:1px solid #e0e3e5;}tr:nth-child(even){background:#f1f4f6;}.badge{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11px;font-weight:600;}.badge-critical{background:#ffdad6;color:#93000a;}.badge-warning{background:#ffb688;color:#733600;}.badge-success{background:#d4edda;color:#155724;}</style></head><body><div class=\"header\"><h1>" + title + "</h1><p>Genererad: " + timestamp + "</p></div>"
    if isinstance(data, list) and len(data) > 0:
        first = data[0]
        if "hardware_name" in first:
            html += "<div class=\"stats\"><div class=\"stat\"><div class=\"stat-value\">" + str(len(data)) + "</div><div class=\"stat-label\">Totalt</div></div></div>"
            html += "<div class=\"card\"><table><thead><tr><th>Namn</th><th>IP</th><th>Status</th><th>Inspelning</th></tr></thead><tbody>"
            for item in data:
                s = "Online" if item.get("is_connected") else "Offline"
                sc = "badge-success" if item.get("is_connected") else "badge-critical"
                r = "Ja" if item.get("is_recording") else "Nej"
                html += "<tr><td>" + str(item.get("name","")) + "</td><td>" + str(item.get("ip_address","")) + "</td><td><span class=\"badge " + sc + "\">" + s + "</span></td><td>" + r + "</td></tr>"
            html += "</tbody></table></div>"
        elif "rule_name" in first:
            c = len([d for d in data if d.get("severity") == "Critical"])
            w = len([d for d in data if d.get("severity") == "Warning"])
            html += "<div class=\"stats\"><div class=\"stat\"><div class=\"stat-value\">" + str(len(data)) + "</div><div class=\"stat-label\">Totalt</div></div><div class=\"stat\"><div class=\"stat-value\" style=\"color:#ef4444;\">" + str(c) + "</div><div class=\"stat-label\">Kritiska</div></div><div class=\"stat\"><div class=\"stat-value\" style=\"color:#f97316;\">" + str(w) + "</div><div class=\"stat-label\">Varningar</div></div></div>"
            html += "<div class=\"card\"><table><thead><tr><th>Regel</th><th>Enhet</th><th>Severity</th></tr></thead><tbody>"
            for item in data:
                sc = "badge-critical" if item.get("severity") == "Critical" else "badge-warning" if item.get("severity") == "Warning" else "badge-success"
                html += "<tr><td>" + str(item.get("rule_name","")) + "</td><td>" + str(item.get("device_name","")) + "</td><td><span class=\"badge " + sc + "\">" + str(item.get("severity","")) + "</span></td></tr>"
            html += "</tbody></table></div>"
        elif "email" in first:
            html += "<div class=\"stats\"><div class=\"stat\"><div class=\"stat-value\">" + str(len(data)) + "</div><div class=\"stat-label\">Anvandare</div></div></div>"
            html += "<div class=\"card\"><table><thead><tr><th>Namn</th><th>E-post</th><th>Status</th></tr></thead><tbody>"
            for item in data:
                s = "Aktiv" if item.get("is_enabled") else "Inaktiv"
                sc = "badge-success" if item.get("is_enabled") else "badge-warning"
                html += "<tr><td>" + str(item.get("name","")) + "</td><td>" + str(item.get("email","")) + "</td><td><span class=\"badge " + sc + "\">" + s + "</span></td></tr>"
            html += "</tbody></table></div>"
    html += "<div style=\"text-align:center;padding:20px;color:#727781;font-size:12px;\"><p>XProtect Dashboard | MilestonePSTools</p></div></body></html>"
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html)
'@
Set-Content -Path "$OutputPath\app\report_generator.py" -Value $reportGen -Encoding UTF8

# Skapa app.py
$appPy = @'
import os
import sys
import json
import sqlite3
import subprocess
from datetime import datetime
from flask import Flask, render_template, request, jsonify, redirect, url_for, send_file, flash
from werkzeug.utils import secure_filename

# Lagg till aktuell mapp i Python-sokvagen
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

from config import Config
from report_generator import generate_pdf_report, generate_html_report

app = Flask(__name__)
app.config.from_object(Config)
os.makedirs(app.config["DATA_DIR"], exist_ok=True)
os.makedirs(app.config["REPORTS_DIR"], exist_ok=True)

def init_db():
    conn = sqlite3.connect(app.config["DATABASE"])
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS acknowledgements (id INTEGER PRIMARY KEY AUTOINCREMENT, rule_id TEXT NOT NULL, device_id TEXT, comment TEXT, acknowledged_by TEXT, acknowledged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, expires_at TIMESTAMP)")
    c.execute("CREATE TABLE IF NOT EXISTS report_schedule (id INTEGER PRIMARY KEY AUTOINCREMENT, report_type TEXT NOT NULL, schedule TEXT, last_run TIMESTAMP, enabled INTEGER DEFAULT 1)")
    conn.commit()
    conn.close()

init_db()

def run_powershell(script_name, *args):
    script_path = os.path.join(app.config["SCRIPTS_DIR"], script_name)
    cmd = [app.config["POWERSHELL_PATH"], "-ExecutionPolicy", "Bypass", "-File", script_path]
    cmd.extend(args)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, encoding="utf-8", errors="replace")
        if result.returncode != 0:
            return {"success": False, "error": result.stderr or "Script failed"}
        output = result.stdout.strip() if result.stdout else ""
        if not output:
            return {"success": False, "error": "Ingen output from script"}
        try:
            return {"success": True, "output": json.loads(output)}
        except json.JSONDecodeError:
            return {"success": False, "error": "Ogiltig JSON: " + output[:200]}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Timeout"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_db_acknowledgements(rule_id=None, device_id=None):
    conn = sqlite3.connect(app.config["DATABASE"])
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    if rule_id and device_id:
        c.execute("SELECT * FROM acknowledgements WHERE rule_id = ? AND device_id = ? AND (expires_at IS NULL OR expires_at > datetime('now'))", (rule_id, device_id))
    elif rule_id:
        c.execute("SELECT * FROM acknowledgements WHERE rule_id = ? AND (expires_at IS NULL OR expires_at > datetime('now'))", (rule_id,))
    else:
        c.execute("SELECT * FROM acknowledgements WHERE expires_at IS NULL OR expires_at > datetime('now')")
    result = c.fetchall()
    conn.close()
    return [dict(row) for row in result]

@app.route("/")
def index():
    result = run_powershell("get_status.ps1")
    if result["success"]:
        status = result["output"] if isinstance(result["output"], dict) else {"error": "Invalid response"}
    else:
        status = {"error": result.get("error", "Unknown error"), "connected": False}
    return render_template("dashboard.html", status=status)

@app.route("/cameras")
def cameras():
    result = run_powershell("get_cameras.ps1")
    cameras = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
    return render_template("cameras.html", cameras=cameras)

@app.route("/cameras/import", methods=["GET", "POST"])
def import_cameras():
    if request.method == "POST":
        if "file" not in request.files:
            flash("Ingen fil vald", "error")
            return redirect(request.url)
        file = request.files["file"]
        if file.filename == "":
            flash("Ingen fil vald", "error")
            return redirect(request.url)
        if file:
            filename = secure_filename(file.filename)
            filepath = os.path.join(app.config["DATA_DIR"], filename)
            file.save(filepath)
            result = run_powershell("import_cameras.ps1", filepath)
            if result["success"]:
                flash("Importerade kameror", "success")
            else:
                flash("Fel vid import: " + result.get("error", "Okant fel"), "error")
            return redirect(url_for("cameras"))
    return render_template("import_cameras.html")

@app.route("/cameras/report")
def camera_report():
    report_format = request.args.get("format", "html")
    result = run_powershell("get_cameras.ps1")
    cameras = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if report_format == "pdf":
        filepath = os.path.join(app.config["REPORTS_DIR"], "camera_report_" + timestamp + ".pdf")
        generate_pdf_report(cameras, filepath, "Kamera-rapport")
        return send_file(filepath, as_attachment=True)
    else:
        filepath = os.path.join(app.config["REPORTS_DIR"], "camera_report_" + timestamp + ".html")
        generate_html_report(cameras, filepath, "Kamera-rapport")
        return send_file(filepath, as_attachment=True)

@app.route("/audit")
def audit():
    result = run_powershell("audit.ps1")
    audit_results = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
    acknowledgements = get_db_acknowledgements()
    ack_dict = {(a["rule_id"], a["device_id"]): a for a in acknowledgements}
    for item in audit_results:
        key = (item.get("rule_id"), item.get("device_id"))
        if key in ack_dict:
            item["acknowledged"] = True
            item["ack_comment"] = ack_dict[key]["comment"]
        else:
            item["acknowledged"] = False
    stats = {"total": len(audit_results), "critical": sum(1 for r in audit_results if r.get("severity") == "Critical" and not r.get("acknowledged")), "warning": sum(1 for r in audit_results if r.get("severity") == "Warning" and not r.get("acknowledged")), "info": sum(1 for r in audit_results if r.get("severity") == "Info" and not r.get("acknowledged")), "acknowledged": sum(1 for r in audit_results if r.get("acknowledged"))}
    return render_template("audit.html", audit_results=audit_results, stats=stats)

@app.route("/audit/acknowledge", methods=["POST"])
def acknowledge_issue():
    data = request.get_json()
    conn = sqlite3.connect(app.config["DATABASE"])
    c = conn.cursor()
    c.execute("INSERT INTO acknowledgements (rule_id, device_id, comment, acknowledged_by) VALUES (?, ?, ?, ?)", (data["rule_id"], data["device_id"], data["comment"], data.get("acknowledged_by", "Admin")))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/audit/remove_ack", methods=["POST"])
def remove_acknowledgement():
    data = request.get_json()
    conn = sqlite3.connect(app.config["DATABASE"])
    c = conn.cursor()
    c.execute("DELETE FROM acknowledgements WHERE rule_id = ? AND device_id = ?", (data["rule_id"], data["device_id"]))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/audit/report")
def audit_report():
    report_format = request.args.get("format", "html")
    result = run_powershell("audit.ps1")
    audit_results = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if report_format == "pdf":
        filepath = os.path.join(app.config["REPORTS_DIR"], "audit_report_" + timestamp + ".pdf")
        generate_pdf_report(audit_results, filepath, "Best Practice Audit")
        return send_file(filepath, as_attachment=True)
    else:
        filepath = os.path.join(app.config["REPORTS_DIR"], "audit_report_" + timestamp + ".html")
        generate_html_report(audit_results, filepath, "Best Practice Audit")
        return send_file(filepath, as_attachment=True)

@app.route("/users")
def users():
    result = run_powershell("get_users.ps1")
    if result["success"]:
        users = result["output"].get("users", []) if isinstance(result["output"], dict) else []
    else:
        users = []
    return render_template("users.html", users=users)

@app.route("/users/report")
def users_report():
    report_format = request.args.get("format", "html")
    result = run_powershell("get_users.ps1")
    if result["success"]:
        users = result["output"].get("users", []) if isinstance(result["output"], dict) else []
    else:
        users = []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if report_format == "pdf":
        filepath = os.path.join(app.config["REPORTS_DIR"], "users_report_" + timestamp + ".pdf")
        generate_pdf_report(users, filepath, "Anvandare och Roller")
        return send_file(filepath, as_attachment=True)
    else:
        filepath = os.path.join(app.config["REPORTS_DIR"], "users_report_" + timestamp + ".html")
        generate_html_report(users, filepath, "Anvandare och Roller")
        return send_file(filepath, as_attachment=True)

@app.route("/rules")
def rules():
    result = run_powershell("get_rules.ps1")
    rules = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
    return render_template("rules.html", rules=rules)

@app.route("/rules/toggle", methods=["POST"])
def toggle_rule():
    data = request.get_json()
    result = run_powershell("toggle_rule.ps1", data["rule_id"], "true" if data["enabled"] else "false")
    return jsonify(result)

@app.route("/reports")
def reports():
    conn = sqlite3.connect(app.config["DATABASE"])
    c = conn.cursor()
    c.execute("SELECT * FROM report_schedule")
    schedules = [dict(row) for row in c.fetchall()]
    conn.close()
    existing_reports = []
    for f in os.listdir(app.config["REPORTS_DIR"]):
        filepath = os.path.join(app.config["REPORTS_DIR"], f)
        existing_reports.append({"filename": f, "created": datetime.fromtimestamp(os.path.getctime(filepath)), "size": os.path.getsize(filepath)})
    existing_reports.sort(key=lambda x: x["created"], reverse=True)
    return render_template("reports.html", schedules=schedules, existing_reports=existing_reports)

@app.route("/reports/schedule", methods=["POST"])
def schedule_report():
    data = request.get_json()
    conn = sqlite3.connect(app.config["DATABASE"])
    c = conn.cursor()
    c.execute("INSERT INTO report_schedule (report_type, schedule, enabled) VALUES (?, ?, 1)", (data["report_type"], data["schedule"]))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/reports/run", methods=["POST"])
def run_report():
    data = request.get_json()
    report_type = data.get("report_type", "all")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if report_type == "cameras" or report_type == "all":
        result = run_powershell("get_cameras.ps1")
        cameras = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
        generate_html_report(cameras, os.path.join(app.config["REPORTS_DIR"], "camera_report_" + timestamp + ".html"), "Kamera-rapport")
    if report_type == "audit" or report_type == "all":
        result = run_powershell("audit.ps1")
        audit_results = result["output"] if (result["success"] and isinstance(result["output"], list)) else []
        generate_html_report(audit_results, os.path.join(app.config["REPORTS_DIR"], "audit_report_" + timestamp + ".html"), "Best Practice Audit")
    if report_type == "users" or report_type == "all":
        result = run_powershell("get_users.ps1")
        users = result["output"].get("users", []) if (result["success"] and isinstance(result["output"], dict)) else []
        generate_html_report(users, os.path.join(app.config["REPORTS_DIR"], "users_report_" + timestamp + ".html"), "Anvandare och Roller")
    return jsonify({"success": True, "timestamp": timestamp})

@app.route("/api/status")
def api_status():
    result = run_powershell("get_status.ps1")
    return jsonify(result["output"] if result["success"] else {})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
'@
Set-Content -Path "$OutputPath\app\app.py" -Value $appPy -Encoding UTF8

Write-Host "   Klart!" -ForegroundColor Green

# STEG 6: Skapa START.bat
Write-Host "[6/6] Skapar start-skript..." -ForegroundColor Yellow
$startBat = @'
@echo off
cd /d "%~dp0"
cd app
echo.
echo =============================================
echo   XProtect Dashboard
echo =============================================
echo.
echo Startar servern...
echo.
echo Oppna webblasare och ga till:
echo   http://localhost:5000
echo.
..\python\python.exe app.py
pause
'@
Set-Content -Path "$OutputPath\START.bat" -Value $startBat -Encoding ASCII
Write-Host "   Klart!" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Klart! Paketet ar helt forberett." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Naesta steg:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. ZIPPA mappen:" -ForegroundColor White
Write-Host "   Compress-Archive -Path ""$OutputPath"" -DestinationPath ""$OutputPath.zip""" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Kopiera till servern" -ForegroundColor White
Write-Host ""
Write-Host "3. Pa servern:" -ForegroundColor White
Write-Host "   - Packa upp" -ForegroundColor Gray
Write-Host "   - Installera MilestonePSTools:" -ForegroundColor Gray
Write-Host "     Copy-Item fran en annan server:" -ForegroundColor Gray
Write-Host "     Copy-Item -Path ""\\ANNAN-SERVER\C$\Program Files\WindowsPowerShell\Modules\MilestonePSTools"" -Destination ""C:\Program Files\WindowsPowerShell\Modules\"" -Recurse" -ForegroundColor Gray
Write-Host "   - Kor START.bat" -ForegroundColor Gray
Write-Host ""
