FROM savonet/liquidsoap:v2.3.3

ENV ICECAST_HOST=icecast \
    ICECAST_PORT=8000 \
    ICECAST_PASSWORD=hackme \
    ICECAST_MOUNT=stream \
    ICECAST_MOUNT_HQ=stream-hq \
    RADIO_NAME="Radio Dream" \
    RADIO_DESCRIPTION="Radio Dream Stream" \
    RADIO_GENRE=Various \
    RADIO_URL=http://localhost:8000 \
    HARBOR_PORT=8001 \
    HARBOR_PASSWORD=hackme \
    HARBOR_USER=source \
    TELNET_ENABLED=true \
    TELNET_PORT=1234 \
    LOG_FILE_ENABLED=true \
    LOG_FILE_PATH=/var/log/liquidsoap/stream.log \
    LOG_LEVEL=4 \
    DISCOGS_ENABLED=false \
    DISCOGS_TOKEN="" \
    STREAM_FORMAT=mp3 \
    STREAM_BITRATE=320 \
    STREAM_SAMPLERATE=44100 \
    AUDIO_SAMPLERATE=44100 \
    AUDIO_CHANNELS=2

RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY environment.liq funcs.liq stream.liq entrypoint.sh ./

RUN chmod +x stream.liq entrypoint.sh

EXPOSE 8001 1234

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/stream.liq"]
