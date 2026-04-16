import os
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_CENTER, TA_LEFT

def generate_pdf_report(data, filepath, title):
    doc = SimpleDocTemplate(
        filepath,
        pagesize=A4,
        rightMargin=20*mm,
        leftMargin=20*mm,
        topMargin=20*mm,
        bottomMargin=20*mm
    )
    
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        spaceAfter=30,
        alignment=TA_CENTER,
        textColor=colors.HexColor('#003d6e')
    ))
    styles.add(ParagraphStyle(
        name='CustomSubtitle',
        parent=styles['Normal'],
        fontSize=10,
        textColor=colors.gray,
        alignment=TA_CENTER,
        spaceAfter=20
    ))
    styles.add(ParagraphStyle(
        name='SectionHeader',
        parent=styles['Heading2'],
        fontSize=14,
        spaceBefore=20,
        spaceAfter=10,
        textColor=colors.HexColor('#003d6e')
    ))
    
    story = []
    
    story.append(Paragraph(title, styles['CustomTitle']))
    story.append(Paragraph(f"Genererad: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", styles['CustomSubtitle']))
    story.append(Spacer(1, 10))
    
    if isinstance(data, dict) and 'users' in data:
        data = data['users']
    
    if isinstance(data, list) and len(data) > 0:
        first_item = data[0]
        
        if 'name' in first_item and 'hardware_name' in first_item:
            story.append(Paragraph("Kameror", styles['SectionHeader']))
            table_data = [['Namn', 'IP-adress', 'Modell', 'Status', 'Inspelning']]
            for item in data:
                status = 'Online' if item.get('is_connected', False) else 'Offline'
                recording = 'Ja' if item.get('is_recording', False) else 'Nej'
                table_data.append([
                    item.get('name', ''),
                    item.get('ip_address', ''),
                    item.get('hardware_model', ''),
                    status,
                    recording
                ])
            
            table = Table(table_data, colWidths=[60*mm, 35*mm, 40*mm, 25*mm, 25*mm])
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#003d6e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.white),
                ('TEXTCOLOR', (0, 1), (-1, -1), colors.HexColor('#181c1e')),
                ('FONTSIZE', (0, 1), (-1, -1), 8),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#c1c7d2')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f1f4f6')]),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ]))
            story.append(table)
            
        elif 'rule_name' in first_item:
            story.append(Paragraph("Best Practice Audit Resultat", styles['SectionHeader']))
            
            critical = [d for d in data if d.get('severity') == 'Critical']
            warnings = [d for d in data if d.get('severity') == 'Warning']
            info = [d for d in data if d.get('severity') == 'Info']
            
            stats_table_data = [['Typ', 'Antal']]
            stats_table_data.append(['Kritiska', len(critical)])
            stats_table_data.append(['Varningar', len(warnings)])
            stats_table_data.append(['Info', len(info)])
            stats_table_data.append(['Totalt', len(data)])
            
            stats_table = Table(stats_table_data, colWidths=[60*mm, 30*mm])
            stats_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#003d6e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
                ('TOPPADDING', (0, 0), (-1, -1), 10),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#c1c7d2')),
            ]))
            story.append(stats_table)
            story.append(Spacer(1, 20))
            
            story.append(Paragraph("Detaljerade resultat", styles['SectionHeader']))
            
            detail_data = [['Regel', 'Enhet', 'Severity']]
            for item in data:
                detail_data.append([
                    item.get('rule_name', '')[:40],
                    item.get('device_name', '')[:25],
                    item.get('severity', '')
                ])
            
            detail_table = Table(detail_data, colWidths=[60*mm, 45*mm, 25*mm])
            detail_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#003d6e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#c1c7d2')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f1f4f6')]),
            ]))
            story.append(detail_table)
            
        elif 'roles' in first_item or 'email' in first_item:
            story.append(Paragraph("Användare och Roller", styles['SectionHeader']))
            table_data = [['Användare', 'E-post', 'Roller', 'Status']]
            for item in data:
                roles = ', '.join(item.get('roles', [])[:3])
                status = 'Aktiv' if item.get('is_enabled', True) else 'Inaktiv'
                table_data.append([
                    item.get('name', ''),
                    item.get('email', ''),
                    roles,
                    status
                ])
            
            table = Table(table_data, colWidths=[45*mm, 50*mm, 40*mm, 25*mm])
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#003d6e')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#c1c7d2')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f1f4f6')]),
            ]))
            story.append(table)
    
    doc.build(story)

def generate_html_report(data, filepath, title):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    if isinstance(data, dict) and 'users' in data:
        data = data['users']
    
    html_content = f'''<!DOCTYPE html>
<html lang="sv">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {{
            font-family: 'Inter', sans-serif;
            background: #f7fafc;
            color: #181c1e;
            padding: 40px;
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #003d6e, #005495);
            color: white;
            padding: 40px;
            border-radius: 16px;
            margin-bottom: 30px;
        }}
        .header h1 {{
            margin: 0 0 10px 0;
            font-size: 28px;
        }}
        .header p {{
            margin: 0;
            opacity: 0.8;
        }}
        .card {{
            background: white;
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 30px;
        }}
        .stat {{
            background: white;
            padding: 20px;
            border-radius: 12px;
            text-align: center;
        }}
        .stat-value {{
            font-size: 32px;
            font-weight: 700;
            color: #003d6e;
        }}
        .stat-label {{
            font-size: 12px;
            color: #727781;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
        }}
        th {{
            background: #003d6e;
            color: white;
            padding: 12px 16px;
            text-align: left;
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        td {{
            padding: 12px 16px;
            border-bottom: 1px solid #e0e3e5;
            font-size: 14px;
        }}
        tr:nth-child(even) {{
            background: #f1f4f6;
        }}
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }}
        .badge-critical {{
            background: #ffdad6;
            color: #93000a;
        }}
        .badge-warning {{
            background: #ffb688;
            color: #733600;
        }}
        .badge-info {{
            background: #cdddff;
            color: #004881;
        }}
        .badge-success {{
            background: #d4edda;
            color: #155724;
        }}
        .footer {{
            text-align: center;
            padding: 20px;
            color: #727781;
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>{title}</h1>
        <p>Genererad: {timestamp}</p>
    </div>
'''
    
    if isinstance(data, list) and len(data) > 0:
        first_item = data[0]
        
        if 'name' in first_item and 'hardware_name' in first_item:
            total = len(data)
            online = len([d for d in data if d.get('is_connected')])
            recording = len([d for d in data if d.get('is_recording')])
            
            html_content += f'''
    <div class="stats">
        <div class="stat">
            <div class="stat-value">{total}</div>
            <div class="stat-label">Totalt kameror</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #22c55e;">{online}</div>
            <div class="stat-label">Online</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #003d6e;">{recording}</div>
            <div class="stat-label">Inspelande</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #ef4444;">{total - online}</div>
            <div class="stat-label">Offline</div>
        </div>
    </div>
    
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>Namn</th>
                    <th>IP-adress</th>
                    <th>Modell</th>
                    <th>Firmware</th>
                    <th>Status</th>
                    <th>Inspelning</th>
                </tr>
            </thead>
            <tbody>
'''
            for item in data:
                status_class = 'badge-success' if item.get('is_connected') else 'badge-critical'
                status_text = 'Online' if item.get('is_connected') else 'Offline'
                recording = '<span class="badge badge-success">Ja</span>' if item.get('is_recording') else '<span class="badge badge-info">Nej</span>'
                
                html_content += f'''
                <tr>
                    <td><strong>{item.get('name', '')}</strong></td>
                    <td>{item.get('ip_address', '')}</td>
                    <td>{item.get('hardware_model', '')}</td>
                    <td>{item.get('firmware', '')}</td>
                    <td><span class="badge {status_class}">{status_text}</span></td>
                    <td>{recording}</td>
                </tr>
'''
            html_content += '''
            </tbody>
        </table>
    </div>
'''
        
        elif 'rule_name' in first_item:
            critical = len([d for d in data if d.get('severity') == 'Critical'])
            warnings = len([d for d in data if d.get('severity') == 'Warning'])
            info = len([d for d in data if d.get('severity') == 'Info'])
            
            html_content += f'''
    <div class="stats">
        <div class="stat">
            <div class="stat-value">{len(data)}</div>
            <div class="stat-label">Totalt resultat</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #ef4444;">{critical}</div>
            <div class="stat-label">Kritiska</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #f97316;">{warnings}</div>
            <div class="stat-label">Varningar</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #3b82f6;">{info}</div>
            <div class="stat-label">Info</div>
        </div>
    </div>
    
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>Regel</th>
                    <th>Enhet</th>
                    <th>Severity</th>
                    <th>Beskrivning</th>
                    <th>Rekommendation</th>
                </tr>
            </thead>
            <tbody>
'''
            for item in data:
                severity_class = 'badge-critical' if item.get('severity') == 'Critical' else ('badge-warning' if item.get('severity') == 'Warning' else 'badge-info')
                
                html_content += f'''
                <tr>
                    <td><strong>{item.get('rule_name', '')}</strong></td>
                    <td>{item.get('device_name', '')}</td>
                    <td><span class="badge {severity_class}">{item.get('severity', '')}</span></td>
                    <td>{item.get('description', '')[:80]}...</td>
                    <td>{item.get('recommendation', '')[:80]}...</td>
                </tr>
'''
            html_content += '''
            </tbody>
        </table>
    </div>
'''
        
        elif 'roles' in first_item or 'email' in first_item:
            active = len([d for d in data if d.get('is_enabled')])
            builtin = len([d for d in data if d.get('is_builtin')])
            
            html_content += f'''
    <div class="stats">
        <div class="stat">
            <div class="stat-value">{len(data)}</div>
            <div class="stat-label">Totalt användare</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #22c55e;">{active}</div>
            <div class="stat-label">Aktiva</div>
        </div>
        <div class="stat">
            <div class="stat-value" style="color: #003d6e;">{builtin}</div>
            <div class="stat-label">Inbyggda</div>
        </div>
    </div>
    
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>Användare</th>
                    <th>E-post</th>
                    <th>Domain</th>
                    <th>Roller</th>
                    <th>Status</th>
                    <th>Senast inloggad</th>
                </tr>
            </thead>
            <tbody>
'''
            for item in data:
                status_class = 'badge-success' if item.get('is_enabled') else 'badge-warning'
                status_text = 'Aktiv' if item.get('is_enabled') else 'Inaktiv'
                roles = ', '.join(item.get('roles', [])[:2])
                
                html_content += f'''
                <tr>
                    <td><strong>{item.get('name', '')}</strong></td>
                    <td>{item.get('email', '')}</td>
                    <td>{item.get('domain', '')}</td>
                    <td>{roles}</td>
                    <td><span class="badge {status_class}">{status_text}</span></td>
                    <td>{item.get('last_login', 'Aldrig')}</td>
                </tr>
'''
            html_content += '''
            </tbody>
        </table>
    </div>
'''
    
    html_content += '''
    <div class="footer">
        <p>XProtect Dashboard | MilestonePSTools | Genererad av automatiserad rapport</p>
    </div>
</body>
</html>
'''
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html_content)
