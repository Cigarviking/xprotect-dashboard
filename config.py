import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'xprotect-dashboard-secret-key-2024'
    
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DATA_DIR = os.path.join(BASE_DIR, 'data')
    REPORTS_DIR = os.path.join(BASE_DIR, 'reports')
    SCRIPTS_DIR = os.path.join(BASE_DIR, 'scripts')
    
    DATABASE = os.path.join(DATA_DIR, 'audit.db')
    
    POWERSHELL_PATH = 'powershell.exe'
    
    ALLOWED_EXTENSIONS = {'xlsx', 'xls', 'csv'}
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024

    REPORT_SCHEDULE_OPTIONS = {
        'daily': 'Dagligen kl 04:00',
        'weekly': 'Varje måndag kl 04:00',
        'monthly': 'Första dagen i varje månad kl 04:00'
    }
