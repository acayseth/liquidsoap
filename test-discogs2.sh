#!/bin/bash

USER_TOKEN=""

echo "=== Test 1: Search by artist and release title ==="
QUERY="artist:The Doors release_title:The Doors"
ENCODED=$(echo -n "$QUERY" | jq -sRr @uri)
curl -s "https://api.discogs.com/database/search?q=${ENCODED}&type=release&per_page=3&token=${USER_TOKEN}" | jq -r '.results[] | {title: .title, year: .year, cover: .cover_image}'

echo ""
echo "=== Test 2: Simple search ==="
QUERY="The Doors Break On Through"
ENCODED=$(echo -n "$QUERY" | jq -sRr @uri)
curl -s "https://api.discogs.com/database/search?q=${ENCODED}&type=release&per_page=3&token=${USER_TOKEN}" | jq -r '.results[] | {title: .title, year: .year, cover: .cover_image}'

echo ""
echo "=== Test 3: Artist only ==="
curl -s "https://api.discogs.com/database/search?q=The+Doors&type=release&per_page=3&token=${USER_TOKEN}" | jq -r '.results[] | {title: .title, year: .year, cover: .cover_image}'
