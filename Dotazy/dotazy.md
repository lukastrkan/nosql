# Dotazy

## Práce s daty

### Insert

```
HSET steam:{2000000} appid 2000000 name "UHK Simulator" release_date "2025-01-01" developer "ltrk.dev" publisher "UHK" platforms "windows,linux" price 6.9
```

Vytvoření nové hashmapy pod klíčem steam:{2000000}. Ukládají se následující informace o hře:
- appid: 2000000
- name: "UHK Simulator"
- release_date: "2025-01-01
- developer: "ltrk.dev
- publisher: "UHK
- platforms: "windows,linux"
- price: 6.9

### Update hodnoty

```
HSET steam:{2000000} name "Simulator UHK"
```

Aktualizace/přidání pole name v již existující hashmapě pod klíčem steam:{2000000}. Hodnota name se změní na "Simulator UHK".

### Smazání hodnoty

```
HDEL steam:{2000000} price
```

Z hashmapy s klíčem steam:{2000000} se odstraní pole price.

### Přejmenování klíče

```
RENAME steam:{2000000} steam:{2000001}
```

Změní název klíče ze steam:{2000000} na steam:{2000001}.

### Nastavení expirace

```
EXPIRE steam:{2000000}_copy 60
```

Nastaví expiraci klíče steam:{2000000}_copy na 60 sekund. Po uplynutí této doby bude klíč i s jeho obsahem automaticky odstraněn z databáze.

### Kopírování klíče

```
COPY steam:{2000000} steam:{2000000}:backup
```

Vytvoří kopii klíče steam:{2000000} pod novým názvem steam:{2000000}:backup.

## Indexy (RediSearch)

### Vytvoření indexu

```
FT.CREATE idx_games ON HASH PREFIX 1 "steam:{" SCHEMA name TEXT SORTABLE developer TEXT SORTABLE price NUMERIC SORTABLE genres TEXT
```

