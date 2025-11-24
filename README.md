# Liquidsoap Radio Streaming Setup

Configurație completă pentru un server de streaming radio folosind Liquidsoap și Icecast.

## 📋 Cuprins

- [Structura Proiectului](#structura-proiectului)
- [Cum Funcționează](#cum-funcționează)
- [Configurare](#configurare)
- [Rulare](#rulare)
- [Gestionarea Playlist-urilor](#gestionarea-playlist-urilor)
- [Live Streaming (DJ)](#live-streaming-dj)
- [Metadate și Album Covers](#metadate-și-album-covers)
- [Control și Monitoring](#control-și-monitoring)

## 📁 Structura Proiectului

```
liquidsoap/
├── Dockerfile              # Container Docker pentru Liquidsoap
├── environment.liq         # Variabile de configurare
├── funcs.liq              # Funcții pentru procesare metadata
├── stream.liq             # Configurația principală de streaming
├── .env.example           # Exemplu de variabile de environment
```

## 🔄 Cum Funcționează

### Pas cu Pas - Fluxul de Streaming

#### 1. **Inițializare și Configurare**

```
stream.liq pornește
    ↓
Încarcă environment.liq (variabile de configurare)
    ↓
Încarcă funcs.liq (funcții pentru metadata)
    ↓
Configurează logging, telnet, audio settings
```

#### 2. **Crearea Surselor Audio**

```
┌─────────────────────────────────────────────┐
│ SURSE AUDIO                                 │
├─────────────────────────────────────────────┤
│                                             │
│  1. Songs Playlist                          │
│     - Citește: /app/storage/playlists/songs.m3u │
│     - Mode: randomize (shuffle)             │
│     - Reload: watch (auto-reload la modificări) │
│                                             │
│  2. Jingles Playlist                        │
│     - Citește: /app/storage/playlists/jingles.m3u │
│     - Mode: randomize (shuffle)             │
│     - Metadata hardcodat: "Jingle" / ""     │
│                                             │
│  3. Music (Rotație)                         │
│     - Combină: 1 jingle la fiecare 3 melodii │
│     - Weights: [1, 3] (jingles, songs)      │
│                                             │
│  4. Live Input (Harbor)                     │
│     - Port: 8001 (configurable)             │
│     - Acceptă conexiuni de la DJ software   │
│     - Autentificare: user/password          │
└─────────────────────────────────────────────┘
```

#### 3. **Fallback Logic**

```
┌──────────────────────────────────────┐
│ PRIORITATE SURSE                     │
├──────────────────────────────────────┤
│                                      │
│  1. LIVE (prioritate maximă)         │
│     ↓                                │
│  Dacă nu e activ...                  │
│     ↓                                │
│  2. MUSIC (playlist + jingles)       │
│                                      │
└──────────────────────────────────────┘

Când un DJ se conectează live:
  → Stream-ul trece automat la Live

Când DJ-ul se deconectează:
  → Stream-ul revine automat la Music
```

#### 4. **Procesarea Metadatelor (ID3 → ICY)**

**⚠️ Important: Conversie metadata ID3v2 → ICY**

Liquidsoap citește **ID3v2 tags** din fișierele MP3 și le convertește în format **ICY metadata** pentru streaming:

```
┌─────────────────────────────────────────────────┐
│ Fișier MP3 cu ID3v2 tags                        │
├─────────────────────────────────────────────────┤
│ • TIT2 (Title): "Clouds"                        │
│ • TPE1 (Artist): "Sasha"                        │
│ • TALB (Album): "Airdrawndagger"                │
│ • COMM (Comment): "https://cover.jpg"           │
│ • APIC (Album Art): [binary image data]         │
└─────────────────────────────────────────────────┘
                    ↓
        Liquidsoap citește ID3v2
                    ↓
┌─────────────────────────────────────────────────┐
│ process_metadata(m)                             │
├─────────────────────────────────────────────────┤
│                                                 │
│ 1. Extrage ID3v2 tags:                          │
│    artist = m["artist"]  (din TPE1)             │
│    title = m["title"]    (din TIT2)             │
│    album = m["album"]    (din TALB)             │
│    comment = m["comment"] (din COMM)            │
│                                                 │
│ 2. Construiește ICY StreamTitle:                │
│    "Sasha - Clouds"                             │
│                                                 │
│ 3. Construiește ICY StreamUrl (prioritate):     │
│    a) coverart din APIC tag                     │
│    b) comment din COMM tag                      │
│    c) Discogs API (cu caching)                  │
│    d) radio_url (fallback)                      │
│                                                 │
│ 4. Returnează ICY metadata:                     │
│    [("StreamTitle", "Sasha - Clouds"),          │
│     ("StreamUrl", "https://...cover.jpg")]      │
└─────────────────────────────────────────────────┘
                    ↓
        ICY metadata trimisă la Icecast
                    ↓
┌─────────────────────────────────────────────────┐
│ Icecast embedează în stream                     │
├─────────────────────────────────────────────────┤
│ La fiecare 16000 bytes (icy-metaint):           │
│                                                 │
│ StreamTitle='Sasha - Clouds';                   │
│ StreamUrl='https://i.discogs.com/.../cover.jpg';│
└─────────────────────────────────────────────────┘
                    ↓
        Client primește metadata ICY
```

**Exemplu Discogs API Flow (cu caching):**

```
Prima redare a piesei:
  Artist: "Sasha", Title: "Clouds", Album: "Airdrawndagger"
      ↓
  Cache key: "Sasha|Clouds|Airdrawndagger"
      ↓
  Check cache: NU există
      ↓
  Construiește query: "artist:Sasha release_title:Airdrawndagger"
      ↓
  curl + jq → API request la Discogs
      ↓
  Parse JSON: .results[0].cover_image
      ↓
  Cover URL: "https://i.discogs.com/.../cover.jpg"
      ↓
  Salvează în cache: "Sasha|Clouds|Airdrawndagger" → URL
      ↓
  Log: "Discogs: Found cover for Sasha - Clouds"

A doua redare (aceeași piesă):
  Cache key: "Sasha|Clouds|Airdrawndagger"
      ↓
  Check cache: DA există! ✅
      ↓
  Return instant din cache (NO API REQUEST)
      ↓
  Log: "Discogs: Using cached cover for Sasha - Clouds"
```

**Mapare completă ID3v2 → ICY:**

| ID3v2 Tag | Liquidsoap Key | ICY Metadata       | Exemplu          |
| --------- | -------------- | ------------------ | ---------------- |
| TIT2      | `title`        | StreamTitle        | "Clouds"         |
| TPE1      | `artist`       | StreamTitle        | "Sasha"          |
| TALB      | `album`        | _(pentru Discogs)_ | "Airdrawndagger" |
| COMM      | `comment`      | StreamUrl          | "https://..."    |
| APIC      | `coverart`     | StreamUrl          | _(binary → URL)_ |

#### 5. **Procesare Audio**

```
Source cu metadata
    ↓
┌────────────────────────┐
│ PROCESARE AUDIO        │
├────────────────────────┤
│                        │
│ 1. Normalize           │
│    - Echilibrează      │
│      volumul           │
│    - gain_max: 3dB     │
│    - gain_min: -3dB    │
│                        │
│ 2. Crossfade           │
│    - Tranziții smooth  │
│      între piese       │
│    - Duration: 3s      │
│                        │
└────────────────────────┘
    ↓
Stream procesat
```

#### 6. **Output la Icecast**

```
Stream procesat
    ↓
┌──────────────────────────────────┐
│ output.icecast()                 │
├──────────────────────────────────┤
│                                  │
│ Encoder: Configurable            │
│ (MP3/Vorbis/Opus)                │
│ Bitrate: Configurable            │
│                                  │
│ Server: icecast_host:port        │
│ Mount: /stream                   │
│                                  │
│ Metadata incluse:                │
│  - StreamTitle                   │
│  - StreamUrl                     │
│  - Radio name, genre, etc.       │
│                                  │
└──────────────────────────────────┘
    ↓
Stream disponibil la:
http://icecast:8000/stream
```

### 🔄 Ciclul Complet

```
┌─────────────┐
│   START     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Load Config (environment.liq)           │
│ - Icecast settings                      │
│ - Radio info                            │
│ - API tokens                            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Load Functions (funcs.liq)              │
│ - get_discogs_cover()                   │
│ - process_metadata()                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Create Sources                          │
│ - Songs playlist                        │
│ - Jingles playlist (+ metadata override)│
│ - Rotate (1 jingle / 3 songs)           │
│ - Live input (harbor)                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Fallback Setup                          │
│ [live, music]                           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Process Metadata                        │
│ - Extract artist/title/album            │
│ - Format StreamTitle                    │
│ - Fetch StreamUrl (Discogs API?)        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Audio Processing                        │
│ - Normalize volume                      │
│ - Crossfade transitions                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Output to Icecast                       │
│ - Encode based on STREAM_FORMAT         │
│ - Send to icecast:8000/stream           │
│ - Include all metadata                  │
└──────────────┬──────────────────────────┘
               │
               ▼
       ┌───────────────┐
       │ 🎵 STREAMING  │
       └───────────────┘
```

## ⚙️ Configurare

### 1. Copiază fișierul de configurare

```bash
cp .env.example .env
```

### 2. Editează variabilele în `.env`

#### 🎵 Formate Audio Suportate

Poți alege între 3 formate de encoding:

| Format           | Calitate  | Compatibilitate                    | Recomandare                        |
| ---------------- | --------- | ---------------------------------- | ---------------------------------- |
| **MP3**          | Bună      | ✅ Maximă (toate device-urile)     | General purpose                    |
| **Vorbis** (OGG) | Excelentă | ✅ Bună (majoritatea browser-elor) | Calitate superioară la bitrate mic |
| **Opus**         | Excelentă | ⚠️ Modernă (browsere noi)          | Streaming low-latency              |

**Configurare format:**

```bash
# MP3 (recomandat pentru compatibilitate maximă)
STREAM_FORMAT=mp3
STREAM_BITRATE=320
STREAM_SAMPLERATE=44100

# Vorbis/OGG (calitate superioară)
STREAM_FORMAT=vorbis
STREAM_BITRATE=256
STREAM_SAMPLERATE=48000

# Opus (modern, low-latency)
STREAM_FORMAT=opus
STREAM_BITRATE=192
STREAM_SAMPLERATE=48000
```

**Recomandări bitrate:**

| Format | Low | Medium | High | Lossless-like |
| ------ | --- | ------ | ---- | ------------- |
| MP3    | 128 | 192    | 256  | 320           |
| Vorbis | 96  | 160    | 224  | 320           |
| Opus   | 64  | 96     | 128  | 192           |

```bash
# Icecast Server Configuration
ICECAST_HOST=icecast
ICECAST_PORT=8000
ICECAST_PASSWORD=your_password_here
ICECAST_MOUNT=stream

# Radio Station Information
RADIO_NAME=My Radio Station
RADIO_DESCRIPTION=The Best Radio Ever
RADIO_GENRE=Electronic
RADIO_URL=http://myradio.com

# Harbor (Live Input) Configuration
HARBOR_ENABLED=true
HARBOR_PORT=8001
HARBOR_PASSWORD=dj_password_here
HARBOR_USER=source

# Telnet Server Configuration
TELNET_ENABLED=true
TELNET_PORT=1234

# Discogs API Configuration (opțional)
DISCOGS_ENABLED=true
DISCOGS_TOKEN=your_discogs_token_here
```

### 3. Obține Discogs API Token (Opțional)

1. Creează cont pe [Discogs.com](https://www.discogs.com)
2. Mergi la: Settings → Developers
3. Generează un Personal Access Token
4. Adaugă token-ul în `.env`:
   ```bash
   DISCOGS_ENABLED=true
   DISCOGS_TOKEN=your_token_here
   ```

## 🚀 Rulare

### Cu Docker

```bash
# Build imaginea
docker build -t liquidsoap-radio .

# Rulează containerul
docker run -d \
  --name liquidsoap \
  -p 8001:8001 \
  -p 1234:1234 \
  -v /path/to/your/music:/app/storage/songs:ro \
  -v /path/to/your/jingles:/app/storage/jingles:ro \
  --env-file .env \
  liquidsoap-radio
```

**Volume mounts:**

- `/app/storage/songs` - Mount biblioteca ta de muzică (read-only)
  - La start, containerul scanează automat pentru `.mp3`, `.flac`, `.aac`, `.ogg`, `.m4a`
  - Generează automat `/app/storage/playlists/songs.m3u`
- `/app/storage/jingles` - Mount jingles-uri (opțional, read-only)
  - Generează automat `/app/storage/playlists/jingles.m3u`
- `/app/storage/playlists` - Playlist-uri generate (poate fi persistent cu volume)

### Cu Docker Compose

```yaml
version: "3"
services:
  liquidsoap:
    build: .
    container_name: liquidsoap
    ports:
      - "8001:8001" # Harbor (Live input)
      - "1234:1234" # Telnet
    volumes:
      - /path/to/your/music:/app/storage/songs:ro # Your music library
      - /path/to/your/jingles:/app/storage/jingles:ro # Jingles (optional)
    env_file:
      - .env
    restart: unless-stopped
```

```bash
docker-compose up -d
```

### 🎵 Generare Automată Playlist la Start

Când containerul pornește, `entrypoint.sh` va:

1. **Scana directorul `/app/storage/songs`** pentru fișiere audio
2. **Scana directorul `/app/storage/jingles`** pentru jingles
3. **Formate suportate:** `.mp3`, `.flac`, `.aac`, `.ogg`, `.m4a`
4. **Generează automat:**
   - `/app/storage/playlists/songs.m3u`
   - `/app/storage/playlists/jingles.m3u`
5. **Afișează statistici:**

   ```
   ✓ Found 1523 songs
   ✓ Playlist saved to /app/storage/playlists/songs.m3u
   ✓ Found 12 jingles

   Playlist Summary:
     Songs: 1523 tracks
     Jingles: 12 tracks
   ```

**Avantaje:**

- ✅ Zero configurare manuală
- ✅ Scanare recursivă (toate subdirectoarele)
- ✅ Playlist-ul se actualizează la restart
- ✅ Suport pentru multiple formate audio
- ✅ Mount-uri separate pentru songs și jingles

**Manual playlist update:**

```bash
# Regenerează playlist-ul fără restart
docker exec liquidsoap bash -c "find /app/storage/songs -type f \( -name '*.mp3' -o -name '*.flac' -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \) > /app/storage/playlists/songs.m3u"
```

## 🎵 Gestionarea Playlist-urilor

### Structura directoarelor

```bash
/app/storage/           # Container storage (toate în /app/storage)
├── songs/              # ← Mount extern: biblioteca ta de muzică
│   ├── Artist1/
│   │   ├── Album1/
│   │   │   ├── track1.mp3
│   │   │   └── track2.flac
│   │   └── Album2/
│   │       └── track3.aac
│   └── Artist2/
│       └── song.ogg
│
├── jingles/            # ← Mount extern: jingles-uri (opțional)
│   ├── jingle1.mp3
│   └── jingle2.mp3
│
└── playlists/          # ← Generated automatically la start
    ├── songs.m3u       # Auto-generat din /app/storage/songs
    └── jingles.m3u     # Auto-generat din /app/storage/jingles
```

### Mod de lucru

**Auto-generare (Recomandat)**

```bash
# Mount bibliotecile tale
docker run -d \
  -v /home/user/Music:/app/storage/songs:ro \
  -v /home/user/Jingles:/app/storage/jingles:ro \
  liquidsoap-radio

# La start, containerul generează automat:
# - songs.m3u (din /app/storage/songs)
# - jingles.m3u (din /app/storage/jingles)
# Scanează recursiv toate subdirectoarele
# Formate: mp3, flac, aac, ogg, m4a
```

**Playlist manual (opțional)**

```bash
# Poți crea și manual playlist-uri custom
docker exec liquidsoap vi /app/storage/playlists/songs.m3u
```

### Crearea playlist-urilor

**songs.m3u:**

```
/app/storage/songs/track1.mp3
/app/storage/songs/track2.mp3
/app/storage/songs/track3.mp3
```

**jingles.m3u:**

```
/app/storage/jingles/jingle1.mp3
/app/storage/jingles/jingle2.mp3
```

### Auto-reload

Playlist-urile sunt monitorizate automat. Când modifici un fișier `.m3u`, Liquidsoap îl va reîncărca automat.

### Script pentru generare automată

```bash
#!/bin/bash
# generate_playlists.sh

# Generează songs.m3u
find /app/storage/songs -name "*.mp3" > /app/storage/playlists/songs.m3u

# Generează jingles.m3u
find /app/storage/jingles -name "*.mp3" > /app/storage/playlists/jingles.m3u

echo "Playlists generated!"
```

## 🎙️ Live Streaming (DJ)

### Conectare cu DJ Software

**Setări pentru Mixxx / Virtual DJ / Traktor:**

- **Host:** `localhost` (sau IP-ul serverului)
- **Port:** `8001`
- **Mount:** `live.mp3`
- **User:** `source`
- **Password:** (valoarea din `HARBOR_PASSWORD`)
- **Format:** MP3
- **Bitrate:** 128kbps sau mai mult

### Conectare cu ffmpeg

```bash
ffmpeg -re -i input.mp3 -codec:a libmp3lame -b:a 192k \
  -f mp3 icecast://source:your_password@localhost:8001/live.mp3
```

### Comportament

- Când DJ-ul se conectează → stream-ul trece automat la Live
- Când DJ-ul se deconectează → stream-ul revine la playlist automat
- Zero downtime!

## 🎨 Metadate și Album Covers

### 📡 Cum primesc clienții metadata (ID3v2 → ICY)

**Conversie automată:**

- **Input:** Fișiere MP3 cu **ID3v2 tags** (TIT2, TPE1, TALB, COMM, APIC)
- **Processing:** Liquidsoap extrage și procesează metadata
- **Output:** Stream cu **ICY metadata** (StreamTitle, StreamUrl)

**Flux pentru clienți noi:**

```
1. Client conectează la http://icecast:8000/stream
   ↓
2. Icecast trimite HTTP headers:
   icy-name: Radio Dream
   icy-genre: Various
   icy-metaint: 16000  ← metadata la fiecare 16KB
   ↓
3. Client primește IMEDIAT metadata curentă:
   StreamTitle='Sasha - Clouds';
   StreamUrl='https://i.discogs.com/.../cover.jpg';
   ↓
4. La schimbarea piesei:
   → Liquidsoap trimite metadata nouă
   → Icecast o embedează în stream (la byte 16000)
   → Toți clienții actualizați SIMULTAN
```

**Configurații importante:**

- `icy_metadata="true"` - activează ICY protocol
- `insert_metadata(radio)` - asigură refresh periodic
- `public=true` - vizibilitate în directoare

### Ordinea de prioritate pentru StreamUrl

1. **Tag `coverart`** (APIC) în fișierul MP3
2. **Tag `comment`** (COMM) în fișierul MP3 (poate conține URL)
3. **Discogs API** (căutare automată cu caching)
4. **Radio URL** (fallback)

### 🗄️ Caching Discogs API

**Problemă:** Fără cache, fiecare redare = request nou la Discogs API

**Soluție:** Cache în memorie cu key `"Artist|Title|Album"`

**Performanță:**

```
Playlist cu 100 melodii:

FĂRĂ cache:
  Redare 1: 100 requests ❌
  Redare 2: 100 requests ❌
  Redare 3: 100 requests ❌
  Total: 300+ requests

CU cache:
  Redare 1: 100 requests ✅
  Redare 2: 0 requests (din cache) ✅
  Redare 3: 0 requests (din cache) ✅
  Total: 100 requests (70% reducere!)
```

**În log-uri:**

```
# Prima redare
Discogs: Found cover for Sasha - Clouds: https://...

# A doua redare
Discogs: Using cached cover for Sasha - Clouds
```

**Caracteristici:**

- ✅ Cache persistent pe durata rulării
- ✅ Negative caching (cache-uiește și rezultate goale)
- ✅ Respectă API rate limits (60 req/min)
- ✅ Zero latență pentru metadata din cache

### Adăugare metadata în MP3

```bash
# Cu ffmpeg - adaugă URL în comment
ffmpeg -i input.mp3 -metadata comment="https://example.com/cover.jpg" \
  -codec copy output.mp3

# Cu id3v2
id3v2 --comment "https://example.com/cover.jpg" song.mp3
```

### Format StreamTitle și StreamUrl

```json
{
  "StreamTitle": "Artist - Title",
  "StreamUrl": "https://i.discogs.com/.../cover.jpg"
}
```

### Metadata pentru Jingles

Jingles-urile au metadata hardcodată:

```json
{
  "StreamTitle": "Jingle",
  "StreamUrl": ""
}
```

## 🔧 Control și Monitoring

### Telnet Interface

Conectare:

```bash
telnet localhost 1234
```

Comenzi utile:

```
# Vezi statusul
request.metadata

# Skip la următoarea piesă
skip

# Vezi sursa curentă
sources

# Ajutor
help
```

### Log-uri

```bash
# Vezi log-urile în timp real
docker logs -f liquidsoap

# Log file în container
/var/log/liquidsoap/stream.log
```

### Verificare stream

```bash
# Testează stream-ul
curl -I http://localhost:8000/stream

# Ascultă cu mpv
mpv http://localhost:8000/stream

# Ascultă cu ffplay
ffplay http://localhost:8000/stream
```

## 🐛 Troubleshooting

### Stream-ul nu pornește

1. Verifică că Icecast rulează și este accesibil
2. Verifică credentialele în `.env`
3. Verifică log-urile: `docker logs liquidsoap`

### Nu are metadata

1. Verifică că fișierele MP3 au tag-uri ID3
2. Verifică log-urile pentru erori Discogs API
3. Testează manual cu: `ffprobe song.mp3`

### Playlist-ul nu se reîncarcă

1. Verifică permisiunile pe directorul `storage/`
2. Verifică că `.m3u` conține căi absolute corecte
3. Restart container: `docker restart liquidsoap`

### Playlist-ul jingles.m3u este gol

**Comportament:**

- Stream-ul va continua fără probleme
- Va reda doar melodii (fără jingles)
- În log-uri vei vedea: `WARNING: Jingles playlist empty or unavailable, playing songs only`

**Flux de fallback:**

```
jingles.m3u gol sau lipsă
    ↓
mksafe(jingles) → protejează de erori
    ↓
rotate([jingles_safe, songs]) → încearcă rotație
    ↓
Dacă jingles_safe FAILED
    ↓
fallback → songs only ✅
    ↓
Stream continuă normal (doar melodii)
```

**Rezolvare:**

1. Adaugă fișiere MP3 în `/app/storage/jingles/`
2. Actualizează `jingles.m3u`:
   ```
   /app/storage/jingles/jingle1.mp3
   /app/storage/jingles/jingle2.mp3
   ```
3. Liquidsoap va reîncărca automat și va începe rotația

**Nu este necesar restart!** Playlist-urile se monitorizează automat.

### Live input nu funcționează

1. Verifică că `HARBOR_ENABLED=true` în `.env`
2. Verifică că portul 8001 este deschis
3. Verifică parola în DJ software
4. Verifică că formatul este MP3

### Dezactivare Harbor (live input)

Dacă nu ai nevoie de live streaming, poți dezactiva Harbor:

```bash
HARBOR_ENABLED=false
```

Acest lucru va:

- Dezactiva portul 8001
- Reduce consumul de resurse
- Stream-ul va reda doar playlist-uri (songs + jingles)

### Dezactivare Telnet

Dacă nu ai nevoie de control telnet, poți dezactiva:

```bash
TELNET_ENABLED=false
```

### Configurare Log Level

Ajustează nivelul de logging (1=critical, 2=severe, 3=important, 4=info, 5=debug):

```bash
LOG_LEVEL=4  # Default: info
LOG_LEVEL=2  # Minimal: doar erori severe
LOG_LEVEL=5  # Maxim: debug complet
```

## 📚 Referințe

- [Liquidsoap Documentation](https://www.liquidsoap.info/doc.html)
- [Icecast Documentation](https://icecast.org/docs/)
- [Discogs API](https://www.discogs.com/developers)

## 📝 License

MIT
