#!/bin/bash

CONSUMER_KEY=""
CONSUMER_SECRET=""
ACCESS_TOKEN=""
ACCESS_TOKEN_SECRET=""
USER_TOKEN=""

ARTIST="The Doors"
TITLE="Break On Through"

QUERY="artist:${ARTIST} track:${TITLE}"
ENCODED_QUERY=$(echo -n "$QUERY" | jq -sRr @uri)

echo "Testing Discogs API..."
echo "Artist: $ARTIST"
echo "Title: $TITLE"
echo "Query: $QUERY"
echo ""

# Test cu User Token (cel mai simplu)
echo "=== Test 1: Using User Token ==="
curl -s "https://api.discogs.com/database/search?q=${ENCODED_QUERY}&type=release&per_page=1&token=${USER_TOKEN}" | jq -r '.results[0] | {title: .title, year: .year, cover_image: .cover_image, thumb: .thumb}'

echo ""
echo "=== Test 2: Just cover image ==="
curl -s "https://api.discogs.com/database/search?q=${ENCODED_QUERY}&type=release&per_page=1&token=${USER_TOKEN}" | jq -r '.results[0].cover_image'
