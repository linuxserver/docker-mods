#!/bin/bash

# Script to convert FLAC files to MP3 using FFMpeg
#  https://github.com/linuxserver/docker-mods/tree/lidarr-flac2mp3
# Can also process MP3s and tag them appropriately
# Resultant MP3s are fully tagged

# Dependencies:
#  ffmpeg
#  awk
#  stat
#  nice

# Exit codes:
#  0 - success; or test
#  1 - no tracks files specified on command line
#  2 - mkvmerge not found
# 10 - awk script generated an error

### Variables
export flac2mp3_script=$(basename "$0")
export flac2mp3_pid=$$
export flac2mp3_config=/config/config.xml
export flac2mp3_log=/config/logs/flac2mp3.txt
export flac2mp3_maxlogsize=1024000
export flac2mp3_maxlog=4
export flac2mp3_debug=0
export flac2mp3_tracks="$lidarr_addedtrackpaths"
[ -z "$flac2mp3_tracks" ] && flac2mp3_tracks="$lidarr_trackfile_path"      # For other event type
export flac2mp3_recyclebin=$(sqlite3 /config/lidarr.db 'SELECT Value FROM Config WHERE Key="recyclebin"')
RET=$?; [ "$RET" != 0 ] && >&2 echo "WARNING[$RET]: Unable to read recyclebin information from database \"/config/lidarr.db\""

