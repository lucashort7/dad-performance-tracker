#!/bin/bash

PATH_MODS_FOLDER="../"
PATH_DISCO_TRACKER="$PATH_MODS_FOLDER/DiscoTracker"
PATH_MAIN_FILES="./src"

echo "Cleaning DiscoTracker folder..."
if [ -n "$PATH_DISCO_TRACKER" ]; then
    rm -rf "$PATH_DISCO_TRACKER"
fi

echo "Copying DiscoTracker mod files..."
mkdir -p "$PATH_DISCO_TRACKER/Scripts" && cp -r "$PATH_MAIN_FILES"/* "$PATH_DISCO_TRACKER/Scripts/"

touch "$PATH_DISCO_TRACKER/enabled.txt"

echo "Done!"
