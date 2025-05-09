#!js name=steamlib api_version=1.0

// === 1. Univerzální FT.SEARCH bez LIMIT ===
redis.registerClusterFunction("remoteSearchByText", async (async_client, [indexName, query]) => {
    return await async_client.block(async (client) => {
        redis.log(`🔍 Searching in index '${indexName}' for query: ${query}`);

        const search = await client.callAsync(
            'FT.SEARCH',
            indexName,
            query,
            'NOCONTENT'
        );

        const results = search.results || [];
        if (!Array.isArray(results) || results.length === 0) {
            redis.log("❌ No FT.SEARCH results");
            return [];
        }
      

        return results.map(r => r.id)
    });
});

// === 2. HGETALL + extrakce pole ===
redis.registerClusterFunction("remoteHGetFieldFromHash", async (async_client, [hashKey, fieldName]) => {
    return await async_client.block(async (client) => {
        const hash = await client.callAsync('HGETALL', hashKey);
        redis.log("📦 Hash data for " + hashKey + ": " + JSON.stringify(hash));

        const value = hash[fieldName];
        if (!value) {
            redis.log(`❌ Field '${fieldName}' not found in ${hashKey}`);
            return null;
        }

        redis.log(`🧩 Extracted field '${fieldName}': ${value}`);
        return value;
    });
});

// === 3. HGETALL celého hashe ===
redis.registerClusterFunction("remoteFetchHash", async (async_client, hashKey) => {
    return await async_client.block(async (client) => {
        const data = await client.callAsync('HGETALL', hashKey);
        if (!data || Object.keys(data).length === 0) {
            redis.log("⚠️ Hash is empty: " + hashKey);
            return null;
        }

        redis.log("📦 Fetched full hash from " + hashKey);
        return data;
    });
});

// === 4. Orchestrátor: získat všechna steam:{appid} data podle textového dotazu ===
redis.registerAsyncFunction("searchSteamByText", async (async_client, query) => {
    const indexName = "steam_desc_idx";

    const [rawResults] = await async_client.runOnShards("remoteSearchByText", [indexName, query]);
    const keys = rawResults.flat();  // sjednocení výsledků ze všech shardů
    redis.log("🔍 Flattened descKeys: " + JSON.stringify(keys));

    if (keys.length === 0) {
        redis.log("❌ No descKeys found across shards");
        return [];
    }

    const results = [];

    try {
        for (const descKey of keys) {
            const appid = await async_client.runOnKey(descKey, "remoteHGetFieldFromHash", [descKey, "steam_appid"]);
            if (!appid) continue;

            const steamKey = `steam:{${appid}}`;
            const data = await async_client.runOnKey(steamKey, "remoteFetchHash", steamKey);
            if (data) {                
                results.push(data);
            }
        }
    } catch (error) {
        redis.log("❌ Error while fetching data: " + error);
        return [];
    }

    redis.log(`✅ Returning ${results.length} matched records`);
    return results;
});