### Functions
function usage {
  usage="
$flac2mp3_script
Audio conversion script designed for use with Bazarr

Source: https://github.com/TheCaptain989/lidarr-flac2mp3

Usage:
  $0 [-d] [-b <bitrate>]

Arguments:
  bitrate       # output quality in bits per second (SI units)

Options:
  -d    # enable debug logging
  -b    # set bitrate; default 320K

Examples:
  $flac2mp3_script -b 320k              # Output 320 kilobits per second MP3
                                     (same as default behavior)
  $flac2mp3_script -d -b 160k           # Enable debugging, and output quality
                                     160 kilobits per second
"
  >&2 echo "$usage"
}
# Can still go over flac2mp3_maxlog if read line is too long
#  Must include whole function in subshell for read to work!
function log {(
  while read
  do
    echo $(date +"%y-%-m-%-d %H:%M:%S.%1N")\|"[$flac2mp3_pid]$REPLY" >>"$flac2mp3_log"
    local FILESIZE=$(stat -c %s "$flac2mp3_log")
    if [ $FILESIZE -gt $flac2mp3_maxlogsize ]
    then
      for i in `seq $((flac2mp3_maxlog-1)) -1 0`
      do
        [ -f "${flac2mp3_log::-4}.$i.txt" ] && mv "${flac2mp3_log::-4}."{$i,$((i+1))}".txt"
      done
        [ -f "${flac2mp3_log::-4}.txt" ] && mv "${flac2mp3_log::-4}.txt" "${flac2mp3_log::-4}.0.txt"
      touch "$flac2mp3_log"
    fi
  done
)}
# Inspired by https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
function read_xml {
  local IFS=\>
  read -d \< ENTITY CONTENT
}
# Initiate API Rescan request
function rescan {
  MSG="Info|Calling Lidarr API to rescan artist"
  echo "$MSG" | log
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Forcing rescan of artist '$lidarr_artist_id'. Calling Lidarr API 'RefreshArtist' using POST and URL 'http://$flac2mp3_bindaddress:$flac2mp3_port$flac2mp3_urlbase/api/v1/command?apikey=(removed)'" | log
  RESULT=$(curl -s -d "{name: 'RefreshArtist', artistId: $lidarr_artist_id}" -H "Content-Type: application/json" \
    -X POST http://$flac2mp3_bindaddress:$flac2mp3_port$flac2mp3_urlbase/api/v1/command?apikey=$flac2mp3_apikey)
  [ $flac2mp3_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
  JOBID="$(echo $RESULT | jq -crM .id)"
  if [ "$JOBID" != "null" ]; then
    local RET=0
  else
    local RET=1
  fi
  return $RET
}
# Check result of rescan job
function check_rescan {
  local i=0
  for ((i=1; i <= 15; i++)); do
    [ $flac2mp3_debug -eq 1 ] && echo "Debug|Checking job $JOBID completion, try #$i. Calling Lidarr API using GET and URL 'http://$flac2mp3_bindaddress:$flac2mp3_port$flac2mp3_urlbase/api/command/$JOBID?apikey=(removed)'" | log
    RESULT=$(curl -s -H "Content-Type: application/json" \
      -X GET http://$flac2mp3_bindaddress:$flac2mp3_port$flac2mp3_urlbase/api/v1/command/$JOBID?apikey=$flac2mp3_apikey)
    [ $flac2mp3_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
    if [ "$(echo $RESULT | jq -crM .status)" = "completed" ]; then
      local RET=0
      break
    else
      if [ "$(echo $RESULT | jq -crM .status)" = "failed" ]; then
        local RET=2
        break
      else
        local RET=1
        sleep 1
      fi
    fi
  done
  return $RET
}
# Process options
while getopts ":db:" opt; do
  case ${opt} in
    d ) # For debug purposes only
      MSG="Debug|Enabling debug logging."
      echo "$MSG" | log
      >&2 echo "$MSG"
      flac2mp3_debug=1
      printenv | sort | sed 's/^/Debug|/' | log
      ;;
    b ) # Set bitrate
      flac2mp3_bitrate="$OPTARG"
      ;;
    : )
      MSG="Error|Invalid option: -$OPTARG requires an argument"
      echo "$MSG" | log
      >&2 echo "$MSG"
      ;;
  esac
done
shift $((OPTIND -1))

# Set default bitrate
[ -z "$flac2mp3_bitrate" ] && flac2mp3_bitrate="320k"

if [[ "$lidarr_eventtype" = "Test" ]]; then
  echo "Info|Lidarr event: $lidarr_eventtype" | log
  echo "Info|Script was test executed successfully." | log
  exit 0
fi

if [ -z "$flac2mp3_tracks" ]; then
  MSG="Error|No track file(s) specified! Not called from Lidarr?"
  echo "$MSG" | log
  >&2 echo "$MSG"
  usage
  exit 1
fi

if [ ! -f "/usr/bin/ffmpeg" ]; then
  MSG="Error|/usr/bin/ffmpeg is required by this script"
  echo "$MSG" | log
  >&2 echo "$MSG"
  exit 2
fi

# Legacy one-liner script
#find "$lidarr_artist_path" -name "*.flac" -exec bash -c 'ffmpeg -loglevel warning -i "{}" -y -acodec libmp3lame -b:a 320k "${0/.flac}.mp3" && rm "{}"' {} \;

#### MAIN
echo "Info|Lidarr event: $lidarr_eventtype, Artist: $lidarr_artist_name ($lidarr_artist_id), Album: $lidarr_album_title ($lidarr_album_id), Export bitrate: $flac2mp3_bitrate, Tracks: $flac2mp3_tracks" | log
echo "$flac2mp3_tracks" | awk -v Debug=$flac2mp3_debug \
-v Recycle="$flac2mp3_recyclebin" \
-v Bitrate=$flac2mp3_bitrate '
BEGIN {
  FFMpeg="/usr/bin/ffmpeg"
  FS="|"
  RS="|"
  IGNORECASE=1
}
/\.flac/ {
  Track=$1
  sub(/\n/,"",Track)
  NewTrack=substr(Track, 1, length(Track)-5)".mp3"
  print "Info|Writing: "NewTrack
  if (Debug) print "Debug|Executing: nice "FFMpeg" -loglevel error -i \""Track"\" "CoverCmds1"-map 0 -y -acodec libmp3lame -b:a "Bitrate" -write_id3v1 1 -id3v2_version 3 "CoverCmds2"\""NewTrack"\""
  Result=system("nice "FFMpeg" -loglevel error -i \""Track"\" "CoverCmds1"-map 0 -y -acodec libmp3lame -b:a "Bitrate" -write_id3v1 1 -id3v2_version 3 "CoverCmds2"\""NewTrack"\" 2>&1")
  if (Result) {
    print "Error|"Result" converting \""Track"\""
  } else {
    if (Recycle=="") {
      if (Debug) print "Debug|Deleting: \""Track"\""
      system("[ -s \""NewTrack"\" ] && [ -f \""Track"\" ] && rm \""Track"\"")
    } else {
      match(Track,/^\/?[^\/]+\//)
      RecPath=substr(Track,RSTART+RLENGTH)
      sub(/[^\/]+$/,"",RecPath)
      RecPath=Recycle RecPath
      if (Debug) print "Debug|Moving: \""Track"\" to \""RecPath"\""
      system("[ ! -e \""RecPath"\" ] && mkdir -p \""RecPath"\"; [ -s \""NewTrack"\" ] && [ -f \""Track"\" ] && mv -t \""RecPath"\" \""Track"\"")
    }
  }
}
' | log

RET="${PIPESTATUS[1]}"    # captures awk exit status
if [ $RET != "0" ]; then
  # Check for script completion and non-empty file
  MSG="Error|Script exited abnormally.  File permissions issue?"
  echo "$MSG" | log
  >&2 echo "$MSG"
  exit 10
fi

# Call Lidarr API to RescanArtist
if [ ! -z "$lidarr_artist_id" ]; then
  if [ -f "$flac2mp3_config" ]; then
    # Read Lidarr config.xml
    while read_xml; do
      [[ $ENTITY = "Port" ]] && flac2mp3_port=$CONTENT
      [[ $ENTITY = "UrlBase" ]] && flac2mp3_urlbase=$CONTENT
      [[ $ENTITY = "BindAddress" ]] && flac2mp3_bindaddress=$CONTENT
      [[ $ENTITY = "ApiKey" ]] && flac2mp3_apikey=$CONTENT
    done < $flac2mp3_config
    
    [[ $flac2mp3_bindaddress = "*" ]] && flac2mp3_bindaddress=localhost
    
    # Scan the disk for the new audio tracks
    if rescan; then
      # Check that the rescan completed
      if ! check_rescan; then
        # Timeout or failure
        MSG="Warn|Lidarr job ID $JOBID timed out or failed."
        echo "$MSG" | log
        >&2 echo "$MSG"
      fi
    else
      # Error from API
      MSG="Error|The 'RefreshArtist' API with artist $lidarr_artist_id failed."
      echo "$MSG" | log
      >&2 echo "$MSG"
    fi
  else
    MSG="Warn|Unable to locate Lidarr config file: '$flac2mp3_config'"
    echo "$MSG" | log
    >&2 echo "$MSG"
  fi
else
  MSG="Warn|Missing environment variable lidarr_artist_id"
  echo "$MSG" | log
  >&2 echo "$MSG"
fi

# Cool bash feature
MSG="Info|Completed in $(($SECONDS/60))m $(($SECONDS%60))s"
echo "$MSG" | log
