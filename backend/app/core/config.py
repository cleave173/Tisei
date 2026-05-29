from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Tisei API"
    api_v1_prefix: str = "/api/v1"
    cors_origins: list[str] = ["*"]

    # Database: Railway provides DATABASE_URL directly; fallback to individual vars for local dev.
    database_url_raw: str | None = Field(default=None, alias="DATABASE_URL")
    postgres_user: str = "tisei"
    postgres_password: str = "tisei"
    postgres_db: str = "tisei"
    postgres_host: str = "db"
    postgres_port: int = 5432

    # Auth
    jwt_secret: str = Field(default="change-me-in-prod")
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60  # 1 hour; override in .env
    refresh_token_expire_days: int = 30
    reset_code_expire_minutes: int = 15

    # Email
    email_backend: str = "console"  # "smtp" or "console"
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "noreply@tisei.app"
    smtp_tls: bool = True  # STARTTLS on port 587

    # Google
    google_client_id: str | None = None

    # External services
    libretranslate_url: str = "http://libretranslate:5000"
    yandex_translate_api_key: str | None = None
    yandex_folder_id: str | None = None

    # Google Gemini (used for AI-powered game content generation)
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-2.0-flash"

    @property
    def database_url(self) -> str:
        if self.database_url_raw:
            # Railway gives postgresql:// or postgres://; convert to asyncpg driver.
            return self.database_url_raw.replace(
                "postgresql://",
                "postgresql+asyncpg://",
                1,
            ).replace("postgres://", "postgresql+asyncpg://", 1)
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def database_source(self) -> str:
        return "DATABASE_URL" if self.database_url_raw else "POSTGRES_*"

    @property
    def sync_database_url(self) -> str:
        if self.database_url_raw:
            return self.database_url_raw.replace(
                "postgresql://",
                "postgresql+psycopg2://",
                1,
            ).replace("postgres://", "postgresql+psycopg2://", 1)
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
