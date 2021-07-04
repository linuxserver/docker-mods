#!/bin/bash

# Script to convert FLAC files to MP3 using FFMpeg
#  Dev/test: https://github.com/TheCaptain989/lidarr-flac2mp3
#  Prod: https://github.com/linuxserver/docker-mods/tree/lidarr-flac2mp3
# Resultant MP3s are fully tagged and retain same permissions as original file

# Dependencies:
#  ffmpeg
#  awk
#  stat
#  nice
#  chmod

# Exit codes:
#  0 - success; or test
#  1 - no tracks files found in environment
#  2 - mkvmerge not found
#  3 - invalid command line arguments
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

### Functions
function usage {
  usage="
$flac2mp3_script
Audio conversion script designed for use with Lidarr

Source: https://github.com/TheCaptain989/lidarr-flac2mp3

Usage:
  $0 [-d] [-b <bitrate> | -v <quality>]

Options:
  -d             enable debug logging
  -b <bitrate>   set output quality in constant bits per second [default: 320k]
                 Ex: 160k, 240k, 300000
  -v <quality>   set variable bitrate; quality between 0-9
                 0 is highest quality, 9 is lowest
                 See https://trac.ffmpeg.org/wiki/Encode/MP3 for more details

Examples:
  $flac2mp3_script -b 320k            # Output 320 kbit/s MP3 (non VBR; same as default behavior)
  $flac2mp3_script -v 0               # Output variable bitrate, VBR 220-260 kbit/s
  $flac2mp3_script -d -b 160k         # Enable debugging and set output to 160 kbit/s
"
  echo "$usage" >&2
}
# Can still go over flac2mp3_maxlog if read line is too long
#  Must include whole function in subshell for read to work!
function log {(
  while read
  do
    echo $(date +"%y-%-m-%-d %H:%M:%S.%1N")\|"[$flac2mp3_pid]$REPLY" >>"$flac2mp3_log"
    local flac2mp3_filesize=$(stat -c %s "$flac2mp3_log")
    if [ $flac2mp3_filesize -gt $flac2mp3_maxlogsize ]
    then
      for i in $(seq $((flac2mp3_maxlog-1)) -1 0); do
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
  read -d \< flac2mp3_xml_entity flac2mp3_xml_content
}
# Initiate API Rescan request
function rescan {
  flac2mp3_message="Info|Calling Lidarr API to rescan artist"
  echo "$flac2mp3_message" | log
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Forcing rescan of artist '$lidarr_artist_id'. Calling Lidarr API 'RefreshArtist' using POST and URL '$flac2mp3_api_url/command'" | log
  flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -d "{\"name\": 'RefreshArtist', \"artistId\": $lidarr_artist_id}" \
    -X POST "$flac2mp3_api_url/command")
  [ $flac2mp3_debug -eq 1 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  flac2mp3_jobid="$(echo $flac2mp3_result | jq -crM .id)"
  if [ "$flac2mp3_jobid" != "null" ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Check result of rescan job
function check_rescan {
  local i=0
  for ((i=1; i <= 15; i++)); do
    [ $flac2mp3_debug -eq 1 ] && echo "Debug|Checking job $flac2mp3_jobid completion, try #$i. Calling Lidarr API using GET and URL '$flac2mp3_api_url/command/$flac2mp3_jobid'" | log
    flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
      -X GET "$flac2mp3_api_url/command/$flac2mp3_jobid")
    [ $flac2mp3_debug -eq 1 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
    if [ "$(echo $flac2mp3_result | jq -crM .status)" = "completed" ]; then
      local flac2mp3_return=0
      break
    else
      if [ "$(echo $flac2mp3_result | jq -crM .status)" = "failed" ]; then
        local flac2mp3_return=2
        break
      else
        # It may have timed out, so let's wait a second
        local flac2mp3_return=1
        [ $flac2mp3_debug -eq 1 ] && echo "Debug|Job not done.  Waiting 1 second." | log
        sleep 1
      fi
    fi
  done
  return $flac2mp3_return
}

# Process options
while getopts ":db:v:" opt; do
  case ${opt} in
    d ) # For debug purposes only
      flac2mp3_message="Debug|Enabling debug logging."
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
      flac2mp3_debug=1
      printenv | sort | sed 's/^/Debug|/' | log
      ;;
    b ) # Set constant bit rate
      if [ -n "$flac2mp3_vbrquality" ]; then
        flac2mp3_message="Error|Both -b and -v options cannot be set at the same time."
        echo "$flac2mp3_message" | log
        echo "$flac2mp3_message" >&2
        usage
        exit 3
      else
        flac2mp3_bitrate="$OPTARG"
      fi
      ;;
    v ) # Set variable quality
      if [ -n "$flac2mp3_bitrate" ]; then
        flac2mp3_message="Error|Both -v and -b options cannot be set at the same time."
        echo "$flac2mp3_message" | log
        echo "$flac2mp3_message" >&2
        usage
        exit 3
      else
        flac2mp3_vbrquality="$OPTARG"
      fi
      ;;
    : ) # No required argument specified
      flac2mp3_message="Error|Invalid option: -${OPTARG} requires an argument"
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
      usage
      exit 3
      ;;
    * ) # Unknown option
      flac2mp3_message="Error|Unknown option: -${OPTARG}"
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
      usage
      exit 3
      ;;
  esac
