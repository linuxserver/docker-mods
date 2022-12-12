#!/bin/bash

# Script to convert FLAC files to MP3 using FFmpeg
#  Dev/test: https://github.com/TheCaptain989/lidarr-flac2mp3
#  Prod: https://github.com/linuxserver/docker-mods/tree/lidarr-flac2mp3
# Resultant MP3s are fully tagged and retain same permissions as original file

# Dependencies:
#  ffmpeg
#  ffprobe
#  awk
#  curl
#  jq
#  stat
#  nice
#  basename
#  printenv
#  chmod

# Exit codes:
#  0 - success; or test
#  1 - no audio tracks detected
#  2 - ffmpeg not found
#  3 - invalid command line arguments
#  5 - specified audio file not found
#  6 - error when creating output directory
#  7 - unknown eventtype environment variable
# 10 - awk script generated an error
# 20 - general error

### Variables
export flac2mp3_script=$(basename "$0")
export flac2mp3_ver="{{VERSION}}"
export flac2mp3_pid=$$
export flac2mp3_config=/config/config.xml
export flac2mp3_log=/config/logs/flac2mp3.txt
export flac2mp3_maxlogsize=1024000
export flac2mp3_maxlog=4
export flac2mp3_debug=0
export flac2mp3_keep=0
export flac2mp3_type=$(printenv | sed -n 's/_eventtype *=.*$//p')

# Usage function
function usage {
  usage="
$flac2mp3_script   Version: $flac2mp3_ver
Audio conversion script designed for use with Lidarr

Source: https://github.com/TheCaptain989/lidarr-flac2mp3

Usage:
  $0 [{-d|--debug} [<level>]] [{-b|--bitrate} <bitrate> | {-v|--quality} <quality> | {-a|--advanced} \"<options>\" {-e|--extension} <extension>] [{-f|--file} <audio_file>] [{-k|--keepfile}] [{-o|--output} <directory>] [{-r|--regex} '<regex>'] [{-t|--tags} <taglist>]

Options:
  -d, --debug [<level>]         Enable debug logging
                                level is optional, between 1-3
                                1 is lowest, 3 is highest
                                [default: 1]
  -b, --bitrate <bitrate>       Set output quality in constant bits per second
                                [default: 320k]
                                Ex: 160k, 240k, 300000
  -v, --quality <quality>       Set variable bitrate; quality between 0-9
                                0 is highest quality, 9 is lowest
                                For more details, see:
                                https://trac.ffmpeg.org/wiki/Encode/MP3
  -a, --advanced \"<options>\"    Advanced ffmpeg options enclosed in quotes
                                Specified options replace all script defaults
                                and are sent as entered to ffmpeg for
                                processing.
                                For more details on valid options, see:
                                https://ffmpeg.org/ffmpeg.html#Options
                                WARNING: You must specify an audio codec!
                                WARNING: Invalid options could result in script
                                failure!
                                Requires -e option to also be specified
                                For more details, see:
                                https://github.com/TheCaptain989/lidarr-flac2mp3
  -e, --extension <extension>   File extension for output file, with or without
                                dot
                                Required when -a is specified!
  -f, --file <audio_file>       The script enters batch mode, using the
                                specified audio file as input
                                WARNING: Do not use this argument when called
                                from Lidarr!
  -o, --output <directory>      Specify a destination directory for the
                                converted audio file(s)
                                It will be created if it does not exist.
  -k, --keep-file               Do not delete the source file or move it to the
                                Lidarr Recycle bin
                                This also disables the Lidarr rescan.
  -r, --regex  '<regex>'        Regular expression used to select input files
                                [default: \.flac$]
  -t, --tags <taglist>          Comma separated list of metadata tags to apply
                                automated corrections to.
                                Supports: disc, genre
      --help                    Display this help and exit
      --version                 Display script version and exit

Examples:
  $flac2mp3_script -b 320k           # Output 320 kbit/s MP3 (non-VBR; same as
                                  default behavior)
  $flac2mp3_script -v 0              # Output variable bitrate MP3, VBR 220-260
                                  kbit/s
  $flac2mp3_script -d -b 160k        # Enable debugging level 1 and output a
                                  160 kbit/s MP3
  $flac2mp3_script -r '\\\\.[^.]*$'    # Convert any file to MP3 (not just FLAC)
  $flac2mp3_script -a \"-c:v libtheora -map 0 -q:v 10 -c:a libopus -b:a 192k\" -e .opus
                                # Convert to Opus format, 192 kbit/s, cover art
  $flac2mp3_script -a \"-vn -c:a libopus -b:a 192K\" -e .opus -r '\.mp3$'
                                # Convert .mp3 files to Opus format, 192 kbit/s
                                  no cover art
  $flac2mp3_script -a \"-y -map 0 -c:a aac -b:a 240K -c:v copy\" -e mp4
                                # Convert to MP4 format, using AAC 240 kbit/s
                                  audio, cover art, overwrite file
  $flac2mp3_script -f \"/path/to/audio/a-ha/Hunting High and Low/01 Take on Me.flac\"
                                # Batch Mode
                                  Output 320 kbit/s MP3
  $flac2mp3_script -o \"/path/to/audio\" -k
                                # Place the converted file(s) in specified
                                  directory and do not delete the original
                                  audio file(s)
"
  echo "$usage" >&2
}

