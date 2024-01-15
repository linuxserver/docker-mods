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
#  dirname
#  printenv
#  chmod
#  tr
#  sed

# Exit codes:
#  0 - success; or test
#  1 - no audio tracks detected
#  2 - ffmpeg not found
#  3 - invalid command line arguments
#  4 - log file is not writable
#  5 - specified audio file not found
#  6 - error when creating output directory
#  7 - unknown eventtype environment variable
# 10 - a general error occurred in file conversion loop; check log
# 11 - source and destination have the same file name
# 12 - ffprobe returned an error
# 13 - ffmpeg returned an error
# 14 - the new file could not be found or is zero bytes
# 15 - could not set permissions and/or owner on new file
# 16 - could not delete the original file
# 17 - Lidarr API error
# 18 - Lidarr job timeout
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
  $0 [{-b|--bitrate} <bitrate> | {-v|--quality} <quality> | {-a|--advanced} \"<options>\" {-e|--extension} <extension>] [{-f|--file} <audio_file>] [{-k|--keep-file}] [{-o|--output} <directory>] [{-r|--regex} '<regex>'] [{-t|--tags} <taglist>] [{-l|--log} <log_file>] [{-d|--debug} [<level>]]

Options:
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
  -l, --log <log_file>          log filename
                                [default: /config/log/flac2mp3.txt]
  -d, --debug [<level>]         Enable debug logging
                                level is optional, between 1-3
                                1 is lowest, 3 is highest
                                [default: 1]
      --help                    Display this help and exit
      --version                 Display script version and exit

Examples:
  $flac2mp3_script -b 320k           # Output 320 kbit/s MP3 (non-VBR; same as
                                  default behavior)
  $flac2mp3_script -v 0              # Output variable bitrate MP3, VBR 220-260
                                  kbit/s
  $flac2mp3_script -d -b 160k        # Enable debugging level 1 and output a
                                  160 kbit/s MP3
  $flac2mp3_script -r '\\\\.[^.]*\$'    # Convert any file to MP3 (not just FLAC)
  $flac2mp3_script -a \"-c:v libtheora -map 0 -q:v 10 -c:a libopus -b:a 192k\" -e .opus
                                # Convert to Opus format, 192 kbit/s, cover art
  $flac2mp3_script -a \"-vn -c:a libopus -b:a 192K\" -e .opus -r '\.mp3\$'
                                # Convert .mp3 files to Opus format, 192 kbit/s
                                  no cover art
  $flac2mp3_script -a \"-y -map 0 -c:a aac -b:a 240K -c:v copy\" -e m4a
                                # Convert to M4A format, using AAC 240 kbit/s
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
    -l|--log ) # Log file
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export flac2mp3_log="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 1
      fi
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
      # Test for trailing slash
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
    -*) # Unknown option
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

# Set default new track extension
flac2mp3_extension="${flac2mp3_extension:-.mp3}"

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
# Check Lidarr version
function get_version {
  local url="$flac2mp3_api_url/system/status"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Getting Lidarr version. Calling Lidarr API using GET and URL '$url'" | log
  unset flac2mp3_result
  flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --get "$url")
  local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $flac2mp3_result | jq -crM '.version?')" != "null" ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Check result of command job
function check_job {
  # Exit codes:
  #  0 - success
  #  1 - queued
  #  2 - failed
  #  3 - loop timed out
  # 10 - curl error
  local i=0
  local url="$flac2mp3_api_url/command/$flac2mp3_jobid"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Checking job $flac2mp3_jobid completion. Calling Lidarr API using GET and URL '$url'" | log
  for ((i=1; i <= 15; i++)); do
    unset flac2mp3_result
    flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --get "$url")
    local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
      local flac2mp3_return=10
      break
    }
    [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log

    # Guard clauses
    if [ "$(echo $flac2mp3_result | jq -crM .status)" = "failed" ]; then
      local flac2mp3_return=2
      break
    fi
    if [ "$(echo $flac2mp3_result | jq -crM .status)" = "queued" ]; then
      local flac2mp3_return=1
      break
    fi
    if [ "$(echo $flac2mp3_result | jq -crM .status)" = "completed" ]; then
      local flac2mp3_return=0
      break
    fi

    # It may have timed out, so let's wait a second
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Job not done. Waiting 1 second." | log
    local flac2mp3_return=3
    sleep 1
  done
  return $flac2mp3_return
}
# Get all track files from album
function get_trackfile_info {
  local url="$flac2mp3_api_url/trackFile"
  local data="albumId=$lidarr_album_id"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Getting track file info for album id $lidarr_album_id. Calling Lidarr API using GET and URL '$url?$data'" | log
  unset flac2mp3_result
  flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    --get "$url")
  local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url?$data\"\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  if [ $flac2mp3_curlret -eq 0 -a "$(echo $flac2mp3_result | jq -crM '.[].id?')" != "null" ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Delete track
