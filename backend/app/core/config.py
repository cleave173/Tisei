from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Tisei API"
    api_v1_prefix: str = "/api/v1"
    cors_origins: list[str] = ["*"]

    # Database
    postgres_user: str = "tisei"
    postgres_password: str = "tisei"
    postgres_db: str = "tisei"
    postgres_host: str = "db"
    postgres_port: int = 5432

    # Auth
    jwt_secret: str = Field(default="change-me-in-prod")
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24
    refresh_token_expire_days: int = 30

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
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def sync_database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
