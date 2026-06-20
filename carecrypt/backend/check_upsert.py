import os
import sys
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path)

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import Settings
from supabase import create_client

settings = Settings()
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

try:
    print("Testing single upsert on users table...")
    res = supabase.table("users").upsert({
        "id": "2435abf3-bc49-4741-9f26-9e120c403958",
        "email": "patient1@gmail.com",
        "role": "patient",
        "display_name": "Alex Johnson"
    }).execute()
    print("Response Data:", res.data)
except Exception as e:
    print("Upsert Exception:", e)
