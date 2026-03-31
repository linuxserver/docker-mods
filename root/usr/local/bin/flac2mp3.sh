#!/bin/bash

# Script to convert FLAC files to MP3 using FFmpeg
#  Dev/test: https://github.com/TheCaptain989/lidarr-flac2mp3
#  Prod: https://github.com/linuxserver/docker-mods/tree/lidarr-flac2mp3
#
# Resultant MP3s are fully tagged and retain same permissions as original file
#
# Legacy one-liner script for posterity
#  find "$lidarr_artist_path" -name "*.flac" -exec bash -c 'ffmpeg -loglevel warning -i "{}" -y -acodec libmp3lame -b:a 320k "${0/.flac}.mp3" && rm "{}"' {} \;

# NOTE: ShellCheck linter directives appear as comments

# Dependencies:
#  From ffmpeg package:
#   ffmpeg
#   ffprobe
#  From jq package:
#   jq
#  Generally always available:
#   awk
#   curl
#   stat
#   nice
#   basename
#   dirname
#   printenv
#   chmod
#   tr
#   sed
#   mktemp

# Exit codes:
#  0 - success; or test
#  1 - no audio tracks detected
#  2 - ffmpeg, ffprobe, or jq not found
#  3 - invalid command line arguments
#  4 - log file is not writable
#  5 - specified audio file not found
#  6 - error when creating output directory
#  7 - unknown eventtype environment variable
#  8 - Unable to rename temp file to new track, or to move track to destination in Import mode
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

### MAIN
function main {
  # Main script execution

  initialize_variables
  # Setup ANSI color support (only when running in a terminal)
  setup_ansi_colors
  process_command_line "$@"
  initialize_mode_variables
  check_log
  check_required_binaries
  log_first_debug_messages
  check_wsl
  check_eventtype
  log_script_start
  check_config_file
  check_arr_config
  check_tracks
  set_ffmpeg_parameters
  process_tracks
  update_database
}

