#!/bin/zsh

HOST=$1

if [[ -z "$HOST" ]]; then
  echo "Usage: clear-cache.sh <hostname>"
  exit
fi

echo "Clearing cache..."

setopt +o nomatch

rm -f -v .cache/$HOST-[0-9a-f]*

echo "Done"