# Check for environment variable arguments
if [ -n "$FLAC2MP3_ARGS" ]; then
  if [ $# -ne 0 ]; then
    flac2mp3_prelogmessage="Warning|FLAC2MP3_ARGS environment variable set but will be ignored because command line arguments were also specified."
  else
    # Move the environment variable arguments to the command line for processing
    flac2mp3_prelogmessage="Info|Using settings from environment variable."
    eval set -- "$FLAC2MP3_ARGS"
  fi
fi

# Process arguments
while (( "$#" )); do
  case "$1" in
    -d|--debug ) # Enable debugging, with optional level
      if [ -n "$2" ] && [ ${2:0:1} != "-" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
        export flac2mp3_debug=$2
        shift 2
      else
        export flac2mp3_debug=1
        shift
      fi
      ;;
    --help ) # Display usage
      usage
      exit 0
      ;;
    --version ) # Display version
      echo "$flac2mp3_script $flac2mp3_ver"
      exit 0
      ;;
    -f|--file ) # Batch Mode
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        # Overrides detected *_eventtype
        export flac2mp3_type="batch"
        export flac2mp3_tracks="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -b|--bitrate ) # Set constant bit rate
      if [ -n "$flac2mp3_vbrquality" ]; then
        echo "Error|Both -b and -v options cannot be set at the same time." >&2
        usage
        exit 3
      elif [ -n "$flac2mp3_ffmpegadv" -o -n "$flac2mp3_extension" ]; then
        echo "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
        usage
        exit 3
      elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_bitrate="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -v|--quality ) # Set variable quality
      if [ -n "$flac2mp3_bitrate" ]; then
        echo "Error|Both -v and -b options cannot be set at the same time." >&2
        usage
        exit 3
      elif [ -n "$flac2mp3_ffmpegadv" -o -n "$flac2mp3_extension" ]; then
        echo "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
        usage
        exit 3
      elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_vbrquality="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -a|--advanced ) # Set advanced options
      if [ -n "$flac2mp3_vbrquality" -o -n "$flac2mp3_bitrate" ]; then
        echo "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
        usage
        exit 3
      elif [ -n "$2" ]; then
        export flac2mp3_ffmpegadv="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -e|--extension ) # Set file extension
      if [ -n "$flac2mp3_vbrquality" -o -n "$flac2mp3_bitrate" ]; then
        echo "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
        usage
        exit 3
      elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_extension="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      # Test for dot prefix
      [ "${flac2mp3_extension:0:1}" != "." ] && flac2mp3_extension=".${flac2mp3_extension}"
      ;;
    -o|--output ) # Set output directory
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_output="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      # Test for trailing backslash
      [ "${flac2mp3_output: -1:1}" != "/" ] && flac2mp3_output="${flac2mp3_output}/"
      ;;
    -k|--keep-file ) # Do not delete source file(s)
      export flac2mp3_keep=1
      shift
      ;;
    -r|--regex ) # Sets the regex used to match input files
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_regex="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -t|--tags ) # Metadata tags to correct
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_tags="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      fi
      ;;
    -*|--*=) # Unknown option
      echo "Error|Unknown option: $1" >&2
      usage
      exit 20
      ;;
    *) # Remove unknown positional parameters
      shift
      ;;
  esac
done

# Test for either -a and -e, but not both: logical XOR = non-equality
if [ "${flac2mp3_ffmpegadv:+data}" != "${flac2mp3_extension:+data}" ]; then
  echo "Error|The -a and -e options must be specified together." >&2
  usage
  exit 3
