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
