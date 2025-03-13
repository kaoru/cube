#!/bin/zsh

echo "Clearing cache..."

setopt +o nomatch

rm -f .cache/[0-9a-f]*

echo "Done"
