# Liquidsoap Radio Streaming Setup

Configurație completă pentru un server de streaming radio folosind Liquidsoap 2.3.3 și Icecast.

## 📋 Cuprins

- [Caracteristici](#caracteristici)
- [Structura Proiectului](#structura-proiectului)
- [Configurare](#configurare)
- [Rulare](#rulare)
- [Gestionarea Playlist-urilor](#gestionarea-playlist-urilor)
- [Live Streaming (DJ)](#live-streaming-dj)
- [Metadate și Album Covers](#metadate-și-album-covers)
- [Control și Monitoring](#control-și-monitoring)
- [Troubleshooting](#troubleshooting)

## ✨ Caracteristici

- 🎵 **Playlist automat** - Songs + Jingles cu rotație configurabilă
- 🎙️ **Live streaming** - Harbor input pentru DJ-i (activare/dezactivare)
- 🎨 **Album covers** - Integrare Discogs API cu caching
- 🔄 **Auto-reload** - Playlist-uri monitorizate automat
- 🎚️ **Audio processing** - Normalize, compress, crossfade, blank skip
- 📡 **Multiple formate** - MP3, Vorbis (OGG), Opus
- 🔧 **Telnet control** - Control remote (activare/dezactivare)
- 📊 **Logging configurabil** - 5 niveluri de detaliu
- � **Dockenr ready** - Setup complet containerizat

## 📁 Structura Proiectului

```
liquidsoap/
├── Dockerfile              # Container Docker pentru Liquidsoap 2.3.3
├── stream.liq             # Configurația principală de streaming
├── entrypoint.sh          # Script de inițializare
├── .env.example           # Exemplu de variabile de environment
└── README.md              # Documentație
```

## ⚙️ Configurare

### 1. Copiază fișierul de configurare

```bash
cp .env.example .env
```

### 2. Editează variabilele în `.env`

#### 🎵 Formate Audio Suportate

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

#### 📝 Variabile de Configurare

```bash
# Icecast Server
ICECAST_HOST=icecast
ICECAST_PORT=8000
ICECAST_PASSWORD=your_password_here
ICECAST_MOUNT=stream

# Radio Station Information
RADIO_NAME=My Radio Station
RADIO_DESCRIPTION=The Best Radio Ever
RADIO_GENRE=Electronic
RADIO_URL=http://myradio.com

# Harbor (Live Input) - Activare/Dezactivare
HARBOR_ENABLED=true          # true = activat, false = dezactivat
HARBOR_PORT=8001
HARBOR_PASSWORD=dj_password_here
HARBOR_USER=source

# Telnet Server - Activare/Dezactivare
TELNET_ENABLED=true          # true = activat, false = dezactivat
TELNET_PORT=1234

# Logging (1=critical, 2=severe, 3=important, 4=info, 5=debug)
LOG_LEVEL=4

# Discogs API (opțional - pentru album covers)
DISCOGS_ENABLED=true
DISCOGS_TOKEN=your_discogs_token_here
```

### 3. Obține Discogs API Token (Opțional)

Pentru album covers automate:

1. Creează cont pe [Discogs.com](https://www.discogs.com)
2. Mergi la: Settings → Developers
3. Generează un **Personal Access Token** (User Token)
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

### Cu Docker Compose

```yaml
version: "3"
services:
  liquidsoap:
    build: .
    container_name: liquidsoap
    ports:
      - "8001:8001" # Harbor (Live input) - doar dacă HARBOR_ENABLED=true
      - "1234:1234" # Telnet - doar dacă TELNET_ENABLED=true
    volumes:
      - /path/to/your/music:/app/storage/songs:ro
      - /path/to/your/jingles:/app/storage/jingles:ro
    env_file:
      - .env
    restart: unless-stopped
```

```bash
docker-compose up -d
```

## 🎵 Gestionarea Playlist-urilor

### Generare Automată la Start

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

### Auto-reload

Playlist-urile sunt monitorizate automat. Când modifici un fișier `.m3u`, Liquidsoap îl va reîncărca automat fără restart.

### Regenerare Manuală

```bash
# Regenerează playlist-ul fără restart
docker exec liquidsoap bash -c "find /app/storage/songs -type f \( -name '*.mp3' -o -name '*.flac' -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \) > /app/storage/playlists/songs.m3u"
```

## 🎙️ Live Streaming (DJ)

### Activare/Dezactivare Harbor

```bash
# Activat (default) - permite live streaming
HARBOR_ENABLED=true

# Dezactivat - doar playlist-uri
HARBOR_ENABLED=false
```

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

### Discogs API Integration

Stream-ul caută automat album covers folosind Discogs API:

**Flux:**

1. Extrage artist, title, album din metadata MP3 (ID3v2 tags)
2. Caută în cache (evită request-uri duplicate)
3. Dacă nu e în cache, caută pe Discogs API
4. Salvează rezultatul în cache (persistent pe durata rulării)
5. Trimite cover URL ca `StreamUrl` în ICY metadata

**Performanță cu caching:**

```
Playlist cu 100 melodii:

FĂRĂ cache:
  Redare 1: 100 requests ❌
  Redare 2: 100 requests ❌
  Total: 200+ requests

CU cache:
  Redare 1: 100 requests ✅
  Redare 2: 0 requests (din cache) ✅
  Total: 100 requests (50% reducere!)
```

### Format Metadata ICY

```json
{
  "StreamTitle": "Artist - Title",
  "StreamUrl": "https://i.discogs.com/.../cover.jpg"
}
```

Clienții (VLC, Winamp, browsere) primesc automat metadata actualizată la fiecare piesă nouă.

## 🔧 Control și Monitoring

### Telnet Interface

**Activare/Dezactivare:**

```bash
# Activat (default)
TELNET_ENABLED=true
TELNET_PORT=1234

# Dezactivat
TELNET_ENABLED=false
```

**Conectare:**

```bash
telnet localhost 1234
```

**Comenzi utile:**

```
# Skip la următoarea piesă
skip

# Vezi sursa curentă
sources

# Ajutor
help

# Exit
exit
```

### Log-uri

**Configurare nivel logging:**

```bash
LOG_LEVEL=4  # Default: info
LOG_LEVEL=2  # Minimal: doar erori severe
LOG_LEVEL=5  # Maxim: debug complet
```

**Vizualizare log-uri:**

```bash
# Vezi log-urile în timp real
docker logs -f liquidsoap

# Ultimele 100 linii
docker logs --tail 100 liquidsoap
```

### Verificare Stream

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
- În log-uri: `WARNING: Jingles playlist empty or unavailable`

**Rezolvare:**

1. Adaugă fișiere MP3 în `/app/storage/jingles/`
2. Restart container sau regenerează playlist manual
3. Liquidsoap va reîncărca automat

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