function delete_track {
  local url="$flac2mp3_api_url/trackFile/$1"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Deleting or recycling \"$flac2mp3_track\". Calling Lidarr API using DELETE and URL '$url'" | log
  unset flac2mp3_result
  flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -X DELETE "$url")
  local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  if [ $flac2mp3_curlret -eq 0 ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Get file details on possible files to import into Lidarr
function get_import_info {
  local url="$flac2mp3_api_url/manualimport"
  local data="artistId=$lidarr_artist_id&folder=$lidarr_artist_path&filterExistingFiles=true&replaceExistingFiles=false"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Getting list of files that can be imported. Calling Lidarr API using GET and URL '$url?$data'" | log
  unset flac2mp3_result
  flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --data-urlencode "artistId=$lidarr_artist_id" \
    --data-urlencode "folder=$lidarr_artist_path" \
    -d "filterExistingFiles=true" \
    -d "replaceExistingFiles=false" \
    --get "$url")
  local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url?$data\"\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 3 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  if [ $flac2mp3_curlret -eq 0 ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Import new track into Lidarr
function import_tracks {
  local url="$flac2mp3_api_url/command"
  local data="{\"name\":\"ManualImport\",\"files\":$flac2mp3_json,\"importMode\":\"auto\",\"replaceExistingFiles\":false}"
  echo "Info|Calling Lidarr API to import tracks" | log
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Importing $flac2mp3_import_count new files into Lidarr. Calling Lidarr API using POST and URL '$url' with data $data" | log
  unset flac2mp3_result
  flac2mp3_result=$(curl -s --fail-with-body -H "X-Api-Key: $flac2mp3_apikey" \
    --json "{\"name\":\"ManualImport\"," \
    --json "\"files\":$flac2mp3_json," \
    --json "\"importMode\":\"auto\",\"replaceExistingFiles\":false}" \
    "$url")
  local flac2mp3_curlret=$?; [ $flac2mp3_curlret -ne 0 ] && {
    local flac2mp3_message=$(echo -e "[$flac2mp3_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $flac2mp3_result | jq -crM .message?)" | awk '{print "Error|"$0}')
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  if [ $flac2mp3_curlret -eq 0 -a "$(echo $flac2mp3_result | jq .id?)" != "null" ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Get track media info from ffprobe
function ffprobe {
  [ $flac2mp3_debug -ge 2 ] && echo "Debug|Executing: /usr/bin/ffprobe -hide_banner -loglevel $flac2mp3_ffmpeg_log -print_format json=compact=1 -show_format -show_entries \"format=tags : format_tags=title,disc,genre\" -i \"$1\"" | log
  unset flac2mp3_ffprobe_json
  flac2mp3_ffprobe_json=$(/usr/bin/ffprobe -hide_banner -loglevel $flac2mp3_ffmpeg_log -print_format json=compact=1 -show_format -show_entries "format=tags : format_tags=title,disc,genre" -i "$1")
  flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] ffprobe error when inspecting track: \"$1\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  }
  [ $flac2mp3_debug -ge 2 ] && echo "ffprobe returned: $flac2mp3_ffprobe_json" | awk '{print "Debug|"$0}' | log
  if [ "$flac2mp3_ffprobe_json" != "" ]; then
    local flac2mp3_return=0
  else
    local flac2mp3_return=1
  fi
  return $flac2mp3_return
}
# Exit program
function end_script {
  # Cool bash feature
  flac2mp3_message="Info|Completed in $((SECONDS/60))m $((SECONDS%60))s"
  echo "$flac2mp3_message" | log
  [ "$1" != "" ] && flac2mp3_exitstatus=$1
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Exit code ${flac2mp3_exitstatus:-0}" | log
  exit ${flac2mp3_exitstatus:-0}
}
### End Functions

# Check that log path exists
if [ ! -d "$(dirname $flac2mp3_log)" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Log file path does not exist: '$(dirname $flac2mp3_log)'. Using log file in current directory."
  flac2mp3_log=./flac2mp3.txt
fi

# Check that the log file exists
if [ ! -f "$flac2mp3_log" ]; then
  echo "Info|Creating a new log file: $flac2mp3_log"
  touch "$flac2mp3_log" 2>&1
fi

# Check that the log file is writable
if [ ! -w "$flac2mp3_log" ]; then
  echo "Error|Log file '$flac2mp3_log' is not writable or does not exist." >&2
  flac2mp3_log=/dev/null
  flac2mp3_exitstatus=4
fi

# Check for required binaries
if [ ! -f "/usr/bin/ffmpeg" ]; then
  flac2mp3_message="Error|/usr/bin/ffmpeg is required by this script"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  end_script 2
fi
if [ ! -f "/usr/bin/ffprobe" ]; then
  flac2mp3_message="Error|/usr/bin/ffprobe is required by this script"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  end_script 2
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

# Handle Lidarr Test event
if [[ "$lidarr_eventtype" = "Test" ]]; then
  echo "Info|Lidarr event: $lidarr_eventtype" | log
  flac2mp3_message="Info|Script was test executed successfully."
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message"
  end_script
fi

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

  # Check for localhost
  [[ $flac2mp3_bindaddress = "*" ]] && flac2mp3_bindaddress=localhost

  # Strip leading and trailing forward slashes from URL base
  flac2mp3_urlbase="$(echo "$flac2mp3_urlbase" | sed -re 's/^\/+//; s/\/+$//')"

  # Build URL to Lidarr API
  flac2mp3_api_url="http://$flac2mp3_bindaddress:$flac2mp3_port${flac2mp3_urlbase:+/$flac2mp3_urlbase}/api/v1"

  # Check Lidarr version
  if get_version; then
    flac2mp3_version="$(echo $flac2mp3_result | jq -crM .version)"
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detected Lidarr version $flac2mp3_version" | log
  fi

  # Get album trackfile info. Need the IDs to delete the old tracks.
  if get_trackfile_info; then
    flac2mp3_trackfiles="$flac2mp3_result"
  else
    flac2mp3_message="Warn|Unable to get trackfile info for album ID $lidarr_album_id"
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
  fi
else
  # No config file means we can't call the API. Best effort at this point.
  flac2mp3_message="Warn|Unable to locate Lidarr config file: '$flac2mp3_config'"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
fi

# Check if source audio file exists
if [ "$flac2mp3_type" = "batch" -a ! -f "$flac2mp3_tracks" ]; then
  flac2mp3_message="Error|Input file not found: \"$flac2mp3_tracks\""
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  end_script 5
fi

# Check for empty tracks variable
if [ -z "$flac2mp3_tracks" ]; then
  flac2mp3_message="Error|No audio tracks were detected or specified!"
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  end_script 1
fi

# If specified, check if destination folder exists and create if necessary
if [ "$flac2mp3_output" -a ! -d "$flac2mp3_output" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Destination directory does not exist. Creating: $flac2mp3_output" | log
  mkdir -p "$flac2mp3_output" >&2
  flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] mkdir returned an error. Unable to create output directory."
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    end_script 6
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
if [ $flac2mp3_keep -eq 1 ]; then
  flac2mp3_message+=", Keep source"
fi
flac2mp3_message+=", Matching regex: '${flac2mp3_regex:=[.]flac$}'"
flac2mp3_message+=", Track(s): ${flac2mp3_tracks}"
echo "${flac2mp3_message}" | log

# Set ffmpeg parameters
case "$flac2mp3_debug" in
  0) flac2mp3_ffmpeg_log="error" ;;
  1) flac2mp3_ffmpeg_log="warning" ;;
  2) flac2mp3_ffmpeg_log="info" ;;
  *) flac2mp3_ffmpeg_log="debug" ;;
