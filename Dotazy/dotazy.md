# Dotazy

## Práce s daty

### Insert

```bash
HSET steam:{2000000} appid 2000000 name "UHK Simulator" release_date "2025-01-01" english 1 developer "ltrk.dev" publisher "UHK" platforms "windows,linux" price 6.9
```

Vytvoření nové hashmap hodnoty pod klíčem `steam:{2000000}`.

### Update hodnoty

```bash
HSET steam:{2000000} name "Simulator UHK"
```

Přejmenování hry `steam:{2000000}` na „Simulator UHK“.

### Smazání hodnoty

```bash
HDEL steam:{2000000} price
```

Odstranění pole `price` od klíče `steam:{2000000}`.

### Přejmenování klíče

```bash
RENAME steam:{2000000} steam:{2000001}
```

Přejmenování klíče ze `steam:{2000000}` na `steam:{2000001}`.

### Nastavení expirace

```bash
EXPIRE steam:{2000000}_copy 60
```

Nastaví expiraci klíče na 60 sekund.

### Kopírování klíče

```bash
COPY steam:{2000000} steam:{2000000}:backup
```

Vytvoří kopii klíče pod zadaným klíčem. Nelze mezi shardy.

## Indexy (RediSearch)

### Vytvoření indexu

```bash
FT.CREATE idx_games ON HASH PREFIX 1 "steam:{" SCHEMA name TEXT SORTABLE developer TEXT SORTABLE price NUMERIC SORTABLE genres TEXT
```
Vytvoření indexu idx_games nad klíči začínající na „steam:{“. V klíči se indexují pole name, developer, price a genres. Hodnoty name, developer a price jdou i řadit.

### Výpis existujících indexů

```bash
FT._LIST
```
Výpis všech existujících indexů.

### Zobrazení detailů indexu

```bash
FT.INFO idx_games
```
Vrátí nastavení konkrétního indexu.

### Smazání indexu

```bash
FT.DROPINDEX idx_games
```
Odstraní index.

### Smazání indexu a dat

```bash
FT.DROPINDEX idx_games DD
```
Odstraní index a smaže i hodnoty klíče kterých se index týkal.

### Úprava indexu

```bash
FT.ALTER 'idx_games' SCHEMA ADD release_date TEXT SORTABLE
```
Přidání dalšího sloupce do indexu.

## Filtrování (RediSearch)

### Fulltextové vyhledávání v textu a řazení

```bash
FT.SEARCH idx_games "@name: simulator" SORTBY price DESC
```
Vyhledání všech her obsahující slovo „simulator“ v názvu seřazených od nejdražšího po nejlevnější.
### Fulltext vyhledávání a filtrování podle rozsahu

```bash
FT.SEARCH 'idx_games' '@genres:(simulator) @price:[0, 10]'
```
Vyhledání všech her v kategorii simulátor v cenovém rozmezí od 0 do 10 USD.
### Fulltext vyhledávání s negací

```bash
FT.SEARCH 'idx_games' '+@platforms:mac @genres:(racing) -@platforms:linux' RETURN 3 name platforms genres
```
Dotaz vrátí název, platformy a žánry všech závodní her dostupných na MacOS a nedostupných na Linuxu.
### Vyhledávání s OR

```bash
FT.SEARCH 'idx_games' '@platforms:(mac|linux) -@platforms:(windows)' RETURN 4 name platforms genres price
```
Dotaz vrátí název, platformy, žánry a cenu her dostupných pro MacOS nebo Linux a nedostupných na Windows.

### Profilování vyhledávání

```bash
FT.PROFILE 'idx_games' SEARCH QUERY '@platforms:(mac|linux) -@platforms:(windows)'
```
Profilování SEARCH dotazu. Vrátí informace o tom, jak dlouho dotaz trval, nebo jak dlouho trvala jednotlivá část dotazu.

### Vyhledávání s AND, řazením a limitací počtu výsledků

```bash
FT.SEARCH 'idx_games' '@steamspy_tags: VR @steamspy_tags: horror @price:[0, 30]' SORTBY release_date DESC LIMIT 0 10 RETURN 5 name release_date platforms steamspy_tags price
```
Vrátí jméno, datum vydání, platformy, tagy a cenu prvních 10 VR horrorových her do 30 USD seřazených od nejnovější.

## Agregační funkce (RediSearch)

### Počet vydaných her a jejich hodnocení jednotlivých vývojářů

```bash
FT.AGGREGATE idx_games "*"
  GROUPBY 1 @developer
  REDUCE COUNT 0 AS game_count
  REDUCE SUM 1 @positive_ratings AS total_positive
  REDUCE SUM 1 @negative_ratings AS total_negative
  APPLY "(@total_positive / (@total_positive + @total_negative)) * 100" AS positive_ratio
  FILTER "@game_count > 0"
  SORTBY 2 @game_count DESC
```
Zjistí počet her od každého vývojáře, součet pozitivních/negativních hodnocení a vypočte podíl pozitivních v procentech.

### Počet vydaných her jednotlivých vývojářů každý rok a jejich průměrná cena

```bash
FT.AGGREGATE idx_games "*"
  APPLY "substr(@release_date, 0, 4)" AS release_year
  GROUPBY 2 @release_year @developer
  REDUCE COUNT 0 AS game_count
  REDUCE AVG 1 @price AS avg_price
  SORTBY 4 @release_year ASC @game_count DESC
```
Ukáže počet a průměrnou cenu her podle roku vydání a jména vývojáře, setříděno podle roku a počtu.

### Průměrný herní čas podle vývojáře

```bash
FT.AGGREGATE idx_games "*"
  GROUPBY 1 @developer
  REDUCE AVG 1 @average_playtime AS avg_playtime_minutes
  APPLY "@avg_playtime_minutes / 60" AS avg_playtime_hours
  SORTBY 2 @avg_playtime_hours DESC
```
Zjistí průměrný čas hraní (v hodinách) pro každého vývojáře a setřídí podle největšího průměru.

### Počet her podle rozsahu počtu majitelů

```bash
FT.AGGREGATE idx_games "*" GROUPBY 1 @owners REDUCE COUNT 0 AS total_games SORTBY 2 @total_games DESC
```
Ukáže, kolik her spadá do jednotlivých rozsahů počtu majitelů.

### Nejvyšší cena hry podle vývojáře

```bash
FT.AGGREGATE idx_games "*"
  GROUPBY 1 @developer
  REDUCE MAX 1 @price AS max_price
  SORTBY 2 @max_price DESC
```
Pro každého vývojáře dohledá jeho nejdražší hru.

### Profilování agregace

```bash
FT.PROFILE 'idx_games' AGGREGATE QUERY "*"
  GROUPBY 1 @developer
  REDUCE MAX 1 @price AS max_price
  SORTBY 2 @max_price DESC
```
Profilování AGGREGATE dotazu. Vrátí informace o tom, jak dlouho dotaz trval, nebo jak dlouho trvala jednotlivá část dotazu.

## Cluster příkazy

### Informace o clusteru

```bash
CLUSTER INFO
```
Zobrazí informace o clusteru jako celku. Signalizuje například status cluster (ok/fail), případně i chybějící jednotlivé sloty.

### Uzly clusteru

```bash
CLUSTER NODES
```
Vypíše seznam nodů v clusteru, u každého uvede zda se jedná o master nebo slave a jaký je jeho status.

### Identifikace slotu klíče

```bash
CLUSTER KEYSLOT steam:{1000370}
```
Dotaz vrátí příslušný slot, do kterého klíč náleží.

### Zobrazení běžící konfigurace

```bash
CONFIG GET cluster*
```
Příkaz vypíše aktuální nastavení clusteru. 

### Přesunutí slotu v rámci clusteru

```bash
CLUSTER SETSLOT <SLOT> NODE <NODE ID>
```
Příkaz přiřadí slot jiné node. Vhodné pro vyvažování zátěže nebo přesun dat mezi uzly.

### Status replikace

```bash
INFO REPLICATION
```
Zobrazí status replikace aktuální node.