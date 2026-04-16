import sys
import os
import subprocess
import json
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from report_generator import generate_html_report

def run_powershell(script_name):
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', script_name)
    cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', script_path]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode == 0:
            return json.loads(result.stdout)
        return {'error': result.stderr}
    except Exception as e:
        return {'error': str(e)}

def main():
    schedule = sys.argv[1] if len(sys.argv) > 1 else 'daily'
    
    print(f"Generating scheduled report: {schedule}")
    
    reports_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'reports')
    os.makedirs(reports_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    print("Fetching cameras...")
    cameras = run_powershell('get_cameras.ps1')
    if 'error' not in cameras:
        filepath = os.path.join(reports_dir, f'camera_report_{timestamp}.html')
        generate_html_report(cameras, filepath, 'Kamera-rapport')
        print(f"Camera report saved: {filepath}")
    
    print("Fetching audit results...")
    audit_results = run_powershell('audit.ps1')
    if 'error' not in audit_results:
        filepath = os.path.join(reports_dir, f'audit_report_{timestamp}.html')
        generate_html_report(audit_results, filepath, 'Best Practice Audit')
        print(f"Audit report saved: {filepath}")
    
    print("Fetching users...")
    users = run_powershell('get_users.ps1')
    if 'error' not in users:
        filepath = os.path.join(reports_dir, f'users_report_{timestamp}.html')
        generate_html_report(users, filepath, 'Anvaendare och Roller')
        print(f"Users report saved: {filepath}")
    
    print(f"All reports generated at {datetime.now()}")

if __name__ == '__main__':
    main()
