# Add after line 32 (after discogs_enabled)
discogs_cache_max_size = int_of_string(environment.get("DISCOGS_CACHE_MAX_SIZE"))

telegram_enabled = bool_of_string(environment.get("TELEGRAM_ENABLED"))
telegram_bot_token = environment.get("TELEGRAM_BOT_TOKEN")
telegram_chat_id = environment.get("TELEGRAM_CHAT_ID")

# Add after discogs_cache = ref([])
def send_telegram(msg) =
  if telegram_enabled and telegram_bot_token != "" and telegram_chat_id != "" then
    try
      enc_msg = url.encode(msg)
      url_base = "https://api.telegram.org/bot#{telegram_bot_token}/sendMessage"
      url_params = "?chat_id=#{telegram_chat_id}" ^ "&text=#{enc_msg}" ^ "&parse_mode=HTML"
      full_url = url_base ^ url_params
      cmd = "curl -s -X POST '#{full_url}' >/dev/null 2>&1"
      ignore(process.run(cmd))
      log("Telegram: Sent")
    catch e do
      log("Telegram: Error - #{e}")
    end
  end
end