Vytvoření fulltextového indexu idx_games nad hash záznamy začínajícími prefixem steam:{. Index bude fungovat nad těmito poli v každé hash:
- name jako textové pole, které lze řadit 
- developer jako textové pole, které lze řadit
- price jako číselné pole, které lze řadit
- genres jako textové pole bez možnosti řazení

### Výpis existujících indexů

```
FT._LIST
```

Výpis všech existujících indexů.

### Zobrazení detailů indexu

```
FT.INFO idx_games
```

Vrátí nastavení konkrétního indexu.

### Smazání indexu

```
FT.DROPINDEX idx_games
```

Odstraní index idx_games.

### Smazání indexu a dat

```
FT.DROPINDEX idx_games DD
```

Odstraní index idx_games a smaže i hodnoty klíče kterých se index týkal.

### Úprava indexu

```
FT.ALTER 'idx_games' SCHEMA ADD release_date TEXT SORTABLE
```

Do existujícího indexu idx_games se přidá nové textové řaditelné pole release_date.

## Filtrování (RediSearch)

### Fulltextové vyhledávání v textu a řazení

```
FT.SEARCH idx_games "@name: simulator" SORTBY price DESC
```

Vyhledá v indexu idx_games všechny hry, kde pole name obsahuje slovo „simulator". Výsledky budou seřazeny sestupně podle ceny.

### Fulltext vyhledávání a filtrování podle rozsahu

```
FT.SEARCH 'idx_games' '@genres:(simulator) @price:[0, 10]'
```

Vyhledá v indexu idx_games všechny hry, které splňují následující podmínky:
- V poli genres se nachází slovo „simulator"
- Pole price je v rozsahu 0–10

### Fulltext vyhledávání s negací

```
FT.SEARCH 'idx_games' '+@platforms:mac @genres:(racing) -@platforms:linux ' RETURN 3 name platforms genres
```

Vyhledá v indexu idx_games všechny hry, které:
- Obsahují „mac" v poli platforms
- Mají v poli genres slovo „racing"
- Nevyskytují se na platformě „linux"

### Vyhledávání s OR

```
FT.SEARCH 'idx_games' '@platforms:(mac|linux) -@platforms:(windows) ' RETURN 4 name platforms genres price
```

Vyhledá všechny hry, které:
- Podporují platformu mac NEBO linux
- Nepodporují platformu windows

Z výsledku zobrazí pouze hodnoty z polí name, platforms, genres a price.

### Profilování vyhledávání

```
FT.PROFILE 'idx_games' SEARCH QUERY '@platforms:(mac|linux) -@platforms:(windows)'
```

Slouží k ladění dotazu – zobrazuje rozpis toho jak Redis vyhodnocuje a optimalizuje hledání.

### Vyhledávání s AND, řazením a limitací počtu výsledků

```
FT.SEARCH 'idx_games' '@steamspy_tags: VR @steamspy_tags: horror @price:[0, 30]' SORTBY release_date DESC LIMIT 0 10 RETURN 5 name release_date platforms steamspy_tags price
```

Vyhledá hry, které:
- V poli steamspy_tags obsahují VR a horror
- Cena je od 0 do 30

Výsledky budou seřazené podle data vydání a vyhledá se pouze prvních 10. Výstup bude obsahovat hodnoty z 5 polí.

## Agregační funkce (RediSearch)

### Počet vydaných her a jejich hodnocení jednotlivých vývojářů

```
FT.AGGREGATE idx_games "*" 
  GROUPBY 1 @developer 
  REDUCE COUNT 0 AS game_count 
  REDUCE SUM 1 @positive_ratings AS total_positive 
  REDUCE SUM 1 @negative_ratings AS total_negative 
  APPLY "(@total_positive / (@total_positive + @total_negative)) * 100" AS positive_ratio 
  FILTER "@game_count > 0" 
  SORTBY 2 @game_count DESC
```

Zjistí hodnocení her podle vývojáře:
- Seskupí podle vývojáře
- Vypočítá počet her pro vývojáře
- Sečte počet pozitivních hodnocení
- Sečte počet negativních hodnocení
- Spočítá procentuální hodnocení
- Zobrazí pouze vývojáře s nějakou hrou
- Seřadí podle počtu her

### Počet vydaných her jednotlivých vývojářů každý rok a jejich průměrná cena

```
FT.AGGREGATE idx_games "*" 
  APPLY "substr(@release_date, 0, 4)" AS release_year 
  GROUPBY 2 @release_year @developer 
  REDUCE COUNT 0 AS game_count 
  REDUCE AVG 1 @price AS avg_price     
  SORTBY 4 @release_year ASC @game_count DESC
```

Zjistí statistky vydaných her podle roku a vývojáře:
- Získá rok vydání z datumu
- Seskupí podle roku a vývojáře
- Spočítá hry
- Vypočítá průměrnou cenu
- Seřadí vzestupně podle roku a sestupně podle ceny

### Průměrný herní čas podle vývojáře

```
FT.AGGREGATE idx_games "*" 
  GROUPBY 1 @developer    
  REDUCE AVG 1 @average_playtime AS avg_playtime_minutes 
  APPLY "@avg_playtime_minutes / 60" AS avg_playtime_hours 
  SORTBY 2 @avg_playtime_hours DESC
```

Zjistí průměrnou dobu hraní podle vývojáře:
- Seskupí hry podle vývojáře
- Vypočítá průměr v minutách
- Převede průměr na hodiny
- Seřadí sestupně podle hodin

### Počet her podle rozsahu počtu majitelů

```
FT.AGGREGATE idx_games "*" GROUPBY 1 @owners REDUCE COUNT 0 AS total_games SORTBY 2 @total_games DESC
```

Ukáže, kolik her spadá do jednotlivých rozsahů počtu majitelů:
- Seskupí podle počtu zakoupení
- Spočítá počet výskytů ve skupině
- Setřídí sestupně podle počtu her

### Nejvyšší cena hry podle vývojáře

```
FT.AGGREGATE idx_games "*" 
  GROUPBY 1 @developer 
  REDUCE MAX 1 @price AS max_price 
  SORTBY 2 @max_price DESC
```

Pro každého vývojáře dohledá jeho nejdražší hru:
- Seskupí hry podle vývojáře
- Najde maximum
- Seřadí sestupně

### Profilování agregace

```
FT.PROFILE 'idx_games' AGGREGATE QUERY "*" 
  GROUPBY 1 @developer 
  REDUCE MAX 1 @price AS max_price 
  SORTBY 2 @max_price DESC
```

Profilování AGGREGATE dotazu. Vrátí informace o tom, jak dlouho dotaz trval, nebo jak dlouho trvala jednotlivá část dotazu.

## Cluster příkazy

### Informace o clusteru

```
CLUSTER INFO
```

Zobrazí informace o clusteru jako celku. Signalizuje například status cluster (ok/fail), případně i chybějící jednotlivé sloty.

### Uzly clusteru

```
CLUSTER NODES
```

Vypíše seznam nodů v clusteru, u každého uvede, zda se jedná o master nebo slave a jaký je jeho status.

### Identifikace slotu klíče

```
CLUSTER KEYSLOT steam:{1000370}
```

Dotaz vrátí příslušný slot, do kterého klíč náleží.

### Zobrazení běžící konfigurace

```
CONFIG GET cluster*
```

Příkaz vypíše aktuální nastavení clusteru.

### Přesunutí slotu v rámci clusteru

```
CLUSTER SETSLOT <SLOT> NODE <NODE ID>
```

Příkaz přiřadí slot jiné node. Vhodné pro vyvažování zátěže nebo přesun dat mezi uzly.

### Status replikace

```
INFO REPLICATION
```

Zobrazí status replikace aktuální node.