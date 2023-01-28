#!/bin/bash

# Convert videos to mkv
set -e

for file in "$@" ; do
    dir=$(dirname "$file")
    fn=$(basename "$file")
    filebase=${file%.*}
    if [[ "$dir" == "" ]] ; then
        dir="."
    fi
    jdir="$dir/junk"
    mkdir -p "$jdir"
    mv -v "$file" "$jdir/"
    # make sure not to overwrite
    if [[ -f "$filebase.mkv" ]] ; then echo ERROR output file exists; exit 2 ; fi
    mkvmerge -o "$filebase.mkv" "$jdir/$fn"
done