esac
if [ -n "$flac2mp3_bitrate" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using constant bitrate of $flac2mp3_bitrate" | log
  flac2mp3_ffmpeg_brCommand="-b:a $flac2mp3_bitrate "
elif [ -n "$flac2mp3_vbrquality" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using variable quality of $flac2mp3_vbrquality" | log
  flac2mp3_ffmpeg_brCommand="-q:a $flac2mp3_vbrquality "
elif [ -n "$flac2mp3_ffmpegadv" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using advanced ffmpeg options \"$flac2mp3_ffmpegadv\"" | log
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Exporting with file extension \"$flac2mp3_extension\"" | log
  flac2mp3_ffmpeg_opts="$flac2mp3_ffmpegadv"
fi

# Set default ffmpeg options
[ -z "$flac2mp3_ffmpeg_opts" ] && flac2mp3_ffmpeg_opts="-c:v copy -map 0 -y -acodec libmp3lame ${flac2mp3_ffmpeg_brCommand}-write_id3v1 1 -id3v2_version 3"

# Process tracks
#  Changing the input field separator to split track string
declare -x flac2mp3_import_list=""
IFS=\|
for flac2mp3_track in $flac2mp3_tracks; do
  # Guard clause: regex not match
  if [[ ! $flac2mp3_track =~ $flac2mp3_regex ]]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Skipping track that did not match regex: $flac2mp3_track" | log
    continue
  fi

  # Check that track exists
  if [ ! -f  "$flac2mp3_track" ]; then
    flac2mp3_message="Error|Track file does not exist: \"$flac2mp3_track\" to \"$flac2mp3_newTrack\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    continue
  fi

  # Create a new track name with the given extension
  flac2mp3_newTrack="${flac2mp3_track%.*}${flac2mp3_extension}"
  # Redirect output if asked
  [ -n "$flac2mp3_output" ] && flac2mp3_newTrack="${flac2mp3_output}${flac2mp3_newTrack##*/}"
  # Check for same track name
  if [ "$flac2mp3_newTrack" == "$flac2mp3_track" ]; then
    echo "Error|The original track name and new name are the same! Skipping track: $flac2mp3_track" | log
    flac2mp3_exitstatus=11
    continue
  fi
  
  # Set metadata options to fix tags if asked
  if [ -n "$flac2mp3_tags" ]; then
    flac2mp3_ffmpeg_metadata=""
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detecting and fixing common problems with the following metadata tags: $flac2mp3_tags" | log

    # Get track metadata
    if ffprobe "$flac2mp3_track"; then
      for flac2mp3_tag in $(echo $flac2mp3_tags | tr ',' '|'); do
        case "$flac2mp3_tag" in
          title )  # Fix for parenthesis in titles for live and mix names
            flac2mp3_tag_title=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("title"; "i")).value')
            [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: title=$flac2mp3_tag_title" | log
            flac2mp3_pattern='\([^)]+\)$'      # Rough way to limit editing metadata for every track
            if [[ "$flac2mp3_tag_title" =~ $flac2mp3_pattern ]]; then
              flac2mp3_ffmpeg_metadata+="-metadata title=\"$(echo "$flac2mp3_tag_title" | sed -r 's/\((live|acoustic|demo|[^)]*((re)?mix(es)?|dub|version))\)$/[\1]/i')\" "
            fi
          ;;
          disc )   # Fix one disc by itself
            flac2mp3_tag_disc=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("disc"; "i")).value')
            [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: disc=$flac2mp3_tag_disc" | log
            if [ "$flac2mp3_tag_disc" == "1" ]; then
              flac2mp3_ffmpeg_metadata+='-metadata disc="1/1" '
            fi
          ;;
          genre )   # Fix multiple genres
            flac2mp3_tag_genre=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("genre"; "i")).value')
            [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: genre=$flac2mp3_tag_genre" | log
            # Only trigger on multiple genres
            if [[ $flac2mp3_tag_genre =~ \; ]]; then
              case "$flac2mp3_tag_genre" in
                *Synth-Pop*) flac2mp3_ffmpeg_metadata+='-metadata genre="Electronica & Dance" ' ;;
                *Pop*) flac2mp3_ffmpeg_metadata+='-metadata genre="Pop" ' ;;
                *Indie*) flac2mp3_ffmpeg_metadata+='-metadata genre="Alternative & Indie" ' ;;
                *Industrial*) flac2mp3_ffmpeg_metadata+='-metadata genre="Industrial Rock" ' ;;
                *Electronic*) flac2mp3_ffmpeg_metadata+='-metadata genre="Electronica & Dance" ' ;;
                *Punk*|*Alternative*) flac2mp3_ffmpeg_metadata+='-metadata genre="Alternative & Punk" ' ;;
                *Rock*) flac2mp3_ffmpeg_metadata+='-metadata genre="Rock" ' ;;
              esac
            fi
          ;;
        esac
      done
    else
      echo "Warn|ffprobe did not return any data when querying track: \"$flac2mp3_track\"" | log
      flac2mp3_exitstatus=12
    fi
  fi
  
  # Convert the track
  echo "Info|Writing: $flac2mp3_newTrack" | log
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Executing: nice /usr/bin/ffmpeg -loglevel $flac2mp3_ffmpeg_log -nostdin -i \"$flac2mp3_track\" $flac2mp3_ffmpeg_opts $flac2mp3_ffmpeg_metadata\"$flac2mp3_newTrack\"" | log
  eval nice /usr/bin/ffmpeg -loglevel $flac2mp3_ffmpeg_log -nostdin -i \"$flac2mp3_track\" $flac2mp3_ffmpeg_opts $flac2mp3_ffmpeg_metadata\"$flac2mp3_newTrack\" 2>&1 | log
  flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] ffmpeg error when converting track: \"$flac2mp3_track\" to \"$flac2mp3_newTrack\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    flac2mp3_exitstatus=13
    continue
  }

  # Check for non-zero size file
  if [ ! -s "$flac2mp3_newTrack" ]; then
    flac2mp3_message="Error|The new track does not exist or is zero bytes: \"$flac2mp3_newTrack\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    flac2mp3_exitstatus=14
    continue
  fi

  # Set owner and permissions
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Changing ownership and permissions of \"$flac2mp3_newTrack\"" | log
  chown --reference="$flac2mp3_track" "$flac2mp3_newTrack" >&2
  chmod --reference="$flac2mp3_track" "$flac2mp3_newTrack" >&2
  flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] Error when changing ownership or permissions of track: \"$flac2mp3_newTrack\""
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    flac2mp3_exitstatus=15
  }

  # Do not delete the source file if asked. Skip import.
  if [ $flac2mp3_keep -eq 1 ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Keeping original: \"$flac2mp3_track\"" | log
    continue
  fi

  # Skip the rest of the loop if in batch mode, just delete the track
  if [ "$flac2mp3_type" = "batch" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Deleting: \"$flac2mp3_track\"" | log
    rm "$flac2mp3_track" >&2
    flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
      flac2mp3_message="Error|[$flac2mp3_return] Error when deleting track: \"$flac2mp3_track\""
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
      flac2mp3_exitstatus=16
    }
    continue
  fi

  # Call Lidarr to delete the original file, or recycle if configured.
  flac2mp3_track_id=$(echo $flac2mp3_trackfiles | jq -crM ".[] | select(.path == \"$flac2mp3_track\") | .id")
  delete_track $flac2mp3_track_id
  flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
    flac2mp3_message="Error|[$flac2mp3_return] Lidarr error when deleting the original track: \"$flac2mp3_track\". Not importing new track into Lidarr."
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    flac2mp3_exitstatus=17
    continue
  }

  # Add new track to list of tracks to import
  flac2mp3_import_list+="${flac2mp3_newTrack}|"