fi

# Set default bit rate
[ -z "$flac2mp3_vbrquality" -a -z "$flac2mp3_bitrate" -a -z "$flac2mp3_ffmpegadv" -a -z "$flac2mp3_extension" ] && flac2mp3_bitrate="320k"

## Mode specific variables
if [[ "${flac2mp3_type,,}" = "batch" ]]; then
  # Batch mode
  export lidarr_eventtype="Convert"
elif [[ "${flac2mp3_type,,}" = "lidarr" ]]; then
  export flac2mp3_tracks="$lidarr_addedtrackpaths"
  # Catch for other environment variable
  [ -z "$flac2mp3_tracks" ] && flac2mp3_tracks="$lidarr_trackfile_path"
else
  # Called in an unexpected way
  echo -e "Error|Unknown or missing 'lidarr_eventtype' environment variable: ${flac2mp3_type}\nNot called from Lidarr.\nTry using Batch Mode option: -f <file>"
  exit 7
fi

### Functions

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
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Forcing rescan of artist '$lidarr_artist_id'. Calling Lidarr API 'RefreshArtist' using POST and URL '$flac2mp3_api_url/command'" | log
  flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"RefreshArtist\", \"artistId\": $lidarr_artist_id}" \
    -X POST "$flac2mp3_api_url/command")
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
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
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Checking job $flac2mp3_jobid completion, try #$i. Calling Lidarr API using GET and URL '$flac2mp3_api_url/command/$flac2mp3_jobid'" | log
    flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
      -H "Content-Type: application/json" \
      -X GET "$flac2mp3_api_url/command/$flac2mp3_jobid")
    [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
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
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|Job not done. Waiting 1 second." | log
        sleep 1
      fi
    fi
  done
  return $flac2mp3_return
}
### End Functions

# Check for required binaries
if [ ! -f "/usr/bin/ffmpeg" ]; then
  flac2mp3_message="Error|/usr/bin/ffmpeg is required by this script"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 2
fi
if [ ! -f "/usr/bin/ffprobe" ]; then
  flac2mp3_message="Error|/usr/bin/ffprobe is required by this script"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 2
fi

# Log Debug state
if [ $flac2mp3_debug -ge 1 ]; then
  flac2mp3_message="Debug|Enabling debug logging level ${flac2mp3_debug}. Starting ${lidarr_eventtype^} run."
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message"
fi

# Log FLAC2MP3_ARGS usage
if [ -n "$flac2mp3_prelogmessage" ]; then
  # flac2mp3_prelogmessage is set above, before argument processing
  echo "$flac2mp3_prelogmessage" | log
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|FLAC2MP3_ARGS: ${FLAC2MP3_ARGS}" | log
fi

# Log environment
[ $flac2mp3_debug -ge 2 ] && printenv | sort | sed 's/^/Debug|/' | log