### Functions
function usage {
  # Short usage

  usage="Try '$flac2mp3_script --help' for more information."
  echo "$usage" >&2
}
function long_usage {
  # Full usage
  
  usage="$flac2mp3_script   Version: $flac2mp3_ver
Audio conversion script designed for use with Lidarr

Source: https://github.com/TheCaptain989/lidarr-flac2mp3

Usage:
  $flac2mp3_script [{-b|--bitrate} <bitrate> | {-v|--quality} <quality> | {-a|--advanced} \"<options>\" {-e|--extension} <extension>]
      [{-f|--file} <audio_file>]
      [{-k|--keep-file}]
      [{-o|--output} <directory>]
      [{-r|--regex} '<regex>']
      [{-t|--tags} <taglist>]
      [{-l|--log} <log_file>]
      [{-c|--config} <config_file>]
      [{-d|--debug} [<level>]]

  Options can also be set via the FLAC2MP3_ARGS environment variable.
  Command-line arguments override the environment variable.

Options and Arguments:
  -b, --bitrate <bitrate>
                  Set output quality in constant bits per second
                  Ex: 160k, 240k, 300000
                  [default: 320k]

  -v, --quality <quality>
                  Set output variable bit rate; quality between 0-9
                  0 is highest quality, 9 is lowest
                  For more details, see: https://trac.ffmpeg.org/wiki/Encode/MP3

  -a, --advanced \"<options>\"
                  Advanced ffmpeg options enclosed in quotes
                  Specified options replace all script defaults and are sent directly to ffmpeg.
                  For more details on valid options, see: https://ffmpeg.org/ffmpeg.html#Options
                  WARNING: You must specify an audio codec!
                  WARNING: Invalid options could result in script failure!
                  Note: Requires -e option to also be specified 
                  For more details, see: https://github.com/TheCaptain989/lidarr-flac2mp3#technical-notes-on-advanced-options

  -e, --extension <extension>
                  File extension for output file, with or without dot
                  Note: Requires -a option to also be specified

  -f, --file <audio_file>
                  If included, the script enters Batch mode and converts the specified audio file
                  WARNING: Do not use this argument when called from Lidarr!

  -o, --output <directory>
                  Specify a destination directory for the converted audio file(s)
                  It will be created if it does not exist.

  -k, --keep-file
                  Do not delete the source file or move it to the Lidarr Recycle bin
                  This also disables importing the new files into Lidarr after conversion.

  -r, --regex '<regex>'
                  Regular expression used to select input files
                  [default: \\.flac$]

  -t, --tags <taglist>
                  Comma separated list of metadata tags to apply automated corrections to.
                  Supports: title, disc, genre

  -l, --log <log_file>
                  Log filename
                  [default: /config/log/flac2mp3.txt]

  -c, --config <config_file>
                  Lidarr XML configuration file
                  [default: ./config/config.xml]

  -d, --debug [<level>]
                  Enable debug logging
                  Level is optional:
                    1 (low)
                    2 includes JSON output
                    3 contains even more JSON output
                  [default: 1]

      --no-ansi
                  Force disable ANSI color codes in terminal output

      --help
                  Display this help and exit

      --version
                  Display script version and exit

Batch Mode:
  Batch mode allows the script to be executed independently of Lidarr.  It processes the
  file specified on the command line and ignores any environment variables that are normally
  expected.

Import Using Script:
  The script can also be used to import the audio files directly from the download client by
  selecting the Settings > Media Management > Importing > Import Using Script setting in Lidarr.
  Doing so will process the audio files before they are added to the library.

Examples:
  $flac2mp3_script -b 320k
                  # Output 320 kbit/s MP3 (non-VBR; same as default behavior)

  $flac2mp3_script -v 0
                  # Output variable bitrate MP3, VBR 220-260 kbit/s

  $flac2mp3_script -d -b 160k
                  # Enable debugging level 1 and output a 160 kbit/s MP3

  $flac2mp3_script -r '\\\\.[^.]*\$'
                  # Convert any file to MP3 (not just FLAC)

  $flac2mp3_script -a \"-c:v libtheora -map 0 -q:v 10 -c:a libopus -b:a 192k\" -e .opus
                  # Convert to Opus format, 192 kbit/s, cover art

  $flac2mp3_script -a \"-vn -c:a libopus -b:a 192K\" -e .opus -r '\.mp3\$'
                  # Convert .mp3 files to Opus format, 192 kbit/s, no cover art

  $flac2mp3_script -a \"-y -map 0 -c:a aac -b:a 240K -c:v copy\" -e m4a
                  # Convert to M4A format, using AAC 240 kbit/s audio, cover art, overwrite file

  $flac2mp3_script-a \"-c:a flac -sample_fmt s16 -ar 44100\" -e flac
                  # Resample to 16-bit FLAC

  $flac2mp3_script -f \"/path/to/audio/a-ha/Hunting High and Low/01 Take on Me.flac\"
                  # Batch Mode
                  # Output 320 kbit/s MP3
  
  $flac2mp3_script -o \"/path/to/audio\" -k
                  # Place the converted file(s) in specified directory and do not delete the
                  # original audio file(s)
"
  echo "$usage"
}
function initialize_variables {
  # Initialize global variables

  export flac2mp3_script=$(basename "$0")
  export flac2mp3_ver="{{VERSION}}"
  export flac2mp3_pid=$$
  export flac2mp3_arr_config=/config/config.xml
  export flac2mp3_log=/config/logs/flac2mp3.txt
  export flac2mp3_maxlogsize=1024000
  export flac2mp3_maxlog=4
  export flac2mp3_debug=0
  # Default to Custom Script mode. Possible modes: "Batch", "Import", "Custom Script"
  export flac2mp3_mode="Custom Script"
  export flac2mp3_keep=0
  export flac2mp3_type=$(printenv | sed -n 's/_eventtype *=.*$//p')
}
function process_command_line {
  # Process arguments, either from the command line or from the environment variable

  # Log command-line arguments
  if [ $# -ne 0 ]; then
    export flac2mp3_prelogmessagedebug="Debug|Command line arguments are '$*'"
  fi

  # Check for environment variable arguments
  if [ -n "$FLAC2MP3_ARGS" ]; then
    if [ $# -ne 0 ]; then
      export flac2mp3_prelogmessage="Warning|FLAC2MP3_ARGS environment variable set but will be ignored because command line arguments were also specified."
    else
      # Move the environment variable arguments to the command line for processing
      export flac2mp3_prelogmessage="Info|Using settings from environment variable."
      eval set -- "$FLAC2MP3_ARGS"
    fi
  fi

  # Process arguments
  while (( "$#" )); do
    case "$1" in
      -d|--debug )
        # Enable debugging, with optional level
        if [ -n "$2" ] && [ ${2:0:1} != "-" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
          export flac2mp3_debug=$2
          shift 2
        else
          export flac2mp3_debug=1
          shift
        fi
      ;;
      --help )
        # Display usage
        long_usage
        exit 0
      ;;
      --version )
        # Display version
        echo_ansi "${flac2mp3_script} ${flac2mp3_ver/{{VERSION\}\}/unknown}"
        exit 0
      ;;
      --no-ansi )
        # Disable all ANSI colors in output
        export flac2mp3_noansi="true"
        shift
      ;;
      -l|--log )
        # Log file
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        export flac2mp3_log="$2"
        shift 2
      ;;
      -f|--file )
        # Batch Mode
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        export flac2mp3_mode="Batch"
        export flac2mp3_tracks="$2"
        shift 2
      ;;
      -b|--bitrate )
        # Set constant bit rate
        if [ -n "$flac2mp3_vbrquality" ]; then
          echo_ansi "Error|Both -b and -v options cannot be set at the same time." >&2
          usage
          exit 3
        elif [ -n "$flac2mp3_ffmpegadv" -o -n "$flac2mp3_extension" ]; then
          echo_ansi "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
          usage
          exit 3
        elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          export flac2mp3_bitrate="$2"
          shift 2
        else
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
      ;;
      -v|--quality )
        # Set variable quality
        if [ -n "$flac2mp3_bitrate" ]; then
          echo_ansi "Error|Both -v and -b options cannot be set at the same time." >&2
          usage
          exit 3
        elif [ -n "$flac2mp3_ffmpegadv" -o -n "$flac2mp3_extension" ]; then
          echo_ansi "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
          usage
          exit 3
        elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          export flac2mp3_vbrquality="$2"
          shift 2
        else
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
      ;;
      -a|--advanced )
        # Set advanced options
        if [ -n "$flac2mp3_vbrquality" -o -n "$flac2mp3_bitrate" ]; then
          echo_ansi "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
          usage
          exit 3
        elif [ -n "$2" ]; then
          export flac2mp3_ffmpegadv="$2"
          shift 2
        else
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
      ;;
      -e|--extension )
        # Set file extension
        if [ -n "$flac2mp3_vbrquality" -o -n "$flac2mp3_bitrate" ]; then
          echo_ansi "Error|The -a and -e options cannot be set at the same time as either -v or -b options." >&2
          usage
          exit 3
        elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          export flac2mp3_extension="$2"
          shift 2
        else
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        # Test for dot prefix
        [ "${flac2mp3_extension:0:1}" != "." ] && export flac2mp3_extension=".${flac2mp3_extension}"
      ;;
      -o|--output )
        # Set output directory
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        export flac2mp3_output="$2"
        shift 2
        # Test for trailing slash
        [ "${flac2mp3_output: -1:1}" != "/" ] && export flac2mp3_output="${flac2mp3_output}/"
      ;;
      -k|--keep-file )
        # Do not delete source file(s)
        export flac2mp3_keep=1
        shift
      ;;
      -r|--regex )
        # Sets the regex used to match input files
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        export flac2mp3_regex="$2"
        shift 2
      ;;
      -t|--tags )
        # Metadata tags to correct
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        export flac2mp3_tags="$2"
        shift 2
      ;;
      -c|--config )
        # Lidarr XML configuration file
        if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
          echo_ansi "Error|Invalid option: $1 requires an argument." >&2
          usage
          exit 3
        fi
        # Overrides default /config/config.xml
        export flac2mp3_arr_config="$2"
        shift 2
      ;;
      -*)
        # Unknown option
        echo_ansi "Error|Unknown option: $1" >&2
        usage
        exit 20
      ;;
      *)
        # Remove unknown positional parameters
        shift
      ;;
    esac
  done

  # Test for either -a and -e, but not both: logical XOR = non-equality
  if [ "${flac2mp3_ffmpegadv:+data}" != "${flac2mp3_extension:+data}" ]; then
    echo_ansi "Error|The -a and -e options must be specified together." >&2
    usage
    exit 3
  fi

  # Set default bit rate
  [ -z "$flac2mp3_vbrquality" -a -z "$flac2mp3_bitrate" -a -z "$flac2mp3_ffmpegadv" -a -z "$flac2mp3_extension" ] && export flac2mp3_bitrate="320k"

  # Set default new track extension
  export flac2mp3_extension="${flac2mp3_extension:-.mp3}"
}
function setup_ansi_colors {
  # Setup ANSI color codes and determine when to use them.
  # Colors should only be used when the script is writing to an interactive terminal.

  export ansi_red='\033[0;31m'
  export ansi_green='\033[0;32m'
  export ansi_yellow='\033[0;33m'
  export ansi_cyan='\033[0;36m'
  export ansi_nc='\033[0m' # No Color
}
function strip_ansi_codes {
  # Remove ANSI escape sequences from stdin (e.g., before writing to log files)
  sed -E 's/\x1B\[[0-9;]*[mK]//g'
}
function echo_ansi {
  # Apply ANSI colors for terminal output only.
  # Colors are based on the message prefix (Error|, Warn|, Debug|).
  
  local msg="$*"
  local prefix="${msg%%|*}"
  local color=""
  case "$prefix" in
    Error) color="$ansi_red" ;;
    Warn)  color="$ansi_yellow" ;;
    Debug) color="$ansi_cyan" ;;
  esac
  
  local use_color=false
  if [ -t 1 -a -t 2 ] && [ -z "$flac2mp3_noansi" ]; then
    use_color=true
  fi
  
  if $use_color && [ -n "$color" ]; then
    builtin echo -e "${color}${msg}${ansi_nc}"
  else
    builtin echo "$msg"
  fi
}
function initialize_mode_variables {
  # Determines script mode and sets mode specific variables

  # Switch to Import mode if *_transfermode variable is found
  local transfermode=$(printenv | sed -n 's/_transfermode *=.*$//p')
  if [ -n "$transfermode" ]; then
    export flac2mp3_mode="Import"
    export flac2mp3_type="$transfermode"    # "lidarr"
  fi

  # Mode specific variable assignment
  if [ "${flac2mp3_mode,,}" == "batch" ]; then
    # Batch mode
    export flac2mp3_type="batch"
    export batch_eventtype="Convert"
    local event_var="${flac2mp3_type,,}_eventtype"
  else
    # Custom Script or Import mode
    if [ "${flac2mp3_type,,}" == "lidarr" ]; then
      # Lidarr
      # shellcheck disable=SC2154
      export flac2mp3_tracks="$lidarr_addedtrackpaths"
      # Catch for other environment variable
      # shellcheck disable=SC2154
      [ -z "$flac2mp3_tracks" ] && export flac2mp3_tracks="$lidarr_trackfile_path"
      # shellcheck disable=SC2154
      export flac2mp3_download_client="$lidarr_download_client"
      # shellcheck disable=SC2154
      export flac2mp3_download_client_type="$lidarr_download_client_type"
    else
      # Called in an unexpected way
      echo_ansi "Error|Unknown or missing *_eventtype or *_transfermode environment variables.\nNot calling from Lidarr? Try using Batch Mode option: -f <file>" >&2
      usage
      exit 7
    fi
    local event_var="${flac2mp3_type,,}_eventtype"
    
    # Import mode overrides
    if [ "${flac2mp3_mode,,}" == "import" ]; then
      local sourcepath_var="${flac2mp3_type,,}_sourcepath"
      local destinationpath_var="${flac2mp3_type,,}_destinationpath"
      local sourcepath="${!sourcepath_var}"
      local destinationpath="${!destinationpath_var}"
      local event_var="${flac2mp3_type,,}_transfermode"
      export flac2mp3_tracks="$sourcepath"
      export flac2mp3_newtracks="$destinationpath"
    fi
  fi

  export flac2mp3_event="${!event_var}"
}
function log {(
  # Write piped message to log file
  # Can still go over flac2mp3_maxlog if read line is too long
  # Must include whole function in subshell for read to work!

  while read -r; do
    # Ensure ANSI escape sequences are stripped from log output
    local line="$REPLY"
    line="$(printf '%s' "$line" | strip_ansi_codes)"

    # shellcheck disable=2046
    echo $(date +"%Y-%m-%d %H:%M:%S.%1N")\|"[$flac2mp3_pid]$line" >>"$flac2mp3_log"
    local filesize=$(stat -c %s "$flac2mp3_log")
    if [ $filesize -gt $flac2mp3_maxlogsize ]; then
      for i in $(seq $((flac2mp3_maxlog-1)) -1 0); do
        [ -f "${flac2mp3_log::-4}.$i.txt" ] && mv "${flac2mp3_log::-4}."{$i,$((i+1))}".txt"
      done
      [ -f "${flac2mp3_log::-4}.txt" ] && mv "${flac2mp3_log::-4}.txt" "${flac2mp3_log::-4}.0.txt"
      touch "$flac2mp3_log"
    fi
  done
)}
function read_xml {
  # Read XML file and parse it
  # Inspired by https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash

  local IFS=\>
  read -r -d \< flac2mp3_xml_entity flac2mp3_xml_content
}
function get_version {
  # Get Lidarr version

  call_api 0 "Getting ${flac2mp3_type^} version." "GET" "system/status"
  local json_test="$(echo $flac2mp3_result | jq -crM '.version?')"
  [ "$json_test" != "null" ] && [ "$json_test" != "" ]
  return
}
function get_trackfile_info {
  # Get all track files from album

  # shellcheck disable=SC2154
  call_api 0 "Getting track file info for album id $lidarr_album_id." "GET" "trackFile" "albumId=$lidarr_album_id"
  local json_test="$(echo $flac2mp3_result | jq -crM '.[].id?')"
  [ "$json_test" != "null" ] && [ "$json_test" != "" ]
  return
}
function check_job {
  # Check result of command job

  # Exit codes:
  #  0 - success
  #  1 - queued
  #  2 - failed
  #  3 - loop timed out
  # 10 - curl error
  
  local jobid="$1" # Job ID to check

  local i
  for ((i=1; i <= 15; i++)); do
    call_api 0 "Checking job $jobid completion." "GET" "command/$jobid"
    local api_return=$?; [ $api_return -ne 0 ] && {
      local return=10
      break
    }

    # Job status checks
    local json_test="$(echo $flac2mp3_result | jq -crM '.status?')"
    case "$json_test" in
      completed) local return=0; break ;;
      failed) local return=2; break ;;
      queued) local return=1; break ;;
      *)
        # It may have timed out, so let's wait a second
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|Job not done. Waiting 1 second." | log
        local return=1
        sleep 1
      ;;
    esac
  done
  return $return
}
function delete_track {
  # Delete track

  local track_id="$1"  # ID of track to delete

  call_api 0 "Deleting or recycling '$track'." "DELETE" "trackFile/$track_id"
  return
}
function move_track {
  # Move audio file to new location

  local source="$1" # Source audio file
  local dest="$2"   # Destination audio file

  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Moving/renaming track '$source' to '$dest'" | log
  local result
  result=$(mv -f "$source" "$dest")
  local return=$?; [ $return -ne 0 ] && {
    local message=$(echo -e "[$return] Unable to move/rename track: \"$source\" to: \"$dest\".\nmv returned: $result" | awk '{print "Error|"$0}')
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 8
  }
  return $return
}
function get_import_info {
  # Get file details on possible files to import into Lidarr

  # shellcheck disable=SC2154
  call_api 1 "Getting list of files that can be imported." "GET" "manualimport" "artistId=$lidarr_artist_id" "folder=$lidarr_artist_path" "filterExistingFiles=true" "replaceExistingFiles=false"
  local json_test="$(echo $flac2mp3_result | jq -crM '.[]? | .tracks?')"
  [ "$json_test" != "null" ] && [ "$json_test" != "" ] && [ "$json_test" != "[]" ]
  return
}
function import_tracks {
  # Import new track into Lidarr

  call_api 0 "Importing $flac2mp3_import_count new files into ${flac2mp3_type^}." "POST" "command" "{\"name\":\"ManualImport\",\"files\":$flac2mp3_json,\"importMode\":\"auto\",\"replaceExistingFiles\":false}"
  local json_test="$(echo $flac2mp3_result | jq -crM '.id?')"
  [ "$json_test" != "null" ] && [ "$json_test" != "" ]
  return
}
function ffprobe {
  # Get track media info from ffprobe

  local trackfile="$1" # Track file to inspect
  
  local ffcommand="/usr/bin/ffprobe"
  execute_ff_command "inspecting file: '$trackfile'" "$ffcommand" -hide_banner -loglevel $flac2mp3_ffmpeg_log -print_format json=compact=1 -show_format -show_entries "format=tags : format_tags=title,disc,genre" -i "$trackfile"

  unset flac2mp3_ffprobe_json
  declare -g flac2mp3_ffprobe_json
  flac2mp3_ffprobe_json="$flac2mp3_ffresult"

  [ "$flac2mp3_ffprobe_json" != "" ]
  return
}
function end_script {
  # Exit program

  # Cool bash feature
  local message="Info|Completed in $((SECONDS/60))m $((SECONDS%60))s"
  echo "$message" | log
  [ "$1" != "" ] && export flac2mp3_exitstatus=$1
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Exit code ${flac2mp3_exitstatus:-0}" | log
  exit ${flac2mp3_exitstatus:-0}
}
function change_exit_status {
  # Set exit status code, but only if it is not already set

  local exit_status="$1" # Exit status code to set
  if [ -z "$flac2mp3_exitstatus" ]; then
    export flac2mp3_exitstatus="$exit_status"
  fi
}
function check_log {
  # Log file checks

  # Check that log path exists
  if [ ! -d "$(dirname $flac2mp3_log)" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo_ansi "Debug|Log file path does not exist: '$(dirname $flac2mp3_log)'. Using log file in current directory."
    export flac2mp3_log=./flac2mp3.txt
  fi

  # Check that the log file exists
  if [ ! -f "$flac2mp3_log" ]; then
    echo_ansi "Info|Creating a new log file: $flac2mp3_log"
    touch "$flac2mp3_log"
  fi

  # Check that the log file is writable
  if [ ! -w "$flac2mp3_log" ]; then
    echo_ansi "Error|Log file '$flac2mp3_log' is not writable or does not exist." >&2
    export flac2mp3_log=/dev/null
    change_exit_status 4
  fi
}
function check_required_binaries {
  # Check for required binaries

  for flac2mp3_file in "/usr/bin/ffmpeg" "/usr/bin/ffprobe" "/usr/bin/jq"; do
    if [ ! -f "$flac2mp3_file" ]; then
      local message="Error|$flac2mp3_file is required by this script"
      echo "$message" | log
      echo_ansi "$message" >&2
      end_script 2
    fi
  done
}
function log_first_debug_messages {
  # First log messages

  # Log Debug state
  if [ $flac2mp3_debug -ge 1 ]; then
    local message="Debug|Running ${flac2mp3_script} version ${flac2mp3_ver/{{VERSION\}\}/unknown} in ${flac2mp3_mode} with debug logging level ${flac2mp3_debug}."
    echo "$message" | log
    echo_ansi "$message" >&2
  fi

  # Log command line parameters
  if [ -n "$flac2mp3_prelogmessagedebug" ]; then
    # flac2mp3_prelogmessagedebug is set in process_command_line
    [ $flac2mp3_debug -ge 1 ] && echo "$flac2mp3_prelogmessagedebug" | log
  fi

  # Log FLAC2MP3_ARGS usage
  if [ -n "$flac2mp3_prelogmessage" ]; then
    # flac2mp3_prelogmessage is set in process_command_line
    echo "$flac2mp3_prelogmessage" | log
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|FLAC2MP3_ARGS: ${FLAC2MP3_ARGS}" | log
  fi

  # Log environment and user
  [ $flac2mp3_debug -ge 2 ] && id | sed 's/^/Debug|Running as: /' | log
  [ $flac2mp3_debug -ge 2 ] && printenv | sort | sed 's/^/Debug|/' | log
}
function check_eventtype {
  # Check for invalid _eventtype and handle test event

  if [[ "$flac2mp3_event" =~ Grab|Rename|TrackRetag|ArtistAdd|ArtistDeleted|AlbumDeleted|ApplicationUpdate|HealthIssue ]]; then
    local message="Error|${flac2mp3_type^} event ${flac2mp3_event} is not supported. Exiting."
    echo "$message" | log
    echo_ansi "$message" >&2
    end_script 20
  fi

  # Handle Test event
  if [[ "${flac2mp3_event}" = "Test" ]]; then
    echo "Info|${flac2mp3_type^} event: ${flac2mp3_event}" | log
    local message="Info|Script was test executed successfully."
    echo "$message" | log
    echo "$message"
    end_script 0
  fi
}
function check_wsl {
  # Check for WSL environment

  if [ -n "$WSL_DISTRO_NAME" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Running in virtual WSL $WSL_DISTRO_NAME distribution." | log
    # Adjust config file location to WSL default
    if [ ! -f "$flac2mp3_arr_config" ]; then
      export flac2mp3_arr_config="/mnt/c/ProgramData/${flac2mp3_type^}/config.xml"
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Will try to use the default WSL configuration file '$flac2mp3_arr_config'" | log
    fi
  fi
}
function log_script_start {
  # First normal log entry (when there are no errors)

  # Build dynamic log message
  local message="Info|${flac2mp3_type^} event: ${flac2mp3_event}"
  if [ "${flac2mp3_mode,,}" != "batch" ]; then
    # shellcheck disable=SC2154
    message+=", Artist: ${lidarr_artist_name} (${lidarr_artist_id}), Album: ${lidarr_album_title} (${lidarr_album_id})"
  fi
  if [ -z "$flac2mp3_ffmpegadv" ]; then
    message+=", Export bitrate: ${flac2mp3_bitrate:-$flac2mp3_vbrquality}"
  else
    message+=", Advanced options: '${flac2mp3_ffmpegadv}', File extension: ${flac2mp3_extension}"
  fi
  if [ -n "$flac2mp3_output" ]; then
    message+=", Output: ${flac2mp3_output}"
  fi
  if [ $flac2mp3_keep -eq 1 ]; then
    message+=", Keep source"
  fi
  message+=", Matching regex: '${flac2mp3_regex:=[.]flac$}'"
  message+=", Track(s): ${flac2mp3_tracks}"
  echo "$message" | log

  if [ "${flac2mp3_mode,,}" = "import" -a -n "$flac2mp3_download_client" ]; then
    echo "Info|Importing tracks directly from ${flac2mp3_download_client} (${flac2mp3_download_client_type})" | log
  fi
}
function check_config_file {
  # Check for config file

  if [ "${flac2mp3_mode,,}" = "batch" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Not using config file in batch mode." | log
    return
  fi

  if ! [ -f "$flac2mp3_arr_config" ]; then
    # No config file means we can't call the API.  Best effort at this point.
    local message="Warn|Unable to locate ${flac2mp3_type^} config file: '$flac2mp3_arr_config'"
    echo "$message" | log
    echo_ansi "$message" >&2
    return
  fi

  # Read Lidarr config.xml
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Reading from ${flac2mp3_type^} config file '$flac2mp3_arr_config'" | log
  while read_xml; do
    [[ $flac2mp3_xml_entity = "Port" ]] && local port=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "UrlBase" ]] && local urlbase=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "BindAddress" ]] && local bindaddress=$flac2mp3_xml_content
    [[ $flac2mp3_xml_entity = "ApiKey" ]] && export flac2mp3_apikey=$flac2mp3_xml_content
  done < "$flac2mp3_arr_config"

  # Allow use of environment variables from https://github.com/Lidarr/Lidarr/pull/4812
  local port_var="${flac2mp3_type^^}__SERVER__PORT"
  [ -n "${!port_var}" ] && local port="${!port_var}"
  local urlbase_var="${flac2mp3_type^^}__SERVER__URLBASE"
  [ -n "${!urlbase_var}" ] && local urlbase="${!urlbase_var}"
  local bindaddress_var="${flac2mp3_type^^}__SERVER__BINDADDRESS"
  [ -n "${!bindaddress_var}" ] && local bindaddress="${!bindaddress_var}"
  local apikey_var="${flac2mp3_type^^}__AUTH__APIKEY"
  [ -n "${!apikey_var}" ] && export flac2mp3_apikey="${!apikey_var}"

  # Check for WSL environment and adjust bindaddress if not otherwise specified
  if [ -n "$WSL_DISTRO_NAME" -a "$bindaddress" = "*" ]; then
    local bindaddress=$(ip route show | grep -i default | awk '{ print $3}')
  fi

  # Check for localhost
  [[ $bindaddress = "*" ]] && local bindaddress=localhost

  # Strip leading and trailing forward slashes from URL base (see issue #44)
  local urlbase="$(echo "$urlbase" | sed -re 's/^\/+//; s/\/+$//')"
  
  # Build URL to Lidarr API
  export flac2mp3_api_url="http://$bindaddress:$port${urlbase:+/$urlbase}/api/v1"

  # Check Lidarr version
  get_version
  local return=$?; [ $return -ne 0 ] && {
    # curl errored out. API calls are really broken at this point.
    local message="Error|[$return] Unable to get ${flac2mp3_type^} version information. It is not safe to continue."
    echo "$message" | log
    echo_ansi "$message" >&2
    end_script 17
  }
  export flac2mp3_version="$(echo $flac2mp3_result | jq -crM .version)"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detected ${flac2mp3_type^} version $flac2mp3_version" | log

  # Import mode will not have any audio tracks until after import 
  if [ "${flac2mp3_mode,,}" == "import" ]; then
    return
  fi

  # Get album trackfile info. Need the IDs to delete the old tracks.
  if get_trackfile_info; then
    export flac2mp3_trackfiles="$flac2mp3_result"
  else
    local message="Warn|Unable to get trackfile info for album ID $lidarr_album_id"
    echo "$message" | log
    echo_ansi "$message" >&2
  fi
}
function check_arr_config {
  # Check Lidarr configuration...

  # Bypass if using Batch mode
  if [ "${flac2mp3_mode,,}" = "batch" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Cannot check ${flac2mp3_type^} config in Batch mode." | log
    return
  fi

  get_media_config
  local return=$?; [ $return -ne 0 ] && {
    # No '.id' in returned JSON
    local message="Warn|The Media Management Config API returned no id."
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 17
  }
  # ...to use an import script
  if [ "$(echo "$flac2mp3_result" | jq -crM ".useScriptImport")" = "true" ]; then
    export flac2mp3_importscript="$(echo "$flac2mp3_result" | jq -crM ".scriptImportPath")"
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|${flac2mp3_type^} is configured to use an external import script: $flac2mp3_importscript" | log

    # Catch double configuration of this script as both Import Script and Custom Script
    if [ "${flac2mp3_mode,,}" = "custom script" -a "$flac2mp3_importscript" = "$0" ]; then
      local message="Error|${flac2mp3_type^} is configured to use ${flac2mp3_script} as an Import script, but called it as a Custom Script, which would result in duplicate processing. Halting."
      echo "$message" | log
      echo_ansi "$message" >&2
      end_script 20
    fi
  fi
}
function call_api {
  # Call the Lidarr API

  local debug_add=$1 # Value added to debug level when evaluating for JSON debug output
  local message="$2" # Message to log
  local method="$3" # HTTP method to use (GET, POST, PUT, DELETE)
  local endpoint="$4" # API endpoint to call
  local -a curl_data_args=() # Use array instead of string for safer argument passing

  # Process remaining data values
  shift 4
  while (( "$#" )); do
    case "$1" in
      "{"*|"["*)
        curl_data_args+=(--json "$1")
      ;;
      *=*)
        curl_data_args+=(--data-urlencode "$1")
      ;;
      *)
        curl_data_args+=(--data-raw "$1")
      ;;
    esac
    shift
  done

  local -a curl_args=(
    -s
    --fail-with-body
    -H "X-Api-Key: $flac2mp3_apikey"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
  )

  local url="$flac2mp3_api_url/$endpoint"
  local data_info=""
  [ ${#curl_data_args[@]} -gt 0 ] && data_info=" with data: ${curl_data_args[*]}"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|$message Calling ${flac2mp3_type^} API using $method and URL '$url'$data_info" | log
  # Special handling of GET method
  if [ "$method" = "GET" ]; then
    curl_args+=(-G)
  else
    curl_args+=(-X "$method")
  fi
  # Add data arguments and url to curl arguments array
  curl_args+=("${curl_data_args[@]}")
  curl_args+=(--url "$url")
  [ $flac2mp3_debug -ge 2 ] && echo "Debug|Executing: curl ${curl_args[*]}" | sed -E 's/(X-Api-Key: )[^ ]+/\1[REDACTED]/' | log
  unset flac2mp3_result
  declare -g flac2mp3_result

  # Retry up to five times if database is locked
  local i
  for ((i=0; i <= 5; i++)); do
    flac2mp3_result=$(curl "${curl_args[@]}")
    local curl_return=$?
    # If database is locked, log and loop
    if wait_if_locked; then
      if [ $curl_return -ne 0 ]; then
        local error_message="$(echo $flac2mp3_result | jq -jcM 'if type=="array" then map(.errorMessage) | join(", ") else (if has("title") then "[HTTP \(.status?)] \(.title) \(.errors?)" elif has("message") then .message else "Unknown JSON format." end) end')"
        local message=$(echo -e "[$curl_return] curl error when calling: \"$url\"$data_info\nWeb server returned: $error_message" | awk '{print "Error|"$0}')
        echo "$message" | log
        echo_ansi "$message" >&2
      fi
      break
    fi
    if [ $i -eq 5 ]; then
      local message="Error|Database is locked after 5 attempts when calling ${flac2mp3_type^} API using $method and URL '$url'${data:+ with ${data[@]}}"
      echo "$message" | log
      echo_ansi "$message" >&2
    fi
  done

  # APIs can return A LOT of data, and it is not always needed for debugging
  [ $flac2mp3_debug -ge 2 ] && echo "Debug|API returned ${#flac2mp3_result} bytes." | log
  [ $flac2mp3_debug -ge $((2 + debug_add)) -a ${#flac2mp3_result} -gt 0 ] && echo "API returned: $flac2mp3_result" | awk '{print "Debug|"$0}' | log
  return $curl_return
}
function wait_if_locked {
  # Wait 1 minute if database is locked

  # Exit codes:
  #  0 - Database is not locked
  #  1 - Database is locked

  if [[ "$(echo $flac2mp3_result | jq -jcM '.message?')" =~ database\ is\ locked ]]; then
    local return=1
    echo "Warn|Database is locked; system is likely overloaded. Sleeping 1 minute." | log
    sleep 60
  else 
    local return=0
  fi
  return $return
}
function execute_ff_command {
  # Execute ffmpeg or ffprobe commands

  local action="$1" # Action being performed (for logging purposes)
  local command="$2" # Full ffmpeg or ffprobe command to execute
  local -a ff_args=() # Use array instead of string for safer argument passing

  # Process remaining data values
  shift 2
  while (( "$#" )); do
    ff_args+=("$1")
    shift
  done

  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Executing: $command ${ff_args[*]}" | log
  local shortcommand="$(echo $command | sed -E 's/(.+ )?(\/[^ ]+) .*$/\2/')"
  shortcommand=$(basename "$shortcommand")
  unset flac2mp3_ffresult
  # This must be a declare statement to avoid the 'Argument list too long' error with some large returned JSON
  declare -g flac2mp3_ffresult
  flac2mp3_ffresult=$($command "${ff_args[@]}")
  local return=$?
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|$shortcommand returned ${#flac2mp3_ffresult} bytes" | log
  [ $flac2mp3_debug -ge 2 ] && [ ${#flac2mp3_ffresult} -ne 0 ] && echo "$shortcommand returned: $flac2mp3_ffresult" | awk '{print "Debug|"$0}' | log
  if [ $return -ne 0 ]; then
    local message=$(echo -e "[$return] Error/Warning when $action.\n$shortcommand returned: $(echo "$flac2mp3_ffresult" | jq -RcrM '. as $raw | try ($raw | fromjson | .warnings[]) catch $raw')" | awk '{print "Error|"$0}')
    echo "$message" | log
    echo_ansi "$message" >&2
    end_script 12
  fi
  return $return
}
function get_media_config {
  # Get media management configuration

  call_api 0 "Getting ${flac2mp3_type^} configuration." "GET" "config/mediamanagement"
  local json_test="$(echo $flac2mp3_result | jq -crM '.id?')"
  [ "$json_test" != "null" ] && [ "$json_test" != "" ]
  return
}
function check_tracks {
  # Various sanity checks on tracks and output directory

  # Check for empty tracks variable
  if [ -z "$flac2mp3_tracks" ]; then
    local message="Error|No audio tracks were detected or specified!"
    echo "$message" | log
    echo_ansi "$message" >&2
    end_script 1
  fi

  # Check if source audio file exists
  if [ "${flac2mp3_mode,,}" = "batch" -o "${flac2mp3_mode,,}" = "import" ] && ! [ -f "$flac2mp3_tracks" ]; then
    local message="Error|Input file not found: '$flac2mp3_tracks'"
    echo "$message" | log
    echo_ansi "$message" >&2
    end_script 5
  fi

  # If specified, check if destination folder exists and create if necessary
  if [ -n "$flac2mp3_output" -a ! -d "$flac2mp3_output" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Destination directory does not exist. Creating: $flac2mp3_output" | log
    mkdir -p "$flac2mp3_output"
    local return=$?; [ $return -ne 0 ] && {
      local message="Error|[$return] mkdir returned an error. Unable to create output directory."
      echo "$message" | log
      echo_ansi "$message" >&2
      end_script 6
    }
  fi
}
function set_ffmpeg_parameters {
  # Set ffmpeg parameters based on user options

  case "$flac2mp3_debug" in
    0) export flac2mp3_ffmpeg_log="error" ;;
    1) export flac2mp3_ffmpeg_log="warning" ;;
    2) export flac2mp3_ffmpeg_log="info" ;;
    *) export flac2mp3_ffmpeg_log="debug" ;;
  esac
  if [ -n "$flac2mp3_bitrate" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using constant bitrate of $flac2mp3_bitrate" | log
    local brCommand="-b:a $flac2mp3_bitrate "
  elif [ -n "$flac2mp3_vbrquality" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using variable quality of $flac2mp3_vbrquality" | log
    brCommand="-q:a $flac2mp3_vbrquality "
  elif [ -n "$flac2mp3_ffmpegadv" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using advanced ffmpeg options \"$flac2mp3_ffmpegadv\"" | log
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Exporting with file extension \"$flac2mp3_extension\"" | log
    export flac2mp3_ffmpeg_opts="$flac2mp3_ffmpegadv"
  fi

  # Set default ffmpeg options
  [ -z "$flac2mp3_ffmpeg_opts" ] && export flac2mp3_ffmpeg_opts="-c:v copy -map 0 -y -acodec libmp3lame ${brCommand}-write_id3v1 1 -id3v2_version 3"
}
function process_tracks {
  # Process tracks loop
  
  # Changing the input field separator to split track string
  declare -g flac2mp3_import_list=""
  IFS=\|
  for track in $flac2mp3_tracks; do
    # Check that track exists
    if [ ! -f  "$track" ]; then
      local message="Error|Track file does not exist: '$track'"
      echo "$message" | log
      echo_ansi "$message" >&2
      continue
    fi

    # Regex doesn't match
    if ! [[ $track =~ $flac2mp3_regex ]]; then
      # Continue to move the file in Import mode
      if [ "${flac2mp3_mode,,}" == "import" ]; then
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|Only importing track that didn't match regex: $track" | log
        echo "Info|Importing '$flac2mp3_newtracks'" | log
        move_track "$track" "$flac2mp3_newtracks"
      else
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|Skipping track that did not match regex: $track" | log
      fi
      continue
    fi

    # Create temporary filename (see issue #54)
    local basename="$(basename -- "${track}")"
    local fileroot="${basename%.*}"
    local tempTrack="$(dirname -- "${track}")/$(mktemp -u -- "${fileroot:0:5}.tmp.XXXXXX")${flac2mp3_extension}"

    # Create a new track name with the given extension
    local newTrack="${track%.*}${flac2mp3_extension}"
    
    # In Import mode, use the directory and filename specified by Lidarr
    if [ "${flac2mp3_mode,,}" == "import" ]; then
      tempTrack="$(dirname -- "${flac2mp3_newtracks}")${tempTrack##*/}"
      newTrack="${flac2mp3_newtracks%.*}${flac2mp3_extension}"
    fi

    # Redirect output if asked
    if [ -n "$flac2mp3_output" ]; then
      tempTrack="${flac2mp3_output}${tempTrack##*/}"
      newTrack="${flac2mp3_output}${newTrack##*/}"
    fi
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Using temporary file '$tempTrack'" | log
    
    # Check for same track name (see issue #54)
    if [ "$newTrack" = "$track" -a $flac2mp3_keep -eq 1 ]; then
      local message="Error|The original track name and new name are the same, but the keep option was specified! Skipping track: $track"
      echo "$message" | log
      echo_ansi "$message" >&2
      change_exit_status 11
      continue
    fi
    
    # Set metadata options to fix tags if asked
    if [ -n "$flac2mp3_tags" ]; then
      local metadata=""
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Detecting and fixing common problems with the following metadata tags: $flac2mp3_tags" | log

      # Get track metadata
      if ffprobe "$track"; then
        for tag in $(echo $flac2mp3_tags | tr ',' '|'); do
          # shellcheck disable=SC2089
          case "$tag" in
            title )
              # Fix for parenthesis in titles for live and mix names
              local tag_title=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("title"; "i")).value')
              [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: title=$tag_title" | log
              local pattern='\([^)]+\)$'      # Rough way to limit editing metadata for every track
              if [[ "$tag_title" =~ $pattern ]]; then
                metadata+="-metadata title=\"$(echo "$tag_title" | sed -r 's/\((live|acoustic|demo|[^)]*((re)?mix(es)?|dub|edit|version))\)$/[\1]/i')\" "
              fi
            ;;
            disc )
              # Fix one disc by itself
              local tag_disc=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("disc"; "i")).value')
              [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: disc=$tag_disc" | log
              if [ "$tag_disc" = "1" ]; then
                metadata+='-metadata disc="1/1" '
              fi
            ;;
            genre )
              # Fix multiple genres
              local tag_genre=$(echo "$flac2mp3_ffprobe_json" | jq -crM '.format.tags | to_entries[] | select(.key | match("genre"; "i")).value')
              [ $flac2mp3_debug -ge 1 ] && echo "Debug|Original metadata: genre=$tag_genre" | log
              # Only trigger on multiple genres
              if [[ $tag_genre =~ \; ]]; then
                case "$tag_genre" in
                  *Synth-Pop*) metadata+='-metadata genre="Electronica & Dance" ' ;;
                  *Pop*) metadata+='-metadata genre="Pop" ' ;;
                  *Indie*) metadata+='-metadata genre="Alternative & Indie" ' ;;
                  *Industrial*) metadata+='-metadata genre="Industrial Rock" ' ;;
                  *Electronic*) metadata+='-metadata genre="Electronica & Dance" ' ;;
                  *Punk*|*Alternative*) metadata+='-metadata genre="Alternative & Punk" ' ;;
                  *Rock*) metadata+='-metadata genre="Rock" ' ;;
                esac
              fi
            ;;
          esac
        done
        # shellcheck disable=SC2090
        [ $flac2mp3_debug -ge 1 ] && echo "Debug|New metadata: ${metadata//-metadata /}" | log
      else
        echo "Warn|ffprobe did not return any data when querying track: '$track'" | log
        change_exit_status 12
      fi
    fi
    
    # Convert the track
    echo "Info|Writing: $newTrack" | log
    local ffcommand="nice /usr/bin/ffmpeg"
    IFS=$' \t\n'  # Temporarily restore IFS
    # shellcheck disable=SC2090
    execute_ff_command "converting track: '$track' to '$tempTrack'" "$ffcommand" -loglevel $flac2mp3_ffmpeg_log -nostdin -i "$track" $flac2mp3_ffmpeg_opts $metadata "$tempTrack"
    local return=$?; [ $return -ne 0 ] && {
      change_exit_status 13
      # Delete the temporary file if it exists
      [ -f "$tempTrack" ] && rm -f "$tempTrack"
      continue
    }
    IFS=\|  # Go back to pipe IFS

    # Check for non-zero size file
    if [ ! -s "$tempTrack" ]; then
      local message="Error|The new track does not exist or is zero bytes: '$tempTrack'"
      echo "$message" | log
      echo_ansi "$message" >&2
      change_exit_status 14
      continue
    fi

    # Checking that we're running as root
    if [ "$(id -u)" -eq 0 ]; then
      # Set owner
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Changing owner of file '$tempTrack'" | log
      local result
      result=$(chown --reference="$track" "$tempTrack")
      local return=$?; [ $return -ne 0 ] && {
        local message=$(echo -e "[$return] Error when changing owner of file: '$tempTrack'\nchown returned: $result" | awk '{print "Error|"$0}')
        echo "$message" | log
        echo_ansi "$message" >&2
        change_exit_status 15
      }
    else
      # Unable to change owner when not running as root
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Unable to change owner of track when running as user '$(id -un)'" | log
    fi
    # Set permissions
    local result
    result=$(chmod --reference="$track" "$tempTrack")
    local return=$?; [ $return -ne 0 ] && {
      local message=$(echo -e "[$return] Error when changing permissions of file: '$tempTrack'\nchmod returned: $result" | awk '{print "Error|"$0}')
      echo "$message" | log
      echo_ansi "$message" >&2
      change_exit_status 15
    }

    # Do not delete the source file if configured and not in Import mode. Skip import.
    # NOTE: Implied that the new track and the original track do not have the same name due to earlier check
    if [ "${flac2mp3_mode,,}" != "import" -a $flac2mp3_keep -eq 1 ]; then
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Keeping original: '$track'" | log
      # Rename the temporary file to the new track name
      move_track "$tempTrack" "$newTrack"
      continue
    fi

    # If in Batch or Import mode, just delete the original file
    if [ "${flac2mp3_mode,,}" = "batch" -o "${flac2mp3_mode,,}" = "import" ]; then
      [ $flac2mp3_debug -ge 1 ] && echo "Debug|Deleting: '$track'" | log
      local result
      result=$(rm -f "$track")
      local return=$?; [ $return -ne 0 ] && {
        local message=$(echo -e "[$return] Error when deleting file: '$track'\nrm returned: $result" | awk '{print "Error|"$0}')
        echo "$message" | log
        echo_ansi "$message" >&2
        change_exit_status 16
      }
    else
      # Call Lidarr to delete the original file, or recycle if configured.
      local track_id=$(echo $flac2mp3_trackfiles | jq -crM ".[] | select(.path == \"$track\") | .id")
      delete_track $track_id
      local return=$?; [ $return -ne 0 ] && {
        local message="Error|[$return] ${flac2mp3_type^} error when deleting the original track: '$track'. Not importing new track into ${flac2mp3_type^}."
        echo "$message" | log
        echo_ansi "$message" >&2
        change_exit_status 17
        continue
      }
    fi

    # Rename the temporary file to the new track name (see issue #54)
    move_track "$tempTrack" "$newTrack"
    local return=$?; [ $return -ne 0 ] && {
      continue
    }

    # Add new track to list of tracks to import
    flac2mp3_import_list+="${newTrack}|"
  done
  # Restore IFS
  IFS=$' \t\n'
  # Remove trailing pipe
  flac2mp3_import_list="${flac2mp3_import_list%|}"
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Track import list: $flac2mp3_import_list" | log
}
function update_database {
  # Call Lidarr API to update database

  # Check for Batch mode
  if [ "${flac2mp3_mode,,}" = "batch" ]; then
    [ $flac2mp3_debug -ge 1 ] && echo "Debug|Not calling API while in batch mode." | log
    return
  fi

  # Do not update the database if the original file still exists
  if [ $flac2mp3_keep -eq 1 ]; then
    echo "Info|Original audio file(s) kept, no database update performed." | log
    return
  fi

  # Check for URL
  if [ -z "$flac2mp3_api_url" ]; then
    # No URL means we can't call the API
    local message="Warn|Unable to determine ${flac2mp3_type^} API URL."
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 20
    return
  fi

  # Check for artist ID
  if [ -z "$lidarr_artist_id" ]; then
    # No Artist ID means we can't call the API
    local message="Warn|Missing environment variable lidarr_artist_id"
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 20
    return
  fi

  # Check the count of files to import into Lidarr when not in Import mode
  export flac2mp3_import_count=$(echo $flac2mp3_import_list | awk -F\| '{print NF}')
  if [ $flac2mp3_import_count -eq 0 ]; then
    # Getting here in Import mode means the regex didn't match any tracks, so we moved the track without adding to the import list.
    if [ "${flac2mp3_mode,,}" == "import" ]; then
      return
    fi
    local message="Warn|Didn't find any tracks to import."
    echo "$message" | log
    echo_ansi "$message" >&2
    return
  fi

  # Scan for files to import into Lidarr
  echo "Info|Preparing to import $flac2mp3_import_count new files. This make take a long time for large libraries." | log
  if ! get_import_info; then
    local message="Error|${flac2mp3_type^} error getting import file list in '$lidarr_artist_path' for artist ID $lidarr_artist_id"
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 17
    return
  fi

  # Build JSON data for all tracks
  # NOTE: Tracks with empty track IDs will not appear in the resulting JSON and will therefore not be imported into Lidarr
  [ $flac2mp3_debug -ge 1 ] && echo "Debug|Building JSON data to import" | log
  export flac2mp3_json=$(echo $flac2mp3_result | jq -jcM "
    map(
      select(.path | inside(\"$flac2mp3_import_list\")) |
      {path, \"artistId\":$lidarr_artist_id, \"albumId\":$lidarr_album_id, albumReleaseId,\"trackIds\":[.tracks[].id], quality, \"disableReleaseSwitching\":false}
    )
  ")

  # Import new files into Lidarr (see issue #39)
  import_tracks
  local return=$?; [ $return -ne 0 ] && {
    local message="Error|[$return] ${flac2mp3_type^} error when importing the new tracks!"
    echo "$message" | log
    echo_ansi "$message" >&2
    change_exit_status 17
  }
  local jobid="$(echo $flac2mp3_result | jq -crM .id)"

  # Check status of job (see issue #39)
  check_job $jobid
  local return=$?; [ $return -ne 0 ] && {
    case $return in
      1) local message="Info|${flac2mp3_type^} job ID $jobid is queued. Trusting this will complete and exiting."
      ;;
      2) local message="Warn|${flac2mp3_type^} job ID $jobid failed."
        change_exit_status 17
      ;;
      3) local message="Warn|Script timed out waiting on ${flac2mp3_type^} job ID $jobid. Last status was: $(echo $flac2mp3_result | jq -crM .status)"
        change_exit_status 18
      ;;
      10) local message="Error|${flac2mp3_type^} job ID $jobid returned a curl error."
        change_exit_status 17
      ;;
    esac
    echo "$message" | log
    echo_ansi "$message" >&2
  }
}
### End Functions

# Do not execute if this script is being sourced from a test script
if [[ ! "${BASH_SOURCE[1]}" =~ test_.*\.sh$ ]]; then
  main "$@"
  end_script
fi
