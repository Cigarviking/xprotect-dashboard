import os
import json
import sqlite3
import subprocess
from datetime import datetime
from flask import Flask, render_template, request, jsonify, redirect, url_for, send_file, flash
from werkzeug.utils import secure_filename
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
