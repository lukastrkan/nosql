#!js name=steamlib api_version=1.0

// === 1. Univerzální FT.SEARCH bez LIMIT ===
redis.registerClusterFunction("remoteSearchByText", async (async_client, [indexName, query]) => {
    return await async_client.block(async (client) => {
        
        const search = await client.callAsync(
            'FT.SEARCH',
            indexName,
            query,
            'NOCONTENT'
        );

        const results = search.results || [];
        if (!Array.isArray(results) || results.length === 0) {            
            redis.log("No results found for query: " + query);
            return [];
        }
      

        return results.map(r => r.id)
    });
});

// === 2. HGETALL + extrakce pole ===
redis.registerClusterFunction("remoteHGetFieldFromHash", async (async_client, [hashKey, fieldName]) => {
    return await async_client.block(async (client) => {
        const hash = await client.callAsync('HGETALL', hashKey);        

        const value = hash[fieldName];
        if (!value) {          
            redis.log("No value found for field: " + fieldName);  
            return null;
        }

        return value;
    });
});

// === 3. HGETALL celého hashe ===
redis.registerClusterFunction("remoteFetchHash", async (async_client, hashKey) => {
    return await async_client.block(async (client) => {
        const data = await client.callAsync('HGETALL', hashKey);
        if (!data || Object.keys(data).length === 0) {     
            redis.log("No data found for hash key: " + hashKey);       
            return null;
        }

        return data;
    });
});

// === 4. Orchestrátor: získat všechna steam:{appid} data podle textového dotazu ===
redis.registerAsyncFunction("searchSteamByText", async (async_client, query) => {
    const indexName = "steam_desc_idx";

    const [rawResults] = await async_client.runOnShards("remoteSearchByText", [indexName, query]);
    const keys = rawResults.flat();  // sjednocení výsledků ze všech shardů

    if (keys.length === 0) {    
        redis.log("No keys found for query: " + query);
        return [];
    }

    const results = [];

        for (const descKey of keys) {
            try {
                const appid = await async_client.runOnKey(descKey, "remoteHGetFieldFromHash", [descKey, "steam_appid"]);
                if (!appid) continue;
    
                const steamKey = `steam:{${appid}}`;
                const data = await async_client.runOnKey(steamKey, "remoteFetchHash", steamKey);
                if (data) {                
                    results.push(data);
                }
            } catch (error) {
                redis.log(`Error processing key ${descKey}: ${error}`);
            }
            
        }

    return results;
});
