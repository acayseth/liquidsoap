# Functions for metadata processing and external API calls

# Get encoder based on stream format
def get_encoder() =
  format = string.lowercase(stream_format)

  if format == "mp3" then
    log("Using MP3 encoder: #{stream_bitrate}kbps @ #{stream_samplerate}Hz")
    %mp3(bitrate=stream_bitrate, samplerate=stream_samplerate)
  elsif format == "vorbis" or format == "ogg" then
    log("Using Vorbis encoder: quality #{stream_bitrate/64} (~#{stream_bitrate}kbps) @ #{stream_samplerate}Hz")
    # Vorbis uses quality scale -1 to 10, approximate from bitrate
    quality = float_of_int(stream_bitrate) / 64.0
    %vorbis(quality=quality, samplerate=stream_samplerate)
  elsif format == "opus" then
    log("Using Opus encoder: #{stream_bitrate}kbps @ #{stream_samplerate}Hz")
    %opus(bitrate=stream_bitrate, samplerate=stream_samplerate)
  else
    log("WARNING: Unknown format '#{format}', falling back to MP3")
    %mp3(bitrate=stream_bitrate, samplerate=stream_samplerate)
  end
end

# Cache for Discogs API results to avoid duplicate requests
# Key: "artist|title|album" -> Value: cover_url
discogs_cache = ref([])

# Get from cache
def get_from_cache(key) =
  list.assoc(default="", key, !discogs_cache)
end

# Add to cache
def add_to_cache(key, value) =
  discogs_cache := list.add((key, value), !discogs_cache)
end

# Search Discogs for album cover using jq for JSON parsing (with caching)
def get_discogs_cover(artist, title, album) =
  if not discogs_enabled or discogs_token == "" then
    ""
  else
    # Create cache key
    cache_key = "#{artist}|#{title}|#{album}"

    # Check cache first
    cached_result = get_from_cache(cache_key)

    if cached_result != "" then
      log("Discogs: Using cached cover for #{artist} - #{title}")
      cached_result
    else
      # Build search query
      query = if album != "" then
        "artist:#{artist} release_title:#{album}"
      else
        "artist:#{artist} track:#{title}"
      end

      # URL encode the query
      encoded_query = url.encode(query)

      # Discogs API endpoint
      api_url = "https://api.discogs.com/database/search?q=#{encoded_query}&type=release&per_page=1&token=#{discogs_token}"

      try
        # Use curl + jq to fetch and parse JSON
        # jq extracts: .results[0].cover_image
        cmd = "curl -s '#{api_url}' | jq -r '.results[0].cover_image // empty'"

        result = list.hd(default="", process.read.lines(cmd))

        cover_url = string.trim(result)

        if cover_url != "" and cover_url != "null" then
          log("Discogs: Found cover for #{artist} - #{title}: #{cover_url}")
          # Add to cache
          add_to_cache(cache_key, cover_url)
          cover_url
        else
          log("Discogs: No cover found for #{artist} - #{title}")
          # Cache negative result to avoid repeated failed requests
          add_to_cache(cache_key, "")
          ""
        end
      catch err do
        log("Discogs API request failed: #{err}")
        ""
      end
    end
  end
end

# Process and format metadata for Icecast
def process_metadata(m) =
  artist = list.assoc(default="", "artist", m)
  title = list.assoc(default="", "title", m)
  album = list.assoc(default="", "album", m)

  # StreamTitle format: "Artist - Title"
  stream_title = if artist != "" and title != "" then
    "#{artist} - #{title}"
  elsif title != "" then
    title
  else
    "#{radio_name}"
  end

  # StreamUrl - Priority: metadata -> Discogs API -> fallback
  coverart = list.assoc(default="", "coverart", m)
  comment = list.assoc(default="", "comment", m)

  stream_url = if coverart != "" then
    coverart
  elsif comment != "" then
    comment
  elsif artist != "" and (title != "" or album != "") then
    # Try Discogs API
    discogs_cover = get_discogs_cover(artist, title, album)
    if discogs_cover != "" then
      discogs_cover
    else
      radio_url
    end
  else
    radio_url
  end

  [
    ("StreamTitle", stream_title),
    ("StreamUrl", stream_url)
  ]
end
