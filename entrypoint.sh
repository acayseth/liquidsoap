#!/bin/bash
set -e

echo "========================================="
echo "Liquidsoap Radio - Starting..."
echo "========================================="

# Create necessary directories
echo "Creating directories..."
mkdir -p /app/storage/songs
mkdir -p /app/storage/jingles
mkdir -p /app/storage/playlists
mkdir -p /var/log/liquidsoap

# Generate songs playlist from storage
echo "Generating songs playlist..."
if [ -d "/app/storage/songs" ]; then
    SONG_COUNT=$(find /app/storage/songs -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" \) 2>/dev/null | wc -l)

    if [ "$SONG_COUNT" -gt 0 ]; then
        find /app/storage/songs -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" \) > /app/storage/playlists/songs.m3u
        echo "✓ Found $SONG_COUNT songs"
        echo "✓ Playlist saved to /app/storage/playlists/songs.m3u"
    else
        echo "⚠ WARNING: No audio files found in /app/storage/songs"
        echo "⚠ Creating empty playlist"
        touch /app/storage/playlists/songs.m3u
    fi
else
    echo "⚠ WARNING: /app/storage/songs directory not found"
    echo "⚠ Creating empty playlist"
    touch /app/storage/playlists/songs.m3u
fi

# Generate jingles playlist if directory exists
echo "Generating jingles playlist..."
if [ -d "/app/storage/jingles" ]; then
    JINGLE_COUNT=$(find /app/storage/jingles -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" \) 2>/dev/null | wc -l)

    if [ "$JINGLE_COUNT" -gt 0 ]; then
        find /app/storage/jingles -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" \) > /app/storage/playlists/jingles.m3u
        echo "✓ Found $JINGLE_COUNT jingles"
    else
        echo "ℹ No jingles found (optional)"
        touch /app/storage/playlists/jingles.m3u
    fi
else
    echo "ℹ Jingles directory not found (optional)"
    touch /app/storage/playlists/jingles.m3u
fi

# Display configuration
echo ""
echo "Configuration:"
echo "  Stream Format: ${STREAM_FORMAT:-mp3}"
echo "  Bitrate: ${STREAM_BITRATE:-320} kbps"
echo "  Samplerate: ${STREAM_SAMPLERATE:-44100} Hz"
echo "  Icecast: ${ICECAST_HOST:-icecast}:${ICECAST_PORT:-8000}"
echo "  Mount: /${ICECAST_MOUNT:-stream}"
echo "  Discogs API: ${DISCOGS_ENABLED:-false}"
echo ""

# Display playlist summary
echo "Playlist Summary:"
echo "  Songs: $(wc -l < /app/storage/playlists/songs.m3u) tracks"
echo "  Jingles: $(wc -l < /app/storage/playlists/jingles.m3u) tracks"
echo ""

echo "========================================="
echo "Starting Liquidsoap..."
echo "========================================="

# Execute liquidsoap with all arguments
exec liquidsoap "$@"