done
shift $((OPTIND -1))

# Set default bit rate
[ -z "$flac2mp3_vbrquality" ] && [ -z "$flac2mp3_bitrate" ] && flac2mp3_bitrate="320k"

# Check for config file
if [ -f "$flac2mp3_config" ]; then
  # Read Lidarr config.xml
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Reading from Lidarr config file '$flac2mp3_config'" | log
  while read_xml; do
    [[ $flac2mp3_xml_entity = "Port" ]] && flac2mp3_port=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "UrlBase" ]] && flac2mp3_urlbase=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "BindAddress" ]] && flac2mp3_bindaddress=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "ApiKey" ]] && flac2mp3_apikey=$flac2mp3_xml_content
  done < $flac2mp3_config

  [[ $flac2mp3_bindaddress = "*" ]] && flac2mp3_bindaddress=localhost

  # Build URL to Lidarr API
  flac2mp3_api_url="http://$flac2mp3_bindaddress:$flac2mp3_port$flac2mp3_urlbase/api/v1"

  # Check Lidarr version
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Getting Lidarr version. Calling Lidarr API using GET and URL '$flac2mp3_api_url/system/status'" | log
  flac2mp3_version=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -X GET "$flac2mp3_api_url/system/status" | jq -crM .version)
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Detected Lidarr version $flac2mp3_version" | log

  # Get RecycleBin
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Getting Lidarr RecycleBin. Calling Lidarr API using GET and URL '$flac2mp3_api_url/config/mediamanagement'" | log
  flac2mp3_recyclebin=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -X GET "$flac2mp3_api_url/config/mediamanagement" | jq -crM .recycleBin)
  [ $flac2mp3_debug -eq 1 ] && echo "Debug|Detected Lidarr RecycleBin '$flac2mp3_recyclebin'" | log
else
  # No config file means we can't call the API.  Best effort at this point.
  flac2mp3_message="Warn|Unable to locate Lidarr config file: '$flac2mp3_config'"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
fi

# Handle Lidarr Test event
if [[ "$lidarr_eventtype" = "Test" ]]; then
  echo "Info|Lidarr event: $lidarr_eventtype" | log
  echo "Info|Script was test executed successfully." | log
  exit 0
fi

# Check if called from within Lidarr
if [ -z "$flac2mp3_tracks" ]; then
  flac2mp3_message="Error|No track file(s) specified! Not called from Lidarr?"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  usage
  exit 1
fi

# Check for required binaries
if [ ! -f "/usr/bin/ffmpeg" ]; then
  flac2mp3_message="Error|/usr/bin/ffmpeg is required by this script"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 2
fi

# Legacy one-liner script for posterity
#find "$lidarr_artist_path" -name "*.flac" -exec bash -c 'ffmpeg -loglevel warning -i "{}" -y -acodec libmp3lame -b:a 320k "${0/.flac}.mp3" && rm "{}"' {} \;

