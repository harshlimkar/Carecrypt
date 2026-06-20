from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3"
    DEBUG: bool = True
    ALLOWED_ORIGINS: List[str] = ["*"]
    SECRET_KEY: str = "carecrypt-secret-key-change-in-production"

    class Config:
        env_file = "../.env"
        extra = "ignore"
