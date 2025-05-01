from redis.cluster import RedisCluster, ClusterNode
import json
import pandas as pd
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib.colors as colors

# Připojení k Redis Clusteru
startup_nodes = [
    ClusterNode(host='172.28.0.11', port=6379),
    ClusterNode(host='172.28.0.13', port=6379),
    ClusterNode(host='172.28.0.15', port=6379),
]
r = RedisCluster(startup_nodes=startup_nodes, decode_responses=True, password='strongpassword')

# Načti všechny klíče
keys = list(r.scan_iter(match="aircraft:*:positions"))

# Pipeline pro efektivní hromadné načtení listů
pipe = r.pipeline()
for key in keys:
    pipe.lrange(key, 0, -1)
results = pipe.execute()

# Shromáždi souřadnice
latitudes = []
longitudes = []

for raw_items in results:
    for raw in raw_items:
        try:
            data = json.loads(raw)
            if "lat" in data and "lon" in data:
                latitudes.append(data["lat"])
                longitudes.append(data["lon"])
        except Exception:
            continue

# Vytvoření DataFrame
df = pd.DataFrame({
    'lat': latitudes,
    'lon': longitudes
})

# Vykreslení heatmapy s mapovým podkladem
fig = plt.figure(figsize=(14, 9))
ax = plt.axes(projection=ccrs.PlateCarree())
ax.set_global()
ax.coastlines(resolution='50m')
ax.add_feature(cfeature.BORDERS, linewidth=0.5)
ax.add_feature(cfeature.LAND, facecolor='lightgray')
ax.add_feature(cfeature.OCEAN, facecolor='lightblue')

# Histogram s logaritmickým normálem
plt.hist2d(
    df['lon'],
    df['lat'],
    bins=1200,
    cmap='hot',
    norm=colors.LogNorm(vmin=1, vmax=None),  # vmin=1 zajistí, že i minimum bude vidět
    alpha=0.7
)

plt.title("Heatmapa poloh letadel (zvýrazněné minimum)")
plt.colorbar(label='Počet bodů (log scale)', orientation='vertical', shrink=0.5, pad=0.05)
plt.savefig("heatmap_letadel.png", dpi=3000, bbox_inches='tight')