#### MAIN
echo "Info|Lidarr event: $lidarr_eventtype, Artist: $lidarr_artist_name ($lidarr_artist_id), Album: $lidarr_album_title ($lidarr_album_id), Export bitrate: ${flac2mp3_bitrate:-$flac2mp3_vbrquality}, Tracks: $flac2mp3_tracks" | log
echo "$flac2mp3_tracks" | awk -v Debug=$flac2mp3_debug \
-v Recycle="$flac2mp3_recyclebin" \
-v Bitrate=$flac2mp3_bitrate \
-v VBR=$flac2mp3_vbrquality '
BEGIN {
  FFMpeg="/usr/bin/ffmpeg"
  FS="|"
  RS="|"
  IGNORECASE=1
  if (Bitrate) {
    if (Debug) print "Debug|Using constant bitrate of "Bitrate
    BrCommand="-b:a "Bitrate
  } else {
    if (Debug) print "Debug|Using variable quality of "VBR
    BrCommand="-q:a "VBR
  }
}
/\.flac/ {
  # Get each FLAC file name and create a new MP3 name
  Track=$1
  sub(/\n/,"",Track)
  NewTrack=substr(Track, 1, length(Track)-5)".mp3"
  print "Info|Writing: "NewTrack
  # Convert the track
  if (Debug) print "Debug|Executing: nice "FFMpeg" -loglevel error -i \""Track"\" -c:v copy -map 0 -y -acodec libmp3lame "BrCommand" -write_id3v1 1 -id3v2_version 3 \""NewTrack"\""
  Result=system("nice "FFMpeg" -loglevel error -i \""Track"\" -c:v copy -map 0 -y -acodec libmp3lame "BrCommand" -write_id3v1 1 -id3v2_version 3 \""NewTrack"\" 2>&1")
  if (Result) {
    print "Error|Exit code "Result" converting \""Track"\""
  } else {
    if (Recycle=="") {
      # No Recycle Bin, so check for non-zero size new file and delete the old one
      if (Debug) print "Debug|Deleting: \""Track"\" and setting permissions on \""NewTrack"\""
      #Command="[ -s \""NewTrack"\" ] && [ -f \""Track"\" ] && chown --reference=\""Track"\" \""NewTrack"\" && chmod --reference=\""Track"\" \""NewTrack"\" && rm \""Track"\""
      Command="if [ -s \""NewTrack"\" ]; then if [ -f \""Track"\" ]; then chown --reference=\""Track"\" \""NewTrack"\"; chmod --reference=\""Track"\" \""NewTrack"\"; rm \""Track"\"; fi; fi"
      if (Debug) print "Debug|Executing: "Command
      system(Command)
    } else {
      # Recycle Bin is configured, so check if it exists, append a relative path to it from the track, check for non-zero size new file, and move the old one to the Recycle Bin
      match(Track,/^\/?[^\/]+\//)
      RecPath=substr(Track,RSTART+RLENGTH)
      sub(/[^\/]+$/,"",RecPath)
      RecPath=Recycle RecPath
      if (Debug) print "Debug|Recycling: \""Track"\" to \""RecPath"\" and setting permissions on \""NewTrack"\""
      Command="if [ ! -e \""RecPath"\" ]; then mkdir -p \""RecPath"\"; fi; if [ -s \""NewTrack"\" ]; then if [ -f \""Track"\" ]; then chown --reference=\""Track"\" \""NewTrack"\"; chmod --reference=\""Track"\" \""NewTrack"\"; mv -t \""RecPath"\" \""Track"\"; fi; fi"
      if (Debug) print "Debug|Executing: "Command
      system(Command)
    }
  }
}
' | log

#### END MAIN

# Check for awk script completion
flac2mp3_return="${PIPESTATUS[1]}"    # captures awk exit status
if [ $flac2mp3_return != "0" ]; then
  flac2mp3_message="Error|Script exited abnormally.  File permissions issue?"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 10
fi

# Call Lidarr API to RescanArtist
if [ -n "$flac2mp3_api_url" ]; then
  if [ "$lidarr_artist_id" ]; then
    # Scan the disk for the new audio tracks
    if rescan; then
      # Check that the rescan completed
      if ! check_rescan; then
        # Timeout or failure
        flac2mp3_message="Warn|Lidarr job ID $flac2mp3_jobid timed out or failed."
        echo "$flac2mp3_message" | log
        echo "$flac2mp3_message" >&2
      fi
    else
      # Error from API
      flac2mp3_message="Error|The 'RefreshArtist' API with artist $lidarr_artist_id failed."
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
    fi
  else
    # No Artist ID means we can't call the API
    flac2mp3_message="Warn|Missing environment variable lidarr_artist_id"
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  fi
else
  # No URL means we can't call the API
  flac2mp3_message="Warn|Unable to determine Lidarr API URL."
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
fi

# Cool bash feature
flac2mp3_message="Info|Completed in $(($SECONDS/60))m $(($SECONDS%60))s"
echo "$flac2mp3_message" | log