# Log Batch mode
if [ "$flac2mp3_type" = "batch" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Switching to batch mode. Input filename: ${flac2mp3_tracks}" | log
fi

# Check for config file
if [ "$flac2mp3_type" = "batch" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Not using config file in batch mode." | log
elif [ -f "$flac2mp3_config" ]; then
  # Read Lidarr config.xml
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Reading from Lidarr config file '$flac2mp3_config'" | log
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
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Getting Lidarr version. Calling Lidarr API using GET and URL '$flac2mp3_api_url/system/status'" | log
  flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
    -X GET "$flac2mp3_api_url/system/status")
  flac2mp3_return=$?; [ "$flac2mp3_return" != 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] curl error when parsing: \"$flac2mp3_api_url/system/status\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  flac2mp3_version="$(echo $flac2mp3_result | jq -crM .version)"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detected Lidarr version $flac2mp3_version" | log

  # Get RecycleBin
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Getting Lidarr RecycleBin. Calling Lidarr API using GET and URL '$flac2mp3_api_url/config/mediamanagement'" | log
  flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
    -X GET "$flac2mp3_api_url/config/mediamanagement")
  flac2mp3_return=$?; [ "$flac2mp3_return" != 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] curl error when parsing: \"$flac2mp3_api_url/config/mediamanagement\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  flac2mp3_recyclebin="$(echo $flac2mp3_result | jq -crM .recycleBin)"
  # Test for trailing backslash
  [ ${#flac2mp3_recyclebin} -ne 0 -a "${flac2mp3_recyclebin: -1:1}" != "/" ] && flac2mp3_recyclebin="${flac2mp3_recyclebin}/"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detected Lidarr RecycleBin '$flac2mp3_recyclebin'" | log
  
  # Get root folder path from Artist info
  if [ "$lidarr_artist_id" != "" ]; then
    flac2mp3_result=$(curl -s -H "X-Api-Key: $flac2mp3_apikey" \
      -H "Content-Type: application/json" \
      -X GET $flac2mp3_api_url/artist/$lidarr_artist_id)
    flac2mp3_return=$?; [ "$flac2mp3_return" != 0 ] && {
      flac2mp3_message="Error|[$flac2mp3_return] curl error when parsing: \"$flac2mp3_api_url/artist/$lidarr_artist_id\""
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
    }
    [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
    flac2mp3_root="$(echo $flac2mp3_result | jq -crM .rootFolderPath)"
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detected Lidarr Root Folder '$flac2mp3_root'" | log
  fi
else
  # No config file means we can't call the API. Best effort at this point.
  flac2mp3_message="Warn|Unable to locate Lidarr config file: '$flac2mp3_config'"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
fi

# Handle Lidarr Test event
if [[ "$lidarr_eventtype" = "Test" ]]; then
  echo "Info|Lidarr event: $lidarr_eventtype" | log
  flac2mp3_message="Info|Script was test executed successfully."
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message"
  exit 0
fi

# Check if source audio file exists
if [ "$flac2mp3_type" = "batch" -a ! -f "$flac2mp3_tracks" ]; then
  flac2mp3_message="Error|Input file not found: \"$flac2mp3_tracks\""
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 5
fi

# Check for empty track variable
if [ -z "$flac2mp3_tracks" ]; then
  flac2mp3_message="Error|No audio tracks were detected or specified!"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 1
fi

# If specified, check if destination folder exists and create if necessary
if [ "$flac2mp3_output" -a ! -d "$flac2mp3_output" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Destination directory does not exist. Creating: $flac2mp3_output" | log
  mkdir -p "$flac2mp3_output"
  flac2mp3_return=$?; [ "$flac2mp3_return" != 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] mkdir returned an error. Unable to create output directory."
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    exit 6
  }
fi

# Legacy one-liner script for posterity
#find "$lidarr_artist_path" -name "*.flac" -exec bash -c 'ffmpeg -loglevel warning -i "{}" -y -acodec libmp3lame -b:a 320k "${0/.flac}.mp3" && rm "{}"' {} \;

#### BEGIN MAIN
# Build dynamic log message
flac2mp3_message="Info|Lidarr event: ${lidarr_eventtype}"
if [ "$flac2mp3_type" != "batch" ]; then
  flac2mp3_message+=", Artist: ${lidarr_artist_name} (${lidarr_artist_id}), Album: ${lidarr_album_title} (${lidarr_album_id})"
fi
if [ -z "$flac2mp3_ffmpegadv" ]; then
  flac2mp3_message+=", Export bitrate: ${flac2mp3_bitrate:-$flac2mp3_vbrquality}"
else
  flac2mp3_message+=", Advanced options: '${flac2mp3_ffmpegadv}', File extension: ${flac2mp3_extension}"
fi
if [ -n "$flac2mp3_output" ]; then
  flac2mp3_message+=", Output: ${flac2mp3_output}"
fi
if [ $flac2mp3_keep = 1 ]; then
  flac2mp3_message+=", Keep source"
fi
if [ -n "$flac2mp3_regex" ]; then
  flac2mp3_message+=", Matching regex: '${flac2mp3_regex}'"
fi
flac2mp3_message+=", Track(s): ${flac2mp3_tracks}"
echo "${flac2mp3_message}" | log

# Process tracks
echo -n "$flac2mp3_tracks" | awk -v Debug=$flac2mp3_debug \
-v Recycle="$flac2mp3_recyclebin" \
-v Bitrate="$flac2mp3_bitrate" \
-v VBR="$flac2mp3_vbrquality" \
-v FFmpegADV="$flac2mp3_ffmpegadv" \
-v Ext="$flac2mp3_extension" \
-v Output="$flac2mp3_output" \
-v Keep=$flac2mp3_keep \
-v Pat="$flac2mp3_regex" \
-v Root="$flac2mp3_root" \
-v Taglist="$flac2mp3_tags" '
BEGIN {
  FFmpeg = "/usr/bin/ffmpeg"
  FS = "|"
  RS = "|"
  IGNORECASE = 1
  # Set default extension, pattern, and logging values
  if (Ext == "") Ext = ".mp3"
  if (Pat == "") Pat = "\\.flac$"
  if (Debug == 0) FFmpegLOG = "error"
  else if (Debug == 1) FFmpegLOG = "warning"
  else if (Debug >= 2) FFmpegLOG = "info"
  if (Bitrate) {
    if (Debug >= 1) print "Debug|Using constant bitrate of "Bitrate
    BrCommand = "-b:a "Bitrate
  } else if (VBR >= 0) {
    if (Debug >= 1) print "Debug|Using variable quality of "VBR
    BrCommand = "-q:a "VBR
  } else if (FFmpegADV) {
    if (Debug >= 1) print "Debug|Using advanced ffmpeg options \""FFmpegADV"\""
    if (Debug >= 1) print "Debug|Exporting with file extension \""Ext"\""
    FFmpegOPTS = FFmpegADV
  }
  if (Debug >= 1) print "Debug|Matching tracks against regex \""Pat"\""
  # Set default ffmpeg options
  if (FFmpegOPTS == "") FFmpegOPTS = "-c:v copy -map 0 -y -acodec libmp3lame "BrCommand" -write_id3v1 1 -id3v2_version 3"
}
$0 !~ Pat {
  if (Debug >= 1) print "Debug|Skipping track that did not match regex: "$0
}
$0 ~ Pat {
  # Get each audio file name and create a new track name with the given extension
  Track = $0
  Last = split(Track, Parts, ".")
  NewTrack = substr(Track, 1, length(Track) - length(Parts[Last]) - 1) Ext
  # Redirect output if asked
  if (Output) sub(/^.*\//, Output, NewTrack)
  # Check for same track name
  if (Track == NewTrack) {
    print "Error|The original track name and new name are the same! Skipping track: "Track
    next
  }
  # Set metadata options to fix tags if asked
  if (Taglist) {
    Metadata = ""; JSON = ""
    NumTags = split(Taglist, Tag, ",")
    if (Debug >= 1) print "Debug|Detecting and fixing common problems with the following metadata tags: "Taglist
    Command = "/usr/bin/ffprobe -hide_banner -loglevel fatal -print_format json=compact=1 -show_format -show_entries \"format=tags : format_tags=disc,genre\" -i \""Track"\" 2>&1"
    if (Debug >= 2) print "Debug|Executing: "Command
    # Concatenate FFprobe output into one line
    while (Command | getline Line) JSON = JSON Line
    for (i = 1; i <= NumTags; i++) {
      if (Tag[i] == "disc") {
        # Fix one disc by itself (\47 is single quote in octal)
        Command = "echo \47"JSON"\47 | jq -crM \47.format.tags.disc\47 2>&1"
        if (Debug >= 2) print "Debug|Executing: "Command
        Command | getline Disc
        sub(/\n/, "", Disc)    # I do not yet know why this is needed
        if (Debug >= 1) print "Debug|Discovered disc: "Disc
        if (Disc ~ /^1$/) Metadata = "-metadata disc=\"1/1\" "Metadata
      }
      if (Tag[i] == "genre") {
        # Fix multiple genres
        Command = "echo \47"JSON"\47 | jq -crM \47.format.tags | to_entries[] | select(.key | match(\"genre\";\"i\")).value\47 2>&1"
        if (Debug >= 2) print "Debug|Executing: "Command
        Command | getline Genre
        sub(/\n/, "", Genre)   # I do not yet know why this is needed
        if (Debug >= 1) print "Debug|Discovered genre: "Genre
        if (Genre ~ /;/) {
          if (Genre ~ /Pop/) Metadata = "-metadata genre=\"Pop\" "Metadata
          else if (Genre ~ /Indie/) Metadata = "-metadata genre=\"Alternative & Indie\" "Metadata
          else if (Genre ~ /Industrial/) Metadata = "-metadata genre=\"Industrial Rock\" "Metadata
          else if (Genre ~ /Electronic/) Metadata = "-metadata genre=\"Electronica & Dance\" "Metadata
          else if (Genre ~ /Punk|Alternative/) Metadata = "-metadata genre=\"Alternative & Punk\" "Metadata
          else if (Genre ~ /Rock/) Metadata = "-metadata genre=\"Rock\" "Metadata
        }
      }
      if (Debug >= 2) print "Debug|Metadata on pass "i"/"NumTags": "Metadata
    }
  }
  print "Info|Writing: "NewTrack
  # Convert the track
  Command = "nice "FFmpeg" -loglevel "FFmpegLOG" -nostdin -i \""Track"\" "FFmpegOPTS" "Metadata"\""NewTrack"\" 2>&1"
  if (Debug >= 1) print "Debug|Executing: "Command
  Result = system(Command)
  if (Debug >= 2) print "Debug|ffmpeg exited"
  if (Result) {
    print "Error|Exit code "Result" converting \""Track"\""
  } else {
    # Build system command to set owner and permissions, etc.
    if (Keep == 1) {
      # Do not delete the source file
      if (Debug >= 1) print "Debug|Keeping original: \""Track"\" and setting permissions on \""NewTrack"\""
      Command = "if [ -s \""NewTrack"\" ]; then if [ -f \""Track"\" ]; then chown --reference=\""Track"\" \""NewTrack"\"; chmod --reference=\""Track"\" \""NewTrack"\"; fi; fi"
    } else {
      if (Recycle == "") {
        # No Recycle Bin, so check for non-zero size new file and delete the old one
        if (Debug >= 1) print "Debug|Deleting: \""Track"\" and setting permissions on \""NewTrack"\""
        Command = "if [ -s \""NewTrack"\" ]; then if [ -f \""Track"\" ]; then chown --reference=\""Track"\" \""NewTrack"\"; chmod --reference=\""Track"\" \""NewTrack"\"; rm \""Track"\"; fi; fi"
      } else {
        # Recycle Bin is configured, so check if it exists, append a relative path to it from the track, check for non-zero size new file, and move the old one to the Recycle Bin
        if (Root == "") {
          # Legacy way in case the Root music folder cannot be determined
          print "Warning|Root music folder is blank. Falling back to legacy split method."
          match(Track, /^\/?[^\/]+\//)
        } else {
          # The following logic tests that the Root folder is a substring of the Track folder, though based on the observed Lidarr behavior this should be a safe assumption. A warning is displayed just in case.
          RSTART = index(Track, Root)
          if (RSTART) {
            RLENGTH = length(Root)
          } else {
            print "Warning|The root music folder \""Root"\" is not part of \""Track"\". Recycled tracks may not appear as expected."
            RLENGTH = 0
          }
        }
        if (Debug >= 2) print "Debug|Splitting track name on RSTART: "RSTART", RLENGTH: "RLENGTH" to prepend recycle path."
        RecPath = substr(Track, RSTART + RLENGTH)
        sub(/^\/+/, "", RecPath)  # remove trailing track name
        sub(/[^\/]+$/, "", RecPath)  # remove leading backslash
        RecPath = Recycle RecPath
        if (Debug >= 1) print "Debug|Recycling: \""Track"\" to \""RecPath"\" and setting permissions on \""NewTrack"\""
        Command = "if [ ! -e \""RecPath"\" ]; then mkdir -p \""RecPath"\"; fi; if [ -s \""NewTrack"\" ]; then if [ -f \""Track"\" ]; then chown --reference=\""Track"\" \""NewTrack"\"; chmod --reference=\""Track"\" \""NewTrack"\"; mv -t \""RecPath"\" \""Track"\"; fi; fi"
      }
    }
    # Set owner, permissions, etc.
    if (Debug >= 2) print "Debug|Executing: "Command
    Result = system(Command)
    if (Result) {
      print "Error|Exit code "Result" setting permissions and/or recycling on \""NewTrack"\""
    }
  }
}
' | log
#### END MAIN

# Check for awk script completion
flac2mp3_return="${PIPESTATUS[1]}"    # captures awk exit status
[ $flac2mp3_debug -ge 2 ] && echo "Debug|awk exited with code: $flac2mp3_return" | log
if [ "$flac2mp3_return" != 0 ]; then
  flac2mp3_message="Error|[$flac2mp3_return] Script exited abnormally. File permissions issue?"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  exit 10
fi

# Call Lidarr API to RescanArtist
if [ "$flac2mp3_type" = "batch" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Cannot use API in batch mode." | log
elif [ $flac2mp3_keep -eq 1 ]; then
  echo "Info|Original audio file(s) kept, no rescan performed." | log
elif [ -n "$flac2mp3_api_url" ]; then
  # Check for artist ID
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
