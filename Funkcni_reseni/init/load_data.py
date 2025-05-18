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
    "FT.CREATE", "steam_desc_idx",
    "ON", "HASH",
    "PREFIX", "1", "steam_description_data:",
    "SCHEMA",
    "short_description", "TEXT",
    "detailed_description", "TEXT",
    "about_the_game", "TEXT",
    "steam_appid", "NUMERIC"
)
