import kagglehub
from redis_client import get_redis_client
import os
import csv

# Download latest version
path = kagglehub.dataset_download("nikdavis/steam-store-games")

r = get_redis_client()

for file in os.listdir(path):
    if file.endswith(".csv"):
        with open(os.path.join(path, file), newline='', encoding='utf-8') as f:
            filaname = file.split(".")[0]
            reader = csv.DictReader(f)
            for i, row in enumerate(reader):
                if 'steam_appid' in row:
                    appid = '{'+row['steam_appid']+'}'
                else:
                    appid = '{'+row['appid']+'}'
                key = f"{filaname}:{appid}"
                r.hset(key, mapping=row)  # Redis hash
            print(f"Loaded {file} into Redis as hashes")

r.execute_command(
    "FT.CREATE", "idx_games",
    "ON", "HASH",
    "PREFIX", "1", "steam:{",
    "SCHEMA",
    "name", "TEXT",
    "price", "NUMERIC", "SORTABLE",
    "genres", "TEXT",
    "platforms", "TEXT",
    "steamspy_tags", "TEXT",
    "release_date", "TEXT", "SORTABLE",
    "developer", "TEXT", "SORTABLE",
    "positive_ratings", "NUMERIC", "SORTABLE",
    "negative_ratings", "NUMERIC", "SORTABLE",
    "average_playtime", "NUMERIC", "SORTABLE",
    "owners", "TEXT", "SORTABLE",
)

r.execute_command(
    "FT.CREATE", "idx_steam_description",
    "ON", "HASH",
    "PREFIX", "1", "desc:{",
    "SCHEMA",
    "detailed_description", "TEXT",
    "about_the_game", "TEXT",
    "short_description", "TEXT"
)

r.execute_command(
    "FT.CREATE", "idx_steam_media",
    "ON", "HASH",
    "PREFIX", "1", "media:{",
    "SCHEMA",
    "header_image", "TEXT",
    "screenshots", "TEXT",
    "background", "TEXT",
    "movies", "TEXT"
)

r.execute_command(
    "FT.CREATE", "idx_steam_requirements",
    "ON", "HASH",
    "PREFIX", "1", "req:{",
    "SCHEMA",
    "pc_requirements", "TEXT",
    "mac_requirements", "TEXT",
    "linux_requirements", "TEXT",
    "minimum", "TEXT",
    "recommended", "TEXT"
)

r.execute_command(
    "FT.CREATE", "idx_steamspy_tags",
    "ON", "HASH",
    "PREFIX", "1", "tags:{",
    "SCHEMA",
    "tags", "TEXT"
)

r.execute_command(
    "FT.CREATE", "idx_steam_support",
    "ON", "HASH",
    "PREFIX", "1", "support:{",
    "SCHEMA",
    "website", "TEXT",
    "support_url", "TEXT",
    "support_email", "TEXT"
)
