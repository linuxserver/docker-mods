#!/bin/bash

. /usr/local/bin/flac2mp3.sh -a "-c:v libtheora -map 0 -q:v 10 -c:a libopus -b:a 192K" -e .opus
