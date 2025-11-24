telnet_enabled = bool_of_string(environment.get("TELNET_ENABLED"))
telnet_port = int_of_string(environment.get("TELNET_PORT"))
log_level = int_of_string(environment.get("LOG_LEVEL"))

settings.server.telnet := telnet_enabled
settings.server.telnet.bind_addr := "0.0.0.0"
settings.server.telnet.port := telnet_port

settings.log.level := log_level
settings.log.stdout := true

icecast_host = environment.get("ICECAST_HOST")
icecast_port = int_of_string(environment.get("ICECAST_PORT"))
icecast_mount = environment.get("ICECAST_MOUNT")
icecast_password = environment.get("ICECAST_PASSWORD")

radio_name = environment.get("RADIO_NAME")
radio_description = environment.get("RADIO_DESCRIPTION")
radio_genre = environment.get("RADIO_GENRE")
radio_url = environment.get("RADIO_URL")

harbor_enabled = bool_of_string(environment.get("HARBOR_ENABLED"))
harbor_port = int_of_string(environment.get("HARBOR_PORT"))
harbor_password = environment.get("HARBOR_PASSWORD")
harbor_user = environment.get("HARBOR_USER")

stream_format = environment.get("STREAM_FORMAT")
stream_bitrate = int_of_string(environment.get("STREAM_BITRATE"))
stream_samplerate = int_of_string(environment.get("STREAM_SAMPLERATE"))

discogs_token = environment.get("DISCOGS_TOKEN")
discogs_enabled = bool_of_string(environment.get("DISCOGS_ENABLED"))

discogs_cache = ref([])

def get_discogs_cover(artist, title, album) =
  if not discogs_enabled or discogs_token == "" then
    ""
  else
    cache_key = "#{artist}|#{title}|#{album}"
    cache = discogs_cache()
    cached = list.assoc(default="", cache_key, cache)

    if cached != "" then
      log("Discogs: Using cached cover for #{artist} - #{title}")
      cached
    else
      query = if album != "" then
        "artist:#{artist} release_title:#{album}"
      else
        "artist:#{artist} track:#{title}"
      end

      encoded = url.encode(query)
      api_url = "https://api.discogs.com/database/search?q=#{encoded}&type=release&per_page=1&token=#{discogs_token}"

      try
        cmd = "curl -s '#{api_url}' | jq -r '.results[0].cover_image // empty'"
        result = list.hd(default="", process.read.lines(cmd))
        cover = string.trim(result)

        if cover != "" and cover != "null" then
          log("Discogs: Found cover for #{artist} - #{title}")
          discogs_cache := list.add((cache_key, cover), cache)
          cover
        else
          discogs_cache := list.add((cache_key, ""), cache)
          ""
        end
      catch err do
        log("Discogs API error: #{err}")
        ""
      end
    end
  end
end

def process_metadata(m) =
  artist = m["artist"] ?? ""
  title = m["title"] ?? ""
  album = m["album"] ?? ""

  stream_title = if artist != "" and title != "" then
    "#{artist} - #{title}"
  elsif title != "" then
    title
  else
    radio_name
  end

  stream_url = if artist != "" and (title != "" or album != "") then
    cover = get_discogs_cover(artist, title, album)
    if cover != "" then cover else radio_url end
  else
    radio_url
  end

  [
    ("StreamTitle", stream_title),
    ("StreamUrl", stream_url)
  ]
end

songs = playlist(
  mode="randomize",
  reload_mode="watch",
  "/app/storage/playlists/songs.m3u"
)
songs = mksafe(songs)
songs = blank.skip(max_blank=5.0, min_noise=0.01, songs)
songs = normalize(songs)
songs = compress(songs)

jingles = playlist(
  mode="randomize",
  reload_mode="watch",
  "/app/storage/playlists/jingles.m3u"
)
jingles = mksafe(jingles)
jingles = blank.skip(max_blank=5.0, min_noise=0.01, jingles)
jingles = normalize(jingles)
jingles = compress(jingles)
jingles = metadata.map(update=false, fun(m) -> begin
  [("title", "Jingle"), ("artist", "")]
end, jingles)

music = rotate(
  weights=[3, 1],
  [songs, jingles]
)

music = metadata.map(update=false, fun(m) -> begin
  artist = m["artist"] ?? "Unknown"
  title = m["title"] ?? "Unknown"
  log("Now playing: #{artist} - #{title}")
  m
end, music)

music = crossfade(
  duration=3.0,
  fade_in=1.5,
  fade_out=1.5,
  music
)

radio = if harbor_enabled then
  log("Harbor (live input) enabled on port #{harbor_port}")
  live = input.harbor(
    "live.mp3",
    port=harbor_port,
    password=harbor_password,
    user=harbor_user
  )
  fallback(track_sensitive=false, [live, music, sine(440.0)])
else
  log("Harbor (live input) disabled")
  fallback(track_sensitive=false, [music, sine(440.0)])
end

radio = metadata.map(update=true, process_metadata, radio)

def get_encoder() =
  format = string.lowercase(stream_format)

  if format == "mp3" then
    log("Using MP3 encoder: #{stream_bitrate}kbps @ #{stream_samplerate}Hz")
    %mp3(bitrate=stream_bitrate, samplerate=stream_samplerate, stereo=true)
  elsif format == "vorbis" or format == "ogg" then
    log("Using Vorbis encoder: #{stream_bitrate}kbps @ #{stream_samplerate}Hz")
    quality = float_of_int(stream_bitrate) / 64.0
    %vorbis(quality=quality, samplerate=stream_samplerate)
  elsif format == "opus" then
    log("Using Opus encoder: #{stream_bitrate}kbps @ #{stream_samplerate}Hz")
    %opus(bitrate=stream_bitrate, samplerate=stream_samplerate)
  else
    log("WARNING: Unknown format '#{format}', falling back to MP3")
    %mp3(bitrate=stream_bitrate, samplerate=stream_samplerate, stereo=true)
  end
end

output.icecast(
  get_encoder(),
  host=icecast_host,
  port=icecast_port,
  password=icecast_password,
  mount=icecast_mount,
  name=radio_name,
  description=radio_description,
  genre=radio_genre,
  url=radio_url,
  public=true,
  radio
)

log("Stream started successfully!")
log("Icecast: http://#{icecast_host}:#{icecast_port}/#{icecast_mount}")
if harbor_enabled then
  log("Harbor (live input): ENABLED on port #{harbor_port}, user: #{harbor_user}")
else
  log("Harbor (live input): DISABLED")
end
if telnet_enabled then
  log("Telnet control: ENABLED on port #{telnet_port}")
else
  log("Telnet control: DISABLED")
end
