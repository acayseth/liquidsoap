#!/usr/bin/liquidsoap

%include "environment.liq"
%include "funcs.liq"

set("log.level", log_level)
set("log.stdout", true)
set("log.file", false)

set("server.telnet", telnet_enabled)
set("server.telnet.bind_addr", "0.0.0.0")
set("server.telnet.port", telnet_port)

set("frame.audio.samplerate", audio_samplerate)
set("frame.audio.channels", audio_channels)

songs = playlist(
  mode="randomize",
  reload_mode="watch",
  "/app/storage/playlists/songs.m3u"
)

jingles = playlist(
  mode="randomize",
  reload_mode="watch",
  "/app/storage/playlists/jingles.m3u"
)

# Override metadata for jingles
jingles = map_metadata(fun(_) -> [
  ("StreamTitle", "Jingle"),
  ("StreamUrl", "")
], jingles)

# Check if jingles playlist is available
# If jingles.m3u is empty or missing, fallback to songs only
jingles_available = mksafe(jingles)

# Create rotation with jingles + songs
music_with_jingles = rotate(weights=[1, 3], [jingles_available, songs])

# Log when switching between modes
music_with_jingles = on_track(fun(_) ->
  log("Playing with jingles rotation (1 jingle per 3 songs)")
, music_with_jingles)

songs_only = on_track(fun(_) ->
  log("WARNING: Jingles playlist empty or unavailable, playing songs only")
, songs)

music = fallback(
  track_sensitive=false,
  [music_with_jingles, songs_only]
)

live = input.harbor(
  "live.mp3",
  port=harbor_port,
  password=harbor_password,
  user=harbor_user
)

radio = fallback(
  track_sensitive=false,
  [live, music]
)

# Apply metadata processing
radio = map_metadata(process_metadata, radio)

# Log metadata changes
radio = on_metadata(fun(m) ->
  log("Now playing: #{m["StreamTitle"]} | StreamUrl: #{m["StreamUrl"]}")
, radio)

# Insert metadata updates periodically to ensure new clients get current metadata
# This refreshes metadata every 30 seconds with the current track info
radio = insert_metadata(radio)

radio = normalize(radio, gain_max=3., gain_min=-3.)

radio = crossfade(
  duration=3.,
  radio
)

# Output to Icecast with ICY metadata support and dynamic encoder
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
  icy_metadata="true",
  public=true,
  radio
)