done
IFS=$' \t\n'
#### END MAIN

#### Call Lidarr API to update database
# Check for URL
if [ "$flac2mp3_type" = "batch" ]; then
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Cannot use API in batch mode." | log
elif [ $flac2mp3_keep -eq 1 ]; then
  echo "Info|Original audio file(s) kept, no database update performed." | log
elif [ -n "$flac2mp3_api_url" ]; then
  # Check for artist ID
  if [ -n "$lidarr_artist_id" ]; then
    # Remove trailing pipe
    flac2mp3_import_list="${flac2mp3_import_list%|}"
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Track import list: \"$flac2mp3_import_list\"" | log
    # Scan for files to import into Lidarr
    export flac2mp3_import_count=$(echo $flac2mp3_import_list |  awk -F\| '{print NF}')
    if [ $flac2mp3_import_count -ne 0 ]; then
      echo "Info|Preparing to import $flac2mp3_import_count new files. This make take a long time for large libraries." | log
      if get_import_info; then
        # Build JSON data for all tracks
        # NOTE: Tracks with empty track IDs will not appear in the resulting JSON and will therefore not be imported into Lidarr
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|Building JSON data to import" | log
        export flac2mp3_json=$(echo $flac2mp3_result | jq -jcrM "
          map(
            select(.path | inside(\"$flac2mp3_import_list\")) |
            {path, \"artistId\":$lidarr_artist_id, \"albumId\":$lidarr_album_id, albumReleaseId,\"trackIds\":[.tracks[].id], quality, \"disableReleaseSwitching\":false}
          )
        ")

        # Import new files into Lidarr
        import_tracks
        flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
          flac2mp3_message="Error|[$flac2mp3_return] Lidarr error when importing the new tracks!"
          echo "$flac2mp3_message" | log
          echo "$flac2mp3_message" >&2
          flac2mp3_exitstatus=17
        }
        flac2mp3_jobid="$(echo $flac2mp3_result | jq -crM .id)"

        # Check status of job
        check_job
        flac2mp3_return=$?; [ $flac2mp3_return -ne 0 ] && {
          case $flac2mp3_return in
            1) flac2mp3_message="Info|Lidarr job ID $flac2mp3_jobid is queued. Trusting this will complete and exiting."
               flac2mp3_exitstatus=0
            ;;
            2) flac2mp3_message="Warn|Lidarr job ID $flac2mp3_jobid failed."
               flac2mp3_exitstatus=17
            ;;
            3) flac2mp3_message="Warn|Script timed out waiting on Lidarr job ID $flac2mp3_jobid. Last status was: $(echo $flac2mp3_result | jq -crM .status)"
               flac2mp3_exitstatus=18
            ;;
           10) flac2mp3_message="Error|Lidarr job ID $flac2mp3_jobid returned a curl error."
               flac2mp3_exitstatus=17
           ;;
          esac
          echo "$flac2mp3_message" | log
          echo "$flac2mp3_message" >&2
        }
      else
        flac2mp3_message="Error|Lidarr error getting import file list in \"$lidarr_artist_path\" for artist ID $lidarr_artist_id"
        echo "$flac2mp3_message" | log
        echo "$flac2mp3_message" >&2
        flac2mp3_exitstatus=17
      fi
    else
      flac2mp3_message="Warn|Didn't find any tracks to import."
      echo "$flac2mp3_message" | log
      echo "$flac2mp3_message" >&2
    fi
  else
    # No Artist ID means we can't call the API
    flac2mp3_message="Warn|Missing environment variable lidarr_artist_id"
    echo "$flac2mp3_message" | log
    echo "$flac2mp3_message" >&2
    flac2mp3_exitstatus=20
  fi
else
  # No URL means we can't call the API
  flac2mp3_message="Warn|Unable to determine Lidarr API URL."
  echo "$flac2mp3_message" | log
  echo "$flac2mp3_message" >&2
  flac2mp3_exitstatus=20
fi

end_script
