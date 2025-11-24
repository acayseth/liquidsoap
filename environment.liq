# Icecast configuration
icecast_host = getenv(default="icecast", "ICECAST_HOST")
icecast_port = int_of_string(getenv(default="8000", "ICECAST_PORT"))
icecast_password = getenv(default="hackme", "ICECAST_PASSWORD")
icecast_mount = getenv(default="stream", "ICECAST_MOUNT")

# Radio station information
radio_name = getenv(default="Radio Dream", "RADIO_NAME")
radio_description = getenv(default="Radio Dream Stream", "RADIO_DESCRIPTION")
radio_genre = getenv(default="Various", "RADIO_GENRE")
radio_url = getenv(default="http://localhost:8000", "RADIO_URL")

# Harbor (live input) configuration
harbor_port = int_of_string(getenv(default="8001", "HARBOR_PORT"))
harbor_password = getenv(default="hackme", "HARBOR_PASSWORD")
harbor_user = getenv(default="source", "HARBOR_USER")

# Telnet server configuration
telnet_enabled = bool_of_string(getenv(default="true", "TELNET_ENABLED"))
telnet_port = int_of_string(getenv(default="1234", "TELNET_PORT"))

# Logging configuration
log_level = int_of_string(getenv(default="4", "LOG_LEVEL"))

# Discogs API configuration
discogs_token = getenv(default="", "DISCOGS_TOKEN")
discogs_enabled = bool_of_string(getenv(default="false", "DISCOGS_ENABLED"))

# Audio encoding configuration
# Supported formats: mp3, vorbis, opus
stream_format = getenv(default="mp3", "STREAM_FORMAT")
stream_bitrate = int_of_string(getenv(default="320", "STREAM_BITRATE"))
stream_samplerate = int_of_string(getenv(default="44100", "STREAM_SAMPLERATE"))

# Audio settings
audio_samplerate = int_of_string(getenv(default="44100", "AUDIO_SAMPLERATE"))
audio_channels = int_of_string(getenv(default="2", "AUDIO_CHANNELS"))
