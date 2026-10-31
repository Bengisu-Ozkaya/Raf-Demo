import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PORT: int = int(os.getenv("PORT", "8080"))
    JWT_SECRET: str = os.getenv("JWT_SECRET", "raf_demo_secure_jwt_secret_key_2026_x89a1b2c3d4e5f6")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 gün
    
    DB_TYPE: str = os.getenv("DB_TYPE", "firestore") # firestore or postgres
    GCP_PROJECT_ID: str = os.getenv("GCP_PROJECT_ID", "")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

