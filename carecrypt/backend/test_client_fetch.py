import os
import sys
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path)

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import Settings
from supabase import create_client

settings = Settings()
# Use the same key as client (service role fallback key)
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

try:
    print("Logging in as patient1@gmail.com...")
    auth_res = supabase.auth.sign_in_with_password({
        "email": "patient1@gmail.com",
        "password": "Test@123"
    })
    user_id = auth_res.user.id
    jwt_token = auth_res.session.access_token
    print(f"Login success! User ID: {user_id}")
    
    # Create a client representing the authenticated user by setting the Authorization header
    print("Fetching profile as the logged-in user...")
    user_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    user_client.postgrest.auth(jwt_token)
    
    profile_res = user_client.table("users").select("*, patients(patient_id)").eq("id", user_id).single().execute()
    print("Profile Fetch Success:", profile_res.data)
except Exception as e:
    print("Fetch Failed:")
    print(e)
