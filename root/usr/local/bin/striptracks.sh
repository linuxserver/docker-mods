#!/bin/bash

# Video remuxing script designed for use with Radarr and Sonarr
# Automatically strips out unwanted audio and subtitles tracks, keeping only the desired languages.
#  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks
#  Dev/test: https://github.com/TheCaptain989/radarr-striptracks
#
# Inspired by Endoro's post 1/5/2014:
#  https://forum.videohelp.com/threads/343271-BULK-remove-non-English-tracks-from-MKV-container#post2292889
#
# Put a colon `:` in front of every language code.  Expects ISO639-2 codes

# NOTE: ShellCheck linter directives appear as comments

# Dependencies:      # sudo apt install mkvtoolnix jq
#  From mkvtoolnix:
#   mkvmerge
#   mkvpropedit
#  From jq:
#   jq
#  Generally always available:
#   sed
#   awk
#   curl
#   numfmt
#   stat
#   nice
#   basename
#   dirname
#   mktemp

# Exit codes:
#  0 - success; or test
#  1 - no video file specified on command line
#  2 - no audio language specified on command line
#  3 - no subtitles language specified on command line
#  4 - mkvmerge, mkvpropedit, or jq not found
#  5 - input video file not found
#  6 - unable to rename temp video to MKV
#  7 - unknown eventtype environment variable
#  8 - unsupported Radarr/Sonarr version (v2)
#  9 - mkvmerge get media info produced an error or warning
# 10 - remuxing completed, but no output file found
# 11 - source video had no audio tracks
# 12 - log file is not writable
# 13 - mkvmerge or mkvpropedit exited with an error
# 15 - could not set permissions and/or owner on new file
# 16 - could not delete the original file
# 17 - Radarr/Sonarr API error
# 18 - Radarr/Sonarr job timeout
# 20 - general error

### Variables
export striptracks_script=$(basename "$0")
export striptracks_ver="{{VERSION}}"
export striptracks_pid=$$
export striptracks_arr_config=/config/config.xml
export striptracks_log=/config/logs/striptracks.txt
export striptracks_maxlogsize=512000
export striptracks_maxlog=4
export striptracks_debug=0
# Presence of '*_eventtype' variable sets script mode
export striptracks_type=$(printenv | sed -n 's/_eventtype *=.*$//p')

# Usage functions
function usage {
  usage="Try '$striptracks_script --help' for more information."
  echo "$usage" >&2
}
function long_usage {
  usage="$striptracks_script   Version: $striptracks_ver
Video remuxing script that only keeps tracks with the specified languages.
Designed for use with Radarr and Sonarr, but may be used standalone in batch
mode.

Source: https://github.com/TheCaptain989/radarr-striptracks

Usage:
  $0 [{-a|--audio} <audio_languages> [{-s|--subs} <subtitle_languages>] [--reorder] [{-f|--file} <video_file>]] [{-l|--log} <log_file>] [{-c|--config} <config_file>] [{-d|--debug} [<level>]]

  Options can also be set via the STRIPTRACKS_ARGS environment variable.
  Command-line arguments override the environment variable.

Options and Arguments:
  -a, --audio <audio_languages>    Audio languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   multiple codes may be concatenated.
                                   Each code may optionally be followed by a
                                   plus \`+\` and one or more modifiers.
  -s, --subs <subtitle_languages>  Subtitles languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   multiple codes may be concatenated.
                                   Each code may optionally be followed by a
                                   plus \`+\` and one or more modifiers.
      --reorder                    Reorder audio and subtitles tracks to match
                                   the language code order specified in the
                                   <audio_languages> and <subtitle_languages>
                                   arguments.
  -f, --file <video_file>          If included, the script enters batch mode
                                   and converts the specified video file.
                                   WARNING: Do not use this argument when called
                                   from Radarr or Sonarr!
  -l, --log <log_file>             Log filename
                                   [default: /config/log/striptracks.txt]
  -c, --config <config_file>       Radarr/Sonarr XML configuration file
                                   [default: ./config/config.xml]
  -d, --debug [<level>]            Enable debug logging
                                   level is optional, between 1-3
                                   1 is lowest, 3 is highest
                                   [default: 1]
      --help                       Display this help and exit
      --version                    Display script version and exit
      
When audio_languages and subtitle_languages are omitted the script detects the
audio or subtitle languages configured in the Radarr or Sonarr profile.  When
used on the command line, they override the detected codes.  They are also
accepted as positional parameters for backwards compatibility.

Language modifiers may be \`f\` or \`d\` which select Forced or Default tracks
respectively, or a number which specifies the maximum tracks to keep.

Batch Mode:
  In batch mode the script acts as if it were not called from within Radarr
  or Sonarr.  It converts the file specified on the command line and ignores
  any environment variables that are normally expected.  The MKV embedded title
  attribute is set to the basename of the file minus the extension.

Examples:
  $striptracks_script -d 2                      # Enable debugging level 2, audio and
                                           # subtitles languages detected from
                                           # Radarr/Sonarr
  $striptracks_script -a :eng:und -s :eng       # Keep English and Unknown audio and
                                           # English subtitles
  $striptracks_script -a :eng:org -s :any+f:eng # Keep English and Original audio,
                                           # and forced or English subtitles
  $striptracks_script -a :eng -s \"\"             # Keep English audio and no subtitles
  $striptracks_script -d :eng:kor:jpn :eng:spa  # Enable debugging level 1, keeping
                                           # English, Korean, and Japanese
                                           # audio, and English and Spanish
                                           # subtitles
  $striptracks_script -f \"/movies/path/Finding Nemo (2003).mkv\" -a :eng:und -s :eng
                                           # Batch Mode
                                           # Keep English and Unknown audio and
                                           # English subtitles, converting video
                                           # specified
  $striptracks_script -a :any -s \"\"             # Keep all audio and no subtitles
  $striptracks_script -a :org:any+d1 -s :eng+1:any+f2
                                           # Keep all Original and one default
                                           # audio in any language, and one
                                           # English and two forced subtitles
                                           # in any language
"
  echo "$usage"
}

# Log command-line arguments
if [ $# -ne 0 ]; then
  striptracks_prelogmessagedebug="Debug|Command line arguments are '$*'"
fi

# Check for environment variable arguments
if [ -n "$STRIPTRACKS_ARGS" ]; then
  if [ $# -ne 0 ]; then
    striptracks_prelogmessage="Warning|STRIPTRACKS_ARGS environment variable set but will be ignored because command line arguments were also specified."
  else
    # Move the environment variable arguments to the command line for processing
    striptracks_prelogmessage="Info|Using settings from environment variable."
    eval set -- "$STRIPTRACKS_ARGS"
  fi
fi

# Process arguments
# Taken from Drew Stokes post 3/24/2015:
#  https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
unset striptracks_pos_params
while (( "$#" )); do
  case "$1" in
    -d|--debug ) # Enable debugging, with optional level
      if [ -n "$2" ] && [ ${2:0:1} != "-" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
        export striptracks_debug=$2
        shift 2
      else
        export striptracks_debug=1
        shift
      fi
    ;;
    -l|--log ) # Log file
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export striptracks_log="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 1
      fi
    ;;
    --help ) # Display full usage
      long_usage
      exit 0
    ;;
    --version ) # Display version
      echo "$striptracks_script $striptracks_ver"
      exit 0
    ;;
    -f|--file ) # Batch Mode
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        # Overrides detected *_eventtype
        export striptracks_type="batch"
        export striptracks_video="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 1
      fi
    ;;
    -a|--audio ) # Audio languages to keep
      if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 2
      elif [[ "$2" != :* ]]; then
        echo "Error|Invalid option: $1 argument requires a colon." >&2
        usage
        exit 2
      fi
      export striptracks_audiokeep="$2"
      shift 2
    ;;
    -s|--subs|--subtitles ) # Subtitles languages to keep
      if [ -z "$2" ] || [ ${2:0:1} = "-" ]; then
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 3
      elif [[ "$2" != :* ]]; then
        echo "Error|Invalid option: $1 argument requires a colon." >&2
        usage
        exit 3
      fi
      export striptracks_subskeep="$2"
      shift 2
    ;;
    -c|--config ) # *arr XML configuration file
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        # Overrides default /config/config.xml
        export striptracks_arr_config="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 1
      fi
    ;;
    --reorder ) # Reorder audio and subtitles tracks
      export striptracks_reorder="true"
      shift
    ;;
    -*) # Unknown option
      echo "Error|Unknown option: $1" >&2
      usage
      exit 20
    ;;
    *) # preserve positional arguments
      striptracks_pos_params="$striptracks_pos_params $1"
      shift
    ;;
  esac
done
# Set positional arguments in their proper place
eval set -- "$striptracks_pos_params"

# Check for and assign positional arguments. Named override positional.
if [ -n "$1" ]; then
  if [ -n "$striptracks_audiokeep" ]; then
    echo "Warning|Both positional and named arguments set for audio. Using $striptracks_audiokeep" >&2
  else
    striptracks_audiokeep="$1"
  fi
fi
if [ -n "$2" ]; then
  if [ -n "$striptracks_subskeep" ]; then
    echo "Warning|Both positional and named arguments set for subtitles. Using $striptracks_subskeep" >&2
  else
    striptracks_subskeep="$2"
  fi
fi

## Mode specific variables
if [[ "${striptracks_type,,}" = "batch" ]]; then
  # Batch mode
  export batch_eventtype="Convert"
  export striptracks_title="$(basename "$striptracks_video" ".${striptracks_video##*.}")"
elif [[ "${striptracks_type,,}" = "radarr" ]]; then
  # Radarr mode
  # shellcheck disable=SC2154
  export striptracks_video="$radarr_moviefile_path"
  # shellcheck disable=SC2154
  export striptracks_video_folder="$radarr_movie_path"
  export striptracks_video_api="movie"
  # shellcheck disable=SC2154
  export striptracks_video_id="${radarr_movie_id}"
  export striptracks_videofile_api="moviefile"
  # shellcheck disable=SC2154
  export striptracks_videofile_id="${radarr_moviefile_id}"
  # shellcheck disable=SC2154
  export striptracks_rescan_id="${radarr_movie_id}"
  export striptracks_json_quality_root="movieFile"
  export striptracks_video_type="movie"
  export striptracks_video_rootNode=""
  # shellcheck disable=SC2154
  export striptracks_title="${radarr_movie_title:-UNKNOWN} (${radarr_movie_year:-UNKNOWN})"
  export striptracks_language_jq=".language"
  # export striptracks_language_node="languages"
elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
  # Sonarr mode
  # shellcheck disable=SC2154
  export striptracks_video="$sonarr_episodefile_path"
  # shellcheck disable=SC2154
  export striptracks_video_folder="$sonarr_series_path"
  export striptracks_video_api="episode"
  # shellcheck disable=SC2154
  export striptracks_video_id="${sonarr_episodefile_episodeids}"
  export striptracks_videofile_api="episodefile"
  # shellcheck disable=SC2154
  export striptracks_videofile_id="${sonarr_episodefile_id}"
  # shellcheck disable=SC2154
  export striptracks_rescan_id="${sonarr_series_id}"
  export striptracks_json_quality_root="episodeFile"
  export striptracks_video_type="series"
  export striptracks_video_rootNode=".series"
  # shellcheck disable=SC2154
  export striptracks_title="${sonarr_series_title:-UNKNOWN} $(numfmt --format "%02f" ${sonarr_episodefile_seasonnumber:-0})x$(numfmt --format "%02f" ${sonarr_episodefile_episodenumbers:-0}) - ${sonarr_episodefile_episodetitles:-UNKNOWN}"
  # export striptracks_language_node="language"
  # # Sonarr requires the episodeIds array
  # export striptracks_sonarr_json=" \"episodeIds\":[.episodes[].id],"
else
  # Called in an unexpected way
  echo -e "Error|Unknown or missing '*_eventtype' environment variable: ${striptracks_type}\nNot calling from Radarr/Sonarr? Try using Batch Mode option: -f <file>" >&2
  usage
  exit 7
fi
export striptracks_rescan_api="Rescan${striptracks_video_type^}"
export striptracks_eventtype="${striptracks_type,,}_eventtype"
export striptracks_newvideo="${striptracks_video%.*}.mkv"
# If this were defined directly in Radarr or Sonarr this would not be needed here
# shellcheck disable=SC2089
striptracks_isocodemap='{"languages":[{"language":{"name":"Any","iso639-2":["any"]}},{"language":{"name":"Afrikaans","iso639-2":["afr"]}},{"language":{"name":"Albanian","iso639-2":["sqi","alb"]}},{"language":{"name":"Arabic","iso639-2":["ara"]}},{"language":{"name":"Bengali","iso639-2":["ben"]}},{"language":{"name":"Bosnian","iso639-2":["bos"]}},{"language":{"name":"Bulgarian","iso639-2":["bul"]}},{"language":{"name":"Catalan","iso639-2":["cat"]}},{"language":{"name":"Chinese","iso639-2":["zho","chi"]}},{"language":{"name":"Croatian","iso639-2":["hrv"]}},{"language":{"name":"Czech","iso639-2":["ces","cze"]}},{"language":{"name":"Danish","iso639-2":["dan"]}},{"language":{"name":"Dutch","iso639-2":["nld","dut"]}},{"language":{"name":"English","iso639-2":["eng"]}},{"language":{"name":"Estonian","iso639-2":["est"]}},{"language":{"name":"Finnish","iso639-2":["fin"]}},{"language":{"name":"Flemish","iso639-2":["nld","dut"]}},{"language":{"name":"French","iso639-2":["fra","fre"]}},{"language":{"name":"German","iso639-2":["deu","ger"]}},{"language":{"name":"Greek","iso639-2":["ell","gre"]}},{"language":{"name":"Hebrew","iso639-2":["heb"]}},{"language":{"name":"Hindi","iso639-2":["hin"]}},{"language":{"name":"Hungarian","iso639-2":["hun"]}},{"language":{"name":"Icelandic","iso639-2":["isl","ice"]}},{"language":{"name":"Indonesian","iso639-2":["ind"]}},{"language":{"name":"Italian","iso639-2":["ita"]}},{"language":{"name":"Japanese","iso639-2":["jpn"]}},{"language":{"name":"Kannada","iso639-2":["kan"]}},{"language":{"name":"Korean","iso639-2":["kor"]}},{"language":{"name":"Latvian","iso639-2":["lav"]}},{"language":{"name":"Lithuanian","iso639-2":["lit"]}},{"language":{"name":"Macedonian","iso639-2":["mac","mkd"]}},{"language":{"name":"Malayalam","iso639-2":["mal"]}},{"language":{"name":"Marathi","iso639-2":["mar"]}},{"language":{"name":"Norwegian","iso639-2":["nno","nob","nor"]}},{"language":{"name":"Persian","iso639-2":["fas","per"]}},{"language":{"name":"Polish","iso639-2":["pol"]}},{"language":{"name":"Portuguese","iso639-2":["por"]}},{"language":{"name":"Portuguese (Brazil)","iso639-2":["por"]}},{"language":{"name":"Romanian","iso639-2":["rum","ron"]}},{"language":{"name":"Russian","iso639-2":["rus"]}},{"language":{"name":"Serbian","iso639-2":["srp"]}},{"language":{"name":"Slovak","iso639-2":["slk","slo"]}},{"language":{"name":"Slovenian","iso639-2":["slv"]}},{"language":{"name":"Spanish","iso639-2":["spa"]}},{"language":{"name":"Spanish (Latino)","iso639-2":["spa"]}},{"language":{"name":"Swedish","iso639-2":["swe"]}},{"language":{"name":"Tagalog","iso639-2":["tgl"]}},{"language":{"name":"Tamil","iso639-2":["tam"]}},{"language":{"name":"Telugu","iso639-2":["tel"]}},{"language":{"name":"Thai","iso639-2":["tha"]}},{"language":{"name":"Turkish","iso639-2":["tur"]}},{"language":{"name":"Ukrainian","iso639-2":["ukr"]}},{"language":{"name":"Vietnamese","iso639-2":["vie"]}},{"language":{"name":"Unknown","iso639-2":["und"]}}]}'

### Functions

# Can still go over striptracks_maxlog if read line is too long
## Must include whole function in subshell for read to work!
function log {(
  while read -r
  do
    # shellcheck disable=2046
    echo $(date +"%Y-%m-%d %H:%M:%S.%1N")"|[$striptracks_pid]$REPLY" >>"$striptracks_log"
    local striptracks_filesize=$(stat -c %s "$striptracks_log")
    if [ $striptracks_filesize -gt $striptracks_maxlogsize ]
    then
      for i in $(seq $((striptracks_maxlog-1)) -1 0); do
        [ -f "${striptracks_log::-4}.$i.txt" ] && mv "${striptracks_log::-4}."{$i,$((i+1))}".txt"
      done
      [ -f "${striptracks_log::-4}.txt" ] && mv "${striptracks_log::-4}.txt" "${striptracks_log::-4}.0.txt"
      touch "$striptracks_log"
    fi
  done
)}
# Inspired by https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
function read_xml {
  local IFS=\>
  read -r -d \< striptracks_xml_entity striptracks_xml_content
}
# Get Radarr/Sonarr version
function get_version {
  local url="$striptracks_api_url/system/status"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting ${striptracks_type^} version. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.version?')" != "null" ] && [ "$(echo $striptracks_result | jq -crM '.version?')" != "" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get video information
function get_video_info {
  local url="$striptracks_api_url/$striptracks_video_api/$striptracks_video_id"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting video information for $striptracks_video_api '$striptracks_video_id'. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq -crM .hasFile)" = "true" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get video file information
function get_videofile_info {
  local url="$striptracks_api_url/$striptracks_videofile_api/$striptracks_videofile_id"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting video file information for $striptracks_videofile_api '$striptracks_videofile_id'. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq -crM .path)" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Initiate Rescan request
function rescan {
  local url="$striptracks_api_url/command"
  local data="{\"name\":\"$striptracks_rescan_api\",\"${striptracks_video_type}Id\":$striptracks_rescan_id}"
  echo "Info|Calling ${striptracks_type^} API to rescan ${striptracks_video_type}" | log
  local i=0
  for ((i=1; i <= 5; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Forcing rescan of $striptracks_video_type '$striptracks_rescan_id'. Calling ${striptracks_type^} API using POST and URL '$url' with data $data" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      echo "Warn|Database is locked; system is likely overloaded. Sleeping 1 minute." | log
      sleep 60
    fi
  done
  striptracks_jobid="$(echo $striptracks_result | jq -crM .id)"
  if [ $striptracks_curlret -eq 0 -a "$striptracks_jobid" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Check result of command job
function check_job {
  # Exit codes:
  #  0 - success
  #  1 - queued
  #  2 - failed
  #  3 - loop timed out
  # 10 - curl error
  local url="$striptracks_api_url/command/$striptracks_jobid"
  local i=0
  [ $striptracks_debug -ge 1 ] && echo "Debug|Checking job $striptracks_jobid completion. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  for ((i=1; i <= 15; i++)); do
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --get "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      local striptracks_return=10
      break
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log

    # Guard clauses
    if [ "$(echo $striptracks_result | jq -crM .status)" = "failed" ]; then
      local striptracks_return=2
      break
    fi
    if [ "$(echo $striptracks_result | jq -crM .status)" = "queued" ]; then
      local striptracks_return=1
      break
    fi
    if [ "$(echo $striptracks_result | jq -crM .status)" = "completed" ]; then
      local striptracks_return=0
      break
    fi

    # It may have timed out, so let's wait a second
    [ $striptracks_debug -ge 1 ] && echo "Debug|Job not done. Waiting 1 second." | log
    local striptracks_return=3
    sleep 1
  done
  return $striptracks_return
}
# Get profiles
function get_profiles {
  local url="$striptracks_api_url/${1}profile"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of $1 profiles. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  # This returns A LOT of data, and it is normally not needed for debugging
  [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
  [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq -crM '.message?')" != "NotFound" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get language codes
function get_language_codes {
  local url="$striptracks_api_url/language"
  if check_compat languageprofile; then
    local url="$striptracks_api_url/languageprofile"
  fi
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of language codes. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  # This returns more data than is normally needed for debugging
  [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
  [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq -crM '.[] | .name')" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get custom formats
function get_custom_formats {
  local url="$striptracks_api_url/customformat"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of Custom Formats. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  # This returns more data than is normally needed for debugging
  [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
  [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq -crM '.[] | .name')" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Delete track
function delete_video {
  local url="$striptracks_api_url/$striptracks_videofile_api/$1"
  local i=0
  for ((i=1; i <= 5; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Deleting or recycling \"$striptracks_video\". Calling ${striptracks_type^} API using DELETE and URL '$url'" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
       -H "Content-Type: application/json" \
       -H "Accept: application/json" \
       -X DELETE "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      echo "Warn|Database is locked; system is likely overloaded. Sleeping 1 minute." | log
      sleep 60
    fi
  done
  if [ $striptracks_curlret -eq 0 ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# # Get file details on possible files to import into Radarr/Sonarr
# function get_import_info {
  # local url="$striptracks_api_url/manualimport"
  # if [[ "${striptracks_type,,}" = "radarr" ]]; then
    # local temp_id="${striptracks_video_type}Id=$striptracks_rescan_id"
  # fi
  # [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of files that can be imported. Calling ${striptracks_type^} API using GET and URL '$url?${temp_id:+$temp_id&}folder=$striptracks_video_folder&filterExistingFiles=false'" | log
  # unset striptracks_result
  # # Adding a 'seriesId' to the Sonarr import causes the returned videos to have an 'Unknown' quality. Probably a bug.
  # striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    # -H "Content-Type: application/json" \
		# -H "Accept: application/json" \
    # --data-urlencode "${temp_id}" \
    # --data-urlencode "folder=$striptracks_video_folder" \
    # -d "filterExistingFiles=false" \
    # --get "$url")
  # local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    # local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url?${temp_id:+$temp_id&}folder=$striptracks_video_folder&filterExistingFiles=false\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    # echo "$striptracks_message" | log
    # echo "$striptracks_message" >&2
  # }
  # [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
  # [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  # if [ $striptracks_curlret -eq 0 -a "${#striptracks_result}" != 0 ]; then
    # local striptracks_return=0
  # else
    # local striptracks_return=1
  # fi
  # return $striptracks_return
# }
# Update file metadata in Radarr/Sonarr
function set_metadata {
  local url="$striptracks_api_url/$striptracks_videofile_api/editor"
  local data="$(echo $striptracks_original_metadata | jq -crM "{${striptracks_videofile_api}Ids: [${striptracks_videofile_id}], quality, releaseGroup}")"
  local i=0
  for ((i=1; i <= 5; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from quality '$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)' to '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)' and release group '$(echo $striptracks_videofile_info | jq -crM '.releaseGroup | select(. != null)')' to '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'. Calling ${striptracks_type^} API using PUT and URL '$url' with data $data" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      -X PUT "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
    [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      echo "Warn|Database is locked; system is likely overloaded. Sleeping 1 minute." | log
      sleep 60
    fi
  done
  if [ $striptracks_curlret -eq 0 -a "${#striptracks_result}" != 0 ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Read in the output of mkvmerge info extraction (see issue #87)
function get_mediainfo {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: /usr/bin/mkvmerge -J \"$1\"" | log
  unset striptracks_json
  striptracks_json=$(/usr/bin/mkvmerge -J "$1")
  local striptracks_return=$?
  [ $striptracks_debug -ge 2 ] && echo "mkvmerge returned: $striptracks_json" | awk '{print "Debug|"$0}' | log
  case $striptracks_return in
    0)
      # Check for unsupported container.
      if [ "$(echo "$striptracks_json" | jq -crM '.container.supported')" = "false" ]; then
        striptracks_message="Error|Video format for '$1' is unsupported. Unable to continue. mkvmerge returned container info: $(echo $striptracks_json | jq -crM .container)"
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        end_script 9
      fi
    ;;
    1) striptracks_message=$(echo -e "[$striptracks_return] Warning when inspecting video.\nmkvmerge returned: $(echo "$striptracks_json" | jq -crM '.warnings[]')" | awk '{print "Warn|"$0}')
      echo "$striptracks_message" | log
    ;;
    2) striptracks_message=$(echo -e "[$striptracks_return] Error when inspecting video.\nmkvmerge returned: $(echo "$striptracks_json" | jq -crM '.errors[]')" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      end_script 9
    ;;
  esac
  return $striptracks_return
}
# # Import new video into Radarr/Sonarr
# function import_video {
  # local url="$striptracks_api_url/command"
  # local data="{\"name\":\"ManualImport\",\"files\":$striptracks_json,\"importMode\":\"auto\"}"
  # echo "Info|Importing new video \"$striptracks_newvideo\" into ${striptracks_type^}" | log
  # [ $striptracks_debug -ge 1 ] && echo "Debug|Importing new file into ${striptracks_type^}. Calling ${striptracks_type^} API using POST and URL '$url' with data $data" | log
  # unset striptracks_result
  # striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    # -H "Content-Type: application/json" \
		# -H "Accept: application/json" \
    # -d "$data" \
    # "$url")
  # local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    # local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    # echo "$striptracks_message" | log
    # echo "$striptracks_message" >&2
  # }
  # [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  # if [ $striptracks_curlret -eq 0 -a "$(echo $striptracks_result | jq .id?)" != "null" ]; then
    # local striptracks_return=0
  # else
    # local striptracks_return=1
  # fi
  # return $striptracks_return
# }
# Get video files from Radarr/Sonarr that need to be renamed
function get_rename {
  local url="$striptracks_api_url/rename"
  local data="${striptracks_video_type}Id=$striptracks_rescan_id"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of videos that could be renamed. Calling ${striptracks_type^} API using GET and URL '$url&$data'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$data" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url&$data\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$striptracks_result" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Rename video file according to Radarr/Sonarr naming rules
function rename_video {
  local url="$striptracks_api_url/command"
  local data="{\"name\":\"RenameFiles\",\"${striptracks_video_type}Id\":$striptracks_rescan_id,\"files\":[$striptracks_videofile_id]}"
  echo "Info|Renaming new video file per ${striptracks_type^}'s rules to \"$(basename "$striptracks_renamedvideo")\"" | log
  [ $striptracks_debug -ge 1 ] && echo "Debug|Renaming \"$striptracks_newvideo\". Calling ${striptracks_type^} API using POST and URL '$url' with data $data" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$striptracks_result" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Set video language in Radarr
function set_radarr_language {
  local url="$striptracks_api_url/$striptracks_videofile_api/editor"
  local data="{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"languages\":${striptracks_json_languages}}"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from language(s) '$(echo $striptracks_videofile_info | jq -crM "[.languages[].name] | join(\",\")")' to '$(echo $striptracks_json_languages | jq -crM "[.[].name] | join(\",\")")'. Calling ${striptracks_type^} API using PUT and URL '$url' with data $data" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    -X PUT "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$striptracks_result" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Set video language in Sonarr
function set_sonarr_language {
  local url="$striptracks_api_url/$striptracks_videofile_api/editor"
  local data="{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"language\":$(echo $striptracks_json_languages | jq -crM ".[0]")}"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from language '$(echo $striptracks_videofile_info | jq -crM ".language.name")' to '$(echo $striptracks_json_languages | jq -crM ".[0].name")'. Calling ${striptracks_type^} API using PUT and URL '$url' with data $data" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    -X PUT "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ $striptracks_curlret -eq 0 -a "$striptracks_result" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Compatibility checker
function check_compat {
  # return of 1 = the feature is incompatible
  local striptracks_return=1
  case "$1" in
    apiv3)
      [ ${striptracks_arr_version/.*/} -ge 3 ] && local striptracks_return=0
    ;;
    languageprofile)
      # Langauge Profiles
      [ "${striptracks_type,,}" = "sonarr" ] && [ ${striptracks_arr_version/.*/} -eq 3 ] && local striptracks_return=0
    ;;
    customformat)
      # Language option in Custom Formats
      [ "${striptracks_type,,}" = "radarr" ] && [ ${striptracks_arr_version/.*/} -ge 3 ] && local striptracks_return=0
      [ "${striptracks_type,,}" = "sonarr" ] && [ ${striptracks_arr_version/.*/} -ge 4 ] && local striptracks_return=0
    ;;
    originallanguage)
      # Original language selection
      [ "${striptracks_type,,}" = "radarr" ] && [ ${striptracks_arr_version/.*/} -ge 3 ] && local striptracks_return=0
      [ "${striptracks_type,,}" = "sonarr" ] && [ ${striptracks_arr_version/.*/} -ge 4 ] && local striptracks_return=0
    ;;
    qualitylanguage)
      # Language option in Quality Profile
      [ "${striptracks_type,,}" = "radarr" ] && [ ${striptracks_arr_version/.*/} -ge 3 ] && local striptracks_return=0
    ;;
    *)  # Unknown feature
      local striptracks_message="Error|Unknown feature $1 in ${striptracks_type^}"
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    ;;
  esac
  [ $striptracks_debug -ge 1 ] && echo "Debug|Feature $1 is $([ $striptracks_return -eq 1 ] && echo "not ")compatible with ${striptracks_type^} v${striptracks_arr_version}" | log
  return $striptracks_return
}
# Get media management configuration
function get_media_config {
  local url="$striptracks_api_url/config/mediamanagement"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting ${striptracks_type^} configuration. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.id?')" != "null" ] && [ "$(echo $striptracks_result | jq -crM '.id?')" != "" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Update file metadata in Radarr/Sonarr
function set_video_info {
  local url="$striptracks_api_url/$striptracks_video_api/$striptracks_video_id"
  local data="$(echo $striptracks_videoinfo | jq -crM .monitored="$striptracks_videomonitored")"
  local i=0
  for ((i=1; i <= 5; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Updating monitored to '$striptracks_videomonitored'. Calling ${striptracks_type^} API using PUT and URL '$url' with data $data" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      -X PUT "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "Debug|API returned ${#striptracks_result} bytes." | log
    [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      echo "Warn|Database is locked; system is likely overloaded. Sleeping 1 minute." | log
      sleep 60
    fi
  done
  if [ $striptracks_curlret -eq 0 -a "${#striptracks_result}" != 0 ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Handle :org language code
function process_org_code {
  local striptracks_track_type="$1" # 'audio' or 'subtitles'
  local striptracks_keep_var="$2"  # Variable name, e.g., striptracks_audiokeep or striptracks_subskeep

  if [[ "${!striptracks_keep_var}" =~ :org ]]; then
    # Check compatibility
    if [ "${striptracks_type,,}" = "batch" ]; then
      local striptracks_message="Warn|${striptracks_track_type^} argument contains ':org' code, but this is undefined for Batch mode! Unexpected behavior may result."
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    elif ! check_compat originallanguage; then
      local striptracks_message="Warn|${striptracks_track_type^} argument contains ':org' code, but this is undefined and not compatible with this mode/version! Unexpected behavior may result."
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    fi

    # Log debug message if applicable
    [ "$striptracks_debug" -ge 1 ] && echo "Debug|${striptracks_track_type^} argument ':org' specified. Changing '${!striptracks_keep_var}' to '${!striptracks_keep_var//:org/${striptracks_originalLangCode}}'" | log

    # Replace :org with the original language code
    declare -g "$striptracks_keep_var=${!striptracks_keep_var//:org/${striptracks_originalLangCode}}"
  fi
}
# Exit program
function end_script {
  # Cool bash feature
  striptracks_message="Info|Completed in $((SECONDS/60))m $((SECONDS%60))s"
  echo "$striptracks_message" | log
  [ "$1" != "" ] && striptracks_exitstatus=$1
  [ $striptracks_debug -ge 1 ] && echo "Debug|Exit code ${striptracks_exitstatus:-0}" | log
  exit ${striptracks_exitstatus:-0}
}
### End Functions

# Check that log path exists
if [ ! -d "$(dirname $striptracks_log)" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Log file path does not exist: '$(dirname $striptracks_log)'. Using log file in current directory."
  striptracks_log=./striptracks.txt
fi

# Check that the log file exists
if [ ! -f "$striptracks_log" ]; then
  echo "Info|Creating a new log file: $striptracks_log"
  touch "$striptracks_log"
fi

# Check that the log file is writable
if [ ! -w "$striptracks_log" ]; then
  echo "Error|Log file '$striptracks_log' is not writable or does not exist." >&2
  striptracks_log=/dev/null
  striptracks_exitstatus=12
fi

# Check for required binaries
for striptracks_file in "/usr/bin/mkvmerge" "/usr/bin/mkvpropedit" "/usr/bin/jq"; do
  if [ ! -f "$striptracks_file" ]; then
    striptracks_message="Error|$striptracks_file is required by this script"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    end_script 4
  fi
done

# Log Debug state
if [ $striptracks_debug -ge 1 ]; then
  striptracks_message="Debug|Enabling debug logging level ${striptracks_debug}. Starting run for: $striptracks_title"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Log command line parameters
if [ -n "$striptracks_prelogmessagedebug" ]; then
  # striptracks_prelogmessagedebug is set above, before argument processing
  [ $striptracks_debug -ge 1 ] && echo "$striptracks_prelogmessagedebug" | log
fi

# Log STRIPTRACKS_ARGS usage
if [ -n "$striptracks_prelogmessage" ]; then
  # striptracks_prelogmessage is set above, before argument processing
  echo "$striptracks_prelogmessage" | log
  [ $striptracks_debug -ge 1 ] && echo "Debug|STRIPTRACKS_ARGS: ${STRIPTRACKS_ARGS}" | log
fi

# Log environment
[ $striptracks_debug -ge 2 ] && printenv | sort | sed 's/^/Debug|/' | log

# Check for invalid _eventtypes
if [[ "${!striptracks_eventtype}" =~ Grab|Rename|MovieAdded|MovieDelete|MovieFileDelete|SeriesAdd|SeriesDelete|EpisodeFileDelete|HealthIssue|ApplicationUpdate ]]; then
  striptracks_message="Error|${striptracks_type^} event ${!striptracks_eventtype} is not supported. Exiting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 20
fi

# Check for WSL environment
if [ -n "$WSL_DISTRO_NAME" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Running in virtual WSL $WSL_DISTRO_NAME distribution." | log
  # Adjust config file location to WSL default
  if [ ! -f "$striptracks_arr_config" ]; then
    striptracks_arr_config="/mnt/c/ProgramData/${striptracks_type^}/config.xml"
    [ $striptracks_debug -ge 1 ] && echo "Debug|Will try to use the default WSL configuration file '$striptracks_arr_config'" | log
  fi
fi

# Handle Test event
if [[ "${!striptracks_eventtype}" = "Test" ]]; then
  echo "Info|${striptracks_type^} event: ${!striptracks_eventtype}" | log
  striptracks_message="Info|Script was test executed successfully."
  echo "$striptracks_message" | log
  echo "$striptracks_message"
  end_script 0
fi

# First normal log entry (when there are no errors) (see issue #61)
# shellcheck disable=SC2046
striptracks_filesize=$(stat -c %s "${striptracks_video}" | numfmt --to iec --format "%.3f")
striptracks_message="Info|${striptracks_type^} event: ${!striptracks_eventtype}, Video: $striptracks_video, Size: $striptracks_filesize"
echo "$striptracks_message" | log

# Log Batch mode
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Switching to batch mode. Input filename: ${striptracks_video}" | log
fi

# Check for config file
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Not using config file in batch mode." | log
elif [ -f "$striptracks_arr_config" ]; then
  # Read *arr config.xml
  [ $striptracks_debug -ge 1 ] && echo "Debug|Reading from ${striptracks_type^} config file '$striptracks_arr_config'" | log
  while read_xml; do
    [[ $striptracks_xml_entity = "Port" ]] && striptracks_port=$striptracks_xml_content
    [[ $striptracks_xml_entity = "UrlBase" ]] && striptracks_urlbase=$striptracks_xml_content
    [[ $striptracks_xml_entity = "BindAddress" ]] && striptracks_bindaddress=$striptracks_xml_content
    [[ $striptracks_xml_entity = "ApiKey" ]] && striptracks_apikey=$striptracks_xml_content
  done < $striptracks_arr_config

  # Allow use of environment variables from https://github.com/Sonarr/Sonarr/pull/6746
  striptracks_port_var="${striptracks_type^^}__SERVER__PORT"
  [ -n "${!striptracks_port_var}" ] && striptracks_port="${!striptracks_port_var}"
  striptracks_urlbase_var="${striptracks_type^^}__SERVER__URLBASE"
  [ -n "${!striptracks_urlbase_var}" ] && striptracks_urlbase="${!striptracks_urlbase_var}"
  striptracks_bindaddress_var="${striptracks_type^^}__SERVER__BINDADDRESS"
  [ -n "${!striptracks_bindaddress_var}" ] && striptracks_bindaddress="${!striptracks_bindaddress_var}"
  striptracks_apikey_var="${striptracks_type^^}__AUTH__APIKEY"
  [ -n "${!striptracks_apikey_var}" ] && striptracks_apikey="${!striptracks_apikey_var}"

  # Check for WSL environment and adjust bindaddress if not otherwise specified
  if [ -n "$WSL_DISTRO_NAME" -a "$striptracks_bindaddress" = "*" ]; then
    striptracks_bindaddress=$(ip route show | grep -i default | awk '{ print $3}')
  fi

  # Check for localhost
  [[ $striptracks_bindaddress = "*" ]] && striptracks_bindaddress=localhost

  # Strip leading and trailing forward slashes from URL base (see issue #66)
  striptracks_urlbase="$(echo "$striptracks_urlbase" | sed -re 's/^\/+//; s/\/+$//')"
  
  # Build URL to Radarr/Sonarr API (see issue #57)
  striptracks_api_url="http://$striptracks_bindaddress:$striptracks_port${striptracks_urlbase:+/$striptracks_urlbase}/api/v3"

  # Check Radarr/Sonarr version
  get_version
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    # curl errored out. API calls are really broken at this point.
    striptracks_message="Error|[$striptracks_return] Unable to get ${striptracks_type^} version information. It is not safe to continue."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    end_script 17
  }
  striptracks_arr_version="$(echo $striptracks_result | jq -crM .version)"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Detected ${striptracks_type^} version $striptracks_arr_version" | log

  # Requires API v3
  if ! check_compat apiv3; then
    # Radarr/Sonarr version 3 required
    striptracks_message="Error|This script does not support ${striptracks_type^} version ${striptracks_arr_version}. Please upgrade."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    end_script 8
  fi
else
  # No config file means we can't call the API.  Best effort at this point.
  striptracks_message="Warn|Unable to locate ${striptracks_type^} config file: '$striptracks_arr_config'"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Check if video file variable is blank
if [ -z "$striptracks_video" ]; then
  striptracks_message="Error|No video file found! radarr_moviefile_path or sonarr_episodefile_path environment variable missing and -f option not specified on command line."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage 
  end_script 1
fi

# Check if source video exists
if [ ! -f "$striptracks_video" ]; then
  striptracks_message="Error|Input video file not found: \"$striptracks_video\""
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 5
fi

# Create temporary filename
striptracks_basename="$(basename -- "${striptracks_video}")"
striptracks_fileroot="${striptracks_basename%.*}"
export striptracks_tempvideo="$(dirname -- "${striptracks_video}")/$(mktemp -u -- "${striptracks_fileroot:0:5}.tmp.XXXXXX")"
[ $striptracks_debug -ge 1 ] && echo "Debug|Using temporary file \"$striptracks_tempvideo\"" | log

#### Prep work. Includes detect languages configured in Radarr/Sonarr, quality of video, etc.
# Bypass if using batch mode
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Cannot detect languages in batch mode." | log
# Check for URL
elif [ -n "$striptracks_api_url" ]; then
  # Get list of all language IDs
  if get_language_codes; then
    striptracks_lang_codes="$striptracks_result"

    # Get video profile
    if get_video_info; then
      striptracks_videoinfo="$striptracks_result"
      striptracks_videomonitored="$(echo "$striptracks_videoinfo" | jq -crM ".monitored")"
      # This is not strictly necessary as this is normally set in the environment. However, this is needed for testing scripts and it doesn't hurt to use the data returned by the API call.
      striptracks_videofile_id="$(echo $striptracks_videoinfo | jq -crM .${striptracks_json_quality_root}.id)"

      # Get video file info. Needed to save the original quality, release group, and custom formats
      if get_videofile_info; then
        striptracks_videofile_info="$striptracks_result"

        # Get quality profile info
        if get_profiles quality; then
          striptracks_qualityProfiles="$striptracks_result"

          # Save original metadata
          striptracks_original_metadata="$(echo $striptracks_videofile_info | jq -crM '{quality, releaseGroup}')"
          [ $striptracks_debug -ge 1 ] && echo "Debug|Found video file quality '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)' and release group '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'" | log

          # Get language name(s) from quality profile used by video
          striptracks_profileId="$(echo $striptracks_videoinfo | jq -crM ${striptracks_video_rootNode}.qualityProfileId)"
          striptracks_profileName="$(echo $striptracks_qualityProfiles | jq -crM ".[] | select(.id == $striptracks_profileId).name")"
          striptracks_profileLanguages="$(echo $striptracks_qualityProfiles | jq -cM "[.[] | select(.id == $striptracks_profileId) | .language]")"
          striptracks_languageSource="quality profile"
          [ $striptracks_debug -ge 1 ] && echo "Debug|Found quality profile '${striptracks_profileName} (${striptracks_profileId})'$(check_compat qualitylanguage && echo " with language '$(echo $striptracks_profileLanguages | jq -crM '[.[] | "\(.name) (\(.id | tostring))"] | join(",")')'")" | log

          # Query custom formats if returned language from quality profile is null or -1 (Any)
          if [ -z "$striptracks_profileLanguages" -o "$striptracks_profileLanguages" = "[null]" -o "$(echo $striptracks_profileLanguages | jq -crM '.[].id')" = "-1" ] && check_compat customformat; then
            [ $striptracks_debug -ge 1 -a "$(echo $striptracks_profileLanguages | jq -crM '.[].id')" = "-1" ] && echo "Debug|Language selection of 'Any' in quality profile. Deferring to Custom Format language selection if it exists." | log
            # Get list of Custom Formats, and hopefully languages
            get_custom_formats
            striptracks_customFormats="$striptracks_result"
            [ $striptracks_debug -ge 1 ] && echo "Debug|Processing custom format(s) '$(echo "$striptracks_customFormats" | jq -crM '[.[] | select(.specifications[].implementation == "LanguageSpecification") | .name] | unique | join(",")')'" | log

            # Pick our languages by combining data from quality profile and custom format configuration.
            # I'm open to suggestions if there's a better way to get this list or selected languages.
            # Did I mention that JQ is crazy hard?
            striptracks_qcf_langcodes=$(echo "$striptracks_qualityProfiles $striptracks_customFormats" | jq -s -crM --argjson ProfileId $striptracks_profileId '
              [
                # This combines the custom formats [1] with the quality profiles [0], iterating over custom formats that
                # specify languages and evaluating the scoring from the selected quality profile.
                (
                  .[1] | .[] |
                  {id, specs: [.specifications[] | select(.implementation == "LanguageSpecification") | {langCode: .fields[] | select(.name == "value").value, negate, except: ((.fields[] | select(.name == "exceptLanguage").value) // false)}]}
                ) as $CustomFormat |
                .[0] | .[] |
                select(.id == $ProfileId) | .formatItems[] | select(.format == $CustomFormat.id) |
                {format, name, score, specs: $CustomFormat.specs}
              ] |
              [
                # Only count languages with positive scores plus languages with negative scores that are negated, and
                # languages with negative scores that use Except
                .[] |
                (select(.score > 0) | .specs[] | select(.negate == false and .except == false)),
                (select(.score < 0) | .specs[] | select(.negate == true and .except == false)),
                (select(.score < 0) | .specs[] | select(.negate == false and .except == true)) |
                .langCode
              ] |
              unique | join(",")
            ')
            [ $striptracks_debug -ge 2 ] && echo "Debug|Custom format language code(s) '$striptracks_qcf_langcodes' were selected based on quality profile scores." | log

            if [ -n "$striptracks_qcf_langcodes" ]; then
              # Convert the language codes into language code/name pairs
              striptracks_profileLanguages="$(echo $striptracks_lang_codes | jq -crM "map(select(.id | inside($striptracks_qcf_langcodes)) | {id, name})")"
              striptracks_languageSource="custom format"
              [ $striptracks_debug -ge 1 ] && echo "Debug|Found custom format language(s) '$(echo $striptracks_profileLanguages | jq -crM '[.[] | "\(.name) (\(.id | tostring))"] | join(",")')'" | log
            else
              [ $striptracks_debug -ge 1 ] && echo "Debug|None of the applied custom formats have language conditions with usable scores." | log
            fi
          fi

          # Check if the languageprofile API is supported (only in legacy Sonarr; but it was *way* better than Custom Formats <sigh>)
          if [ -z "$striptracks_profileLanguages" -o "$striptracks_profileLanguages" = "[null]" ] && check_compat languageprofile; then
            [ $striptracks_debug -ge 1 ] && echo "Debug|No language found in quality profile or in custom formats. This is normal in legacy versions of Sonarr." | log
            if get_profiles language; then
              striptracks_languageProfiles="$striptracks_result"

              # Get language name(s) from language profile used by video
              striptracks_profileId="$(echo $striptracks_videoinfo | jq -crM .series.languageProfileId)"
              striptracks_profileName="$(echo $striptracks_languageProfiles | jq -crM ".[] | select(.id == $striptracks_profileId).name")"
              striptracks_profileLanguages="$(echo $striptracks_languageProfiles | jq -cM "[.[] | select(.id == $striptracks_profileId) | .languages[] | select(.allowed).language]")"
              striptracks_languageSource="language profile"
              [ $striptracks_debug -ge 1 ] && echo "Debug|Found language profile '(${striptracks_profileId}) ${striptracks_profileName}' with language(s) '$(echo $striptracks_profileLanguages | jq -crM '[.[].name] | join(",")')'" | log
            else
              # languageProfile API failed
              striptracks_message="Warn|The 'languageprofile' API returned an error."
              echo "$striptracks_message" | log
              echo "$striptracks_message" >&2
              striptracks_exitstatus=17
            fi
          fi

          # Check if after all of the above we still couldn't get any languages
          if [ -z "$striptracks_profileLanguages" -o "$striptracks_profileLanguages" = "[null]" ]; then
            striptracks_message="Warn|No languages found in any profile or custom format. Unable to use automatic language detection."
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
            striptracks_exitstatus=20
          else
            # Final determination of configured languages in profiles or custom formats
            striptracks_profileLangNames="$(echo $striptracks_profileLanguages | jq -crM '[.[].name]')"
            [ $striptracks_debug -ge 1 ] && echo "Debug|Determined ${striptracks_type^} configured language(s) of '$(echo $striptracks_profileLanguages | jq -crM '[.[] | "\(.name) (\(.id | tostring))"] | join(",")')' from $striptracks_languageSource" | log
          fi
          
          # Get originalLanguage of video
          if check_compat originallanguage; then
            striptracks_originalLangName="$(echo $striptracks_videoinfo | jq -crM ${striptracks_video_rootNode}.originalLanguage.name)"

            # shellcheck disable=SC2090
            striptracks_originalLangCode="$(echo $striptracks_isocodemap | jq -jcM ".languages[] | select(.language.name == \"$striptracks_originalLangName\") | .language | \":\(.\"iso639-2\"[])\"")"
            [ $striptracks_debug -ge 1 ] && echo "Debug|Found original video language of '$striptracks_originalLangName ($striptracks_originalLangCode)' from $striptracks_video_type '$striptracks_rescan_id'" | log
          fi

          # Map language names to ISO code(s) used by mkvmerge
          unset striptracks_profileLangCodes
          for striptracks_templang in $(echo $striptracks_profileLangNames | jq -crM '.[]'); do
            # Convert 'Original' language selection to specific video language
            if [ "$striptracks_templang" = "Original" ]; then
              striptracks_templang="$striptracks_originalLangName"
            fi
            # shellcheck disable=SC2090
            striptracks_profileLangCodes+="$(echo $striptracks_isocodemap | jq -jcM ".languages[] | select(.language.name == \"$striptracks_templang\") | .language | \":\(.\"iso639-2\"[])\"")"
          done
          [ $striptracks_debug -ge 1 ] && echo "Debug|Mapped $striptracks_languageSource language(s) '$(echo $striptracks_profileLangNames | jq -crM "join(\",\")")' to ISO639-2 code list '$striptracks_profileLangCodes'" | log
        else
          # Get qualityprofile API failed
          striptracks_message="Warn|Unable to retrieve quality profiles from ${striptracks_type^} API"
          echo "$striptracks_message" | log
          echo "$striptracks_message" >&2
          striptracks_exitstatus=17
        fi
      else
        # No '.path' in returned JSON
        striptracks_message="Warn|The '$striptracks_videofile_api' API with id $striptracks_videofile_id returned no path."
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        striptracks_exitstatus=20
      fi
    else
      # 'hasFile' is False in returned JSON.
      striptracks_message="Warn|Could not find a video file for $striptracks_video_api id '$striptracks_video_id'"
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      striptracks_exitstatus=17
    fi
  else
    # Get language codes API failed
    striptracks_message="Warn|Unable to retrieve language codes from 'language' API (curl error or returned a null name)."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=17
  fi
  # Check if Radarr/Sonarr are configured to unmonitor deleted videos
  get_media_config
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    # No '.id' in returned JSON
    striptracks_message="Warn|The Media Management Config API returned no id."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=17
  }
  if [ "$(echo "$striptracks_result" | jq -crM ".autoUnmonitorPreviouslyDownloaded${striptracks_video_api^}s")" = "true" ]; then
    striptracks_message="Warn|Will compensate for ${striptracks_type^} configuration to unmonitor deleted ${striptracks_video_api}s."
    echo "$striptracks_message" | log
  fi
else
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  striptracks_exitstatus=20
fi

# Special handling for ':org' code from command line.
process_org_code "audio" "striptracks_audiokeep"
process_org_code "subtitles" "striptracks_subskeep"

# Final assignment of audio and subtitles selection
## Guard clause
if [ -z "$striptracks_audiokeep" -a -z "$striptracks_profileLangCodes" ]; then
  striptracks_message="Error|No audio languages specified or detected!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  end_script 2
fi
## Allows command line argument to override detected languages
if [ -z "$striptracks_audiokeep" -a -n "$striptracks_profileLangCodes" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|No command line audio languages specified. Using code list '$striptracks_profileLangCodes'" | log
  striptracks_audiokeep="$striptracks_profileLangCodes"
else
  [ $striptracks_debug -ge 1 ] && echo "Debug|Using command line audio languages '$striptracks_audiokeep'" | log
fi

## Log configuration that removes all subtitles
if [ -z "$striptracks_subskeep" -a -z "$striptracks_profileLangCodes" ]; then
  striptracks_message="Info|No subtitles languages specified or detected. Removing all subtitles found."
  echo "$striptracks_message" | log
  striptracks_subskeep="null"
fi
## Allows command line argument to override detected languages
if [ -z "$striptracks_subskeep" -a -n "$striptracks_profileLangCodes" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|No command line subtitle languages specified. Using code list '$striptracks_profileLangCodes'" | log
  striptracks_subskeep="$striptracks_profileLangCodes"
else
  [ $striptracks_debug -ge 1 ] && echo "Debug|Using command line subtitle languages '$striptracks_subskeep'" | log
fi

# Display what we're doing
striptracks_message="Info|Keeping audio tracks with codes '$(echo $striptracks_audiokeep | sed -e 's/^://; s/:/,/g')' and subtitle tracks with codes '$(echo $striptracks_subskeep | sed -e 's/^://; s/:/,/g')'"
echo "$striptracks_message" | log

#### BEGIN MAIN
# Read in the output of mkvmerge info extraction
# Populates the striptracks_json variable
get_mediainfo "$striptracks_video"

# Process JSON data from MKVmerge; track selection logic
striptracks_json_processed=$(echo "$striptracks_json" | jq -jcM --arg AudioKeep "$striptracks_audiokeep" \
--arg SubsKeep "$striptracks_subskeep" '
# Parse input string into JSON language rules function
def parse_language_codes(codes):
  # Supports f, d, and number modifiers (see issues #82 and #86)
  # -1 default value in language key means to keep unlimited tracks
  # NOTE: Logic can result in duplicate keys, but jq just uses the last defined key
  codes | split(":")[1:] | map(split("+") | {lang: .[0], mods: .[1]}) |
  {languages: map(
      # Select tracks with no modifiers or only numeric modifiers
      (select(.mods == null) | {(.lang): -1}),
      (select(.mods | test("^[0-9]+$")?) | {(.lang): .mods | tonumber})
    ) | add,
    forced_languages: map(
      # Select tracks with f modifier
      select(.mods | contains("f")?) | {(.lang): ((.mods | scan("[0-9]+") | tonumber) // -1)}
    ) | add,
    default_languages: map(
      # Select tracks with d modifier
      select(.mods | contains("d")?) | {(.lang): ((.mods | scan("[0-9]+") | tonumber) // -1)}
    ) | add
  };

# Language rules for audio and subtitles, adding required audio tracks (see issue #54)
(parse_language_codes($AudioKeep) | .languages += {"mis":-1,"zxx":-1}) as $AudioRules |
parse_language_codes($SubsKeep) as $SubsRules |

# Log chapter information
if (.chapters[0].num_entries) then
  .striptracks_log = "Info|Chapters: \(.chapters[].num_entries)"
else . end |

# Process tracks
reduce .tracks[] as $track (
  # Create object to hold tracks and counters for each reduce iteration
  # This is what will be output at the end of the reduce loop
  {"tracks": [], "counters": {"audio": {"normal": {}, "forced": {}, "default": {}}, "subtitles": {"normal": {}, "forced": {}, "default": {}}}};

  # Set track language to "und" if null or empty
  # NOTE: The // operator cannot be used here because it checks for null or empty values, not blank strings
  (if ($track.properties.language == "" or $track.properties.language == null) then "und" else $track.properties.language end) as $track_lang |

  # Initialize counters for each track type and language
  (.counters[$track.type].normal[$track_lang] //= 0) |
  if $track.properties.forced_track then (.counters[$track.type].forced[$track_lang] //= 0) else . end |
  if $track.properties.default_track then (.counters[$track.type].default[$track_lang] //= 0) else . end |
  .counters[$track.type] as $track_counters |
  
  # Add tracks one at a time to output object above
  .tracks += [
    $track |
    .striptracks_debug_log = "Debug|Parsing track ID:\(.id) Type:\(.type) Name:\(.properties.track_name) Lang:\($track_lang) Codec:\(.codec) Default:\(.properties.default_track) Forced:\(.properties.forced_track)" |
    # Use track language evaluation above
    .properties.language = $track_lang |

    # Determine keep logic based on type and rules
    if .type == "video" then
      .striptracks_keep = true
    elif .type == "audio" or .type == "subtitles" then
      .striptracks_log = "\(.id): \($track_lang) (\(.codec))\(if .properties.track_name then " \"" + .properties.track_name + "\"" else "" end)" |
      # Same logic for both audio and subtitles
      (if .type == "audio" then $AudioRules else $SubsRules end) as $currentRules |
      if ($currentRules.languages["any"] == -1 or ($track_counters.normal | add) < $currentRules.languages["any"] or
          $currentRules.languages[$track_lang] == -1 or $track_counters.normal[$track_lang] < $currentRules.languages[$track_lang]) then
        .striptracks_keep = true
      elif (.properties.forced_track and
            ($currentRules.forced_languages["any"] == -1 or ($track_counters.forced | add) < $currentRules.forced_languages["any"] or
              $currentRules.forced_languages[$track_lang] == -1 or $track_counters.forced[$track_lang] < $currentRules.forced_languages[$track_lang])) then
        .striptracks_keep = true |
        .striptracks_rule = "forced"
      elif (.properties.default_track and
            ($currentRules.default_languages["any"] == -1 or ($track_counters.default | add) < $currentRules.default_languages["any"] or
              $currentRules.default_languages[$track_lang] == -1 or $track_counters.default[$track_lang] < $currentRules.default_languages[$track_lang])) then
        .striptracks_keep = true |
        .striptracks_rule = "default"
      else . end |
      if .striptracks_keep then
        .striptracks_log = "Info|Keeping \(if .striptracks_rule then .striptracks_rule + " " else "" end)\(.type) track " + .striptracks_log
      else
        .striptracks_keep = false
      end
    else . end
  ] | 
  
  # Increment counters for each track type and language
  .counters[$track.type].normal[$track_lang] +=
    if .tracks[-1].striptracks_keep then
      1
    else 0 end | 
  .counters[$track.type].forced[$track_lang] +=
    if ($track.properties.forced_track and .tracks[-1].striptracks_keep) then
      1
    else 0 end |
  .counters[$track.type].default[$track_lang] +=
    if ($track.properties.default_track and .tracks[-1].striptracks_keep) then
      1
    else 0 end
) |

# Ensure at least one audio track is kept
if ((.tracks | map(select(.type == "audio")) | length == 1) and (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0)) then
  # If there is only one audio track and none are kept, keep the only audio track
  .tracks |= map(if .type == "audio" then
      .striptracks_log = "Warn|No audio tracks matched! Keeping only audio track " + .striptracks_log |
      .striptracks_keep = true
    else . end)
elif (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0) then
  # If no audio tracks are kept, first try to keep the default audio track
  .tracks |= map(if .type == "audio" and .properties.default_track then
      .striptracks_log = "Warn|No audio tracks matched! Keeping default audio track " + .striptracks_log |
      .striptracks_keep = true
    else . end) |
  # If still no audio tracks are kept, keep the first audio track
  if (.tracks | map(select(.type == "audio" and .striptracks_keep)) | length == 0) then
    (first(.tracks[] | select(.type == "audio"))) |= . +
    {striptracks_log: ("Warn|No audio tracks matched! Keeping first audio track " + .striptracks_log),
     striptracks_keep: true}
  else . end
else . end |

# Output simplified dataset
{ striptracks_log, tracks: .tracks | map({ id, type, language: .properties.language, forced: .properties.forced_track, default: .properties.default_track, striptracks_debug_log, striptracks_log, striptracks_keep }) }
')
[ $striptracks_debug -ge 1 ] && echo "Debug|Track processing returned ${#striptracks_json_processed} bytes." | log
[ $striptracks_debug -ge 2 ] && echo "Track processing returned: $(echo "$striptracks_json_processed" | jq)" | awk '{print "Debug|"$0}' | log

# Write messages to log
echo "$striptracks_json_processed" | jq -crM --argjson Debug $striptracks_debug '
# Join log messages into one line function
def log_removed_tracks($type):
  if (.tracks | map(select(.type == $type and .striptracks_keep == false)) | length > 0) then
    "Info|Removing \($type) tracks: " +
    (.tracks | map(select(.type == $type and .striptracks_keep == false) | .striptracks_log) | join(", "))
  else empty end;

# Log the chapters, if any
.striptracks_log // empty,

# Log debug messages
( .tracks[] | (if $Debug >= 1 then .striptracks_debug_log else empty end),

 # Log messages for kept tracks
 (select(.striptracks_keep) | .striptracks_log // empty)
),

# Log removed tracks
log_removed_tracks("audio"),
log_removed_tracks("subtitles"),

# Summary of kept tracks
"Info|Kept tracks: \(.tracks | map(select(.striptracks_keep)) | length) " +
"(audio: \(.tracks | map(select(.type == "audio" and .striptracks_keep)) | length), " +
"subtitles: \(.tracks | map(select(.type == "subtitles" and .striptracks_keep)) | length))"
' | log

# Check for no audio tracks
if [ "$(echo "$striptracks_json_processed" | jq -crM '.tracks|map(select(.type=="audio" and .striptracks_keep))')" = "[]" ]; then
  striptracks_message="Error|Unable to determine any audio tracks to keep. Exiting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 11
fi

# Map current track order
striptracks_order=$(echo "$striptracks_json_processed" | jq -jcM '.tracks | map(.id | "0:" + tostring) | join(",")')
[ $striptracks_debug -ge 1 ] && echo "Debug|Current mkvmerge track order: $striptracks_order" | log

# Prepare to reorder tracks if option is enabled (see issue #92)
if [ "$striptracks_reorder" = "true" ]; then
  striptracks_neworder=$(echo "$striptracks_json_processed" | jq -jcM --arg AudioKeep "$striptracks_audiokeep" \
--arg SubsKeep "$striptracks_subskeep" '
# Reorder tracks function
def order_tracks(tracks; rules; tracktype):
  rules | split(":")[1:] | map(split("+") | {lang: .[0], mods: .[1]}) | 
  reduce .[] as $rule (
    [];
    . as $orderedTracks |
    . += [tracks |
    map(. as $track | 
      select(.type == tracktype and .striptracks_keep and
        ($rule.lang | in({"any":0,($track.language):0})) and
        ($rule.mods == null or
          ($rule.mods | test("[fd]") | not) or
          ($rule.mods | contains("f") and $track.forced) or
          ($rule.mods | contains("d") and $track.default)
        )
      ) |
      .id as $id |
      # Remove track id from orderedTracks if it already exists
      if ([$id] | flatten | inside($orderedTracks | flatten)) then empty else $id end
    )]
  ) | flatten;

# Reorder audio and subtitles according to language code order
.tracks as $tracks |
order_tracks($tracks; $AudioKeep; "audio") as $audioOrder |
order_tracks($tracks; $SubsKeep; "subtitles") as $subsOrder |

# Output ordered track string compatible with the mkvmerge --track-order option
# Video tracks are always first, followed by audio tracks, then subtitles
# NOTE: Other track types are still preserved as mkvmerge will automatically place any missing tracks after those listed per https://mkvtoolnix.download/doc/mkvmerge.html#d4e544
$tracks | map(select(.type == "video") | .id) + $audioOrder + $subsOrder | map("0:" + tostring) | join(",")
')
  [ $striptracks_debug -ge 1 ] && echo "Debug|New mkvmerge track order: $striptracks_neworder" | log
  striptracks_message="Info|Reordering tracks using language code order."
  echo "$striptracks_message" | log
fi

# All tracks matched/no tracks removed (see issues #49 and #89)
if [ "$(echo "$striptracks_json" | jq -crM '.tracks|map(select(.type=="audio" or .type=="subtitles"))|length')" = "$(echo "$striptracks_json_processed" | jq -crM '.tracks|map(select((.type=="audio" or .type=="subtitles") and .striptracks_keep))|length')" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|No tracks will be removed from video \"$striptracks_video\"" | log
  # Check if already MKV
  if [[ $striptracks_video == *.mkv ]]; then
    # Check if reorder option is unset or if the order wouldn't change (see issue #92)
    if [ "$striptracks_reorder" != "true" -o "$striptracks_order" = "$striptracks_neworder" ]; then
      # Remuxing not performed
      striptracks_message="Info|No tracks would be removed from video$( [ "$striptracks_reorder" = "true" ] && echo " or reordered"). Setting Title only and exiting."
      echo "$striptracks_message" | log
      striptracks_mkvcommand="/usr/bin/mkvpropedit -q --edit info --set \"title=$striptracks_title\" \"$striptracks_video\""
      [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: $striptracks_mkvcommand" | log
      striptracks_result=$(eval $striptracks_mkvcommand)
      striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
        striptracks_message=$(echo -e "[$striptracks_return] Error when setting video title: \"$striptracks_tempvideo\"\nmkvpropedit returned: $striptracks_result" | awk '{print "Error|"$0}')
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        striptracks_exitstatus=13
      }
      end_script
    else
      # Reorder tracks anyway
      striptracks_message="Info|No tracks will be removed from video, but they can be reordered. Remuxing anyway."
      echo "$striptracks_message" | log
    fi
  else
    # Not MKV
    [ $striptracks_debug -ge 1 ] && echo "Debug|Source video is not MKV. Remuxing anyway." | log
  fi
fi

# Test for hardlinked file (see issue #85)
striptracks_refcount=$(stat -c %h "$striptracks_video")
[ $striptracks_debug -ge 1 ] && echo "Debug|Input file has a hard link count of $striptracks_refcount" | log
if [ "$striptracks_refcount" != "1" ]; then
  striptracks_message="Warn|Input video file is a hardlink and this will be broken by remuxing."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Build argument with kept audio tracks for MKVmerge
striptracks_audioarg=$(echo "$striptracks_json_processed" | jq -crM '.tracks | map(select(.type == "audio" and .striptracks_keep) | .id) | join(",")')
striptracks_audioarg="-a $striptracks_audioarg"

# Build argument with kept subtitles tracks for MKVmerge, or remove all subtitles
striptracks_subsarg=$(echo "$striptracks_json_processed" | jq -crM '.tracks | map(select(.type == "subtitles" and .striptracks_keep) | .id) | join(",")')
if [ ${#striptracks_subsarg} -ne 0 ]; then
  striptracks_subsarg="-s $striptracks_subsarg"
else
  striptracks_subsarg="-S"
fi

# Build argument for track reorder option for MKVmerge
if [ ${#striptracks_neworder} -ne 0 ]; then
  striptracks_neworder="--track-order $striptracks_neworder"
fi

# Execute MKVmerge (remux then rename, see issue #46)
striptracks_mkvcommand="nice /usr/bin/mkvmerge --title \"$striptracks_title\" -q -o \"$striptracks_tempvideo\" $striptracks_audioarg $striptracks_subsarg $striptracks_neworder \"$striptracks_video\""
[ $striptracks_debug -ge 1 ] && echo "Debug|Executing: $striptracks_mkvcommand" | log
striptracks_result=$(eval $striptracks_mkvcommand)
striptracks_return=$?
case $striptracks_return in
  1) striptracks_message=$(echo -e "[$striptracks_return] Warning when remuxing video: \"$striptracks_video\"\nmkvmerge returned: $striptracks_result" | awk '{print "Warn|"$0}')
    echo "$striptracks_message" | log
  ;;
  2) striptracks_message=$(echo -e "[$striptracks_return] Error when remuxing video: \"$striptracks_video\"\nmkvmerge returned: $striptracks_result" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    end_script 13
  ;;
esac

# Check for non-empty file
if [ ! -s "$striptracks_tempvideo" ]; then
  striptracks_message="Error|Unable to locate or invalid remuxed file: \"$striptracks_tempvideo\".  Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 10
fi

# Checking that we're running as root
if [ "$(id -u)" -eq 0 ]; then
  # Set owner
  [ $striptracks_debug -ge 1 ] && echo "Debug|Changing owner of file \"$striptracks_tempvideo\"" | log
  striptracks_result=$(chown --reference="$striptracks_video" "$striptracks_tempvideo")
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    striptracks_message=$(echo -e "[$striptracks_return] Error when changing owner of file: \"$striptracks_tempvideo\"\nchown returned: $striptracks_result" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=15
  }
else
  # Unable to change owner when not running as root
  [ $striptracks_debug -ge 1 ] && echo "Debug|Unable to change owner of file when running as user '$(id -un)'" | log
fi
# Set permissions
striptracks_result=$(chmod --reference="$striptracks_video" "$striptracks_tempvideo")
striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
  striptracks_message=$(echo -e "[$striptracks_return] Error when changing permissions of file: \"$striptracks_tempvideo\"\nchmod returned: $striptracks_result" | awk '{print "Error|"$0}')
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  striptracks_exitstatus=15
}

# Just delete the original video if running in batch mode
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Deleting: \"$striptracks_video\"" | log
  striptracks_result=$(rm "$striptracks_video")
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    striptracks_message=$(echo -e "[$striptracks_return] Error when deleting video: \"$striptracks_video\"\nrm returned: $striptracks_result" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=16
  }
else
  # Call Radarr/Sonarr to delete the original video, or recycle if configured.
  delete_video $striptracks_videofile_id
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    striptracks_message="Error|[$striptracks_return] ${striptracks_type^} error when deleting the original video: \"$striptracks_video\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=17
  }
fi

# Another check for the temporary file, to make sure it wasn't deleted (see issue #65)
if [ ! -f "$striptracks_tempvideo" ]; then
  striptracks_message="Error|${striptracks_type^} deleted the temporary remuxed file: \"$striptracks_tempvideo\".  Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 10
fi

# Rename the temporary video file to MKV
[ $striptracks_debug -ge 1 ] && echo "Debug|Renaming \"$striptracks_tempvideo\" to \"$striptracks_newvideo\"" | log
striptracks_result=$(mv -f "$striptracks_tempvideo" "$striptracks_newvideo")
striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
  striptracks_message=$(echo -e "[$striptracks_return] Unable to rename temp video: \"$striptracks_tempvideo\" to: \"$striptracks_newvideo\".  Halting.\nmv returned: $striptracks_result" | awk '{print "Error|"$0}')
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 6
}

# Get file size (see issue #61)
# shellcheck disable=SC2046
striptracks_filesize=$(stat -c %s "${striptracks_newvideo}" | numfmt --to iec --format "%.3f")
striptracks_message="Info|New size: $striptracks_filesize"
echo "$striptracks_message" | log
#### END MAIN

#### Call Radarr/Sonarr API to RescanMovie/RescanSeries
# Check for URL
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Not calling API while in batch mode." | log
elif [ -n "$striptracks_api_url" ]; then
  # Check for video IDs
  if [ "$striptracks_video_id" -a "$striptracks_videofile_id" ]; then
    ##### Leaving this here (and all supporting functions and variables) in case the single file import job problem can be resolved.
    ##### See GitHub Issue #50.  Importing directly is a much better way than rescanning.
    # Scan for files to import into Radarr/Sonarr
    # if get_import_info; then
      # # Build JSON data
      # [ $striptracks_debug -ge 1 ] && echo "Debug|Building JSON data to import" | log
      # striptracks_json=$(echo $striptracks_result | jq -jcM "
        # map(
          # select(.path == \"$striptracks_newvideo\") |
          # {path, folderName, \"${striptracks_video_type}Id\":.${striptracks_video_type}.id,${striptracks_sonarr_json} quality, $striptracks_language_node}
        # )
      # ")
      
      # # Import new video into Radarr/Sonarr
      # import_video
      # striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
        # striptracks_message="Error|[$striptracks_return] ${striptracks_type^} error when importing new video!"
        # echo "$striptracks_message" | log
        # echo "$striptracks_message" >&2
        # striptracks_exitstatus=17
      # }
      # striptracks_jobid="$(echo $striptracks_result | jq -crM .id)"
      # Check status of job
    # Scan the disk for the new movie file
    if rescan; then
      # Give it a beat
      sleep 1
      # Check that the Rescan completed
      check_job
      striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
        case $striptracks_return in
          1) striptracks_message="Info|${striptracks_type^} job ID $striptracks_jobid is queued. Trusting this will complete and exiting."
             striptracks_exitstatus=0
          ;;
          2) striptracks_message="Warn|${striptracks_type^} job ID $striptracks_jobid failed."
             striptracks_exitstatus=17
          ;;
          3) striptracks_message="Warn|Script timed out waiting on ${striptracks_type^} job ID $striptracks_jobid. Last status was: $(echo $striptracks_result | jq -crM .status)"
             striptracks_exitstatus=18
          ;;
         10) striptracks_message="Error|${striptracks_type^} job ID $striptracks_jobid returned a curl error."
             striptracks_exitstatus=17
         ;;
        esac
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        end_script
      }

      # Get new video file id
      if get_video_info; then
        striptracks_videoinfo="$striptracks_result"
        striptracks_videofile_id="$(echo $striptracks_videoinfo | jq -crM .${striptracks_json_quality_root}.id)"
        [ $striptracks_debug -ge 1 ] && echo "Debug|Using new video file id '$striptracks_videofile_id'" | log

        # Check if video monitored status changed after the delete/import (see issues #87 and #90)
        if [ "$(echo "$striptracks_videoinfo" | jq -crM ".monitored")" != "$striptracks_videomonitored" ]; then
          striptracks_message="Warn|Video monitor status changed after deleting the original.  Setting it back to '$striptracks_videomonitored'"
          echo "$striptracks_message" | log
          # Set video monitor state
          set_video_info
        fi

        # Get new video file info
        if get_videofile_info; then
          striptracks_videofile_info="$striptracks_result"
          # Check that the metadata didn't get lost in the rescan.
          if [ "$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)" != "$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)" -o "$(echo $striptracks_videofile_info | jq -crM '.releaseGroup | select(. != null)')" != "$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')" ]; then
            # Put back the missing metadata
            set_metadata
            # Check that the returned result shows the updates
            if [ "$(echo $striptracks_result | jq -crM .[].quality.quality.name)" = "$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)" ]; then
              # Updated successfully
              echo "Info|Successfully updated quality to '$(echo $striptracks_result | jq -crM .[].quality.quality.name)' and release group to '$(echo $striptracks_result | jq -crM '.[].releaseGroup | select(. != null)')'" | log
            else
              striptracks_message="Warn|Unable to update ${striptracks_type^} $striptracks_video_api '$striptracks_title' to quality '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)' or release group to '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'"
              echo "$striptracks_message" | log
              echo "$striptracks_message" >&2
              striptracks_exitstatus=17
            fi
          else
            # The metadata was already set correctly
            [ $striptracks_debug -ge 1 ] && echo "Debug|Metadata quality '$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)' and release group '$(echo $striptracks_videofile_info | jq -crM '.releaseGroup | select(. != null)')' remained unchanged." | log
          fi

          # Check the languages returned
          # If we stripped out other languages, remove them
          # Only works in Radarr and Sonarr v4 (no per-episode edit function in Sonarr v3)
          [ $striptracks_debug -ge 1 ] && echo "Debug|Getting languages in new video file \"$striptracks_newvideo\"" | log
          get_mediainfo "$striptracks_newvideo"

          # Build array of full name languages
          striptracks_newvideo_langcodes="$(echo $striptracks_json | jq -crM '.tracks[] | select(.type == "audio") | .properties.language')"
          unset striptracks_newvideo_languages
          for i in $striptracks_newvideo_langcodes; do
            # shellcheck disable=SC2090
            # Exclude Any, Original, and Unknown
            striptracks_newvideo_languages+="$(echo $striptracks_isocodemap | jq -crM ".languages[] | .language | select((.\"iso639-2\"[]) == \"$i\") | select(.name != \"Any\" and .name != \"Original\" and .name != \"Unknown\").name")"
          done
          if [ -n "$striptracks_newvideo_languages" ]; then
            # Covert to standard JSON
            striptracks_json_languages="$(echo $striptracks_lang_codes | jq -crM "map(select(.name | inside(\"$striptracks_newvideo_languages\")) | {id, name})")"
            
            # Check languages for Radarr and Sonarr v4
            # Sooooo glad I did it this way
            if [ "$(echo $striptracks_videofile_info | jq -crM .languages)" != "null" ]; then
              if [ "$(echo $striptracks_videofile_info | jq -crM .languages)" != "$striptracks_json_languages" ]; then
                if set_radarr_language; then
                  striptracks_exitstatus=0
                else
                  striptracks_message="Error|${striptracks_type^} error when updating video language(s)."
                  echo "$striptracks_message" | log
                  echo "$striptracks_message" >&2
                  striptracks_exitstatus=17
                fi
              else
                # The languages are already correct
                [ $striptracks_debug -ge 1 ] && echo "Debug|Language(s) '$(echo $striptracks_json_languages | jq -crM "[.[].name] | join(\",\")")' remained unchanged." | log
              fi
            # Check languages for Sonarr v3 and earlier
            elif [ "$(echo $striptracks_videofile_info | jq -crM .language)" != "null" ]; then
              if [ "$(echo $striptracks_videofile_info | jq -crM .language)" != "$(echo $striptracks_json_languages | jq -crM '.[0]')" ]; then
                if set_sonarr_language; then
                  striptracks_exitstatus=0
                else
                  striptracks_message="Error|${striptracks_type^} error when updating video language(s)."
                  echo "$striptracks_message" | log
                  echo "$striptracks_message" >&2
                  striptracks_exitstatus=17
                fi
              else
                # The languages are already correct
                [ $striptracks_debug -ge 1 ] && echo "Debug|Language '$(echo $striptracks_json_languages | jq -crM ".[0].name")' remained unchanged." | log
              fi
            else
              # Some unknown JSON formatting
              striptracks_message="Warn|The '$striptracks_videofile_api' API returned unknown JSON language node."
              echo "$striptracks_message" | log
              echo "$striptracks_message" >&2
              striptracks_exitstatus=20
            fi
          elif [ "$striptracks_newvideo_langcodes" = "und" ]; then
            # Only language detected is Unknown
            echo "Warn|The only audio language in the video file was 'Unknown (und)'. Not updating ${striptracks_type^} database." | log
          else
            # Video language not in striptracks_isocodemap
            striptracks_message="Warn|Video language code(s) '${striptracks_newvideo_langcodes//$'\n'/,}' not found in the ISO Codemap. Cannot evaluate."
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
            striptracks_exitstatus=20
          fi

          # Get list of videos that could be renamed (see issue #50)
          get_rename
          striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
            striptracks_message="Warn|[$striptracks_return] ${striptracks_type^} error when getting list of videos to rename."
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
            striptracks_exitstatus=17
          }
          # Check if new video is in list of files that can be renamed
          if [ -n "$striptracks_result" -a "$striptracks_result" != "[]" ]; then
            striptracks_renamedvideo="$(echo $striptracks_result | jq -crM ".[] | select(.${striptracks_json_quality_root}Id == $striptracks_videofile_id) | .newPath")"
            # Rename video if needed
            if [ -n "$striptracks_renamedvideo" ]; then
              rename_video
              striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
                striptracks_message="Error|[$striptracks_return] ${striptracks_type^} error when renaming \"$(basename "$striptracks_newvideo")\" to \"$(basename "$striptracks_renamedvideo")\""
                echo "$striptracks_message" | log
                echo "$striptracks_message" >&2
                striptracks_exitstatus=17
              }
            else
              # This file doesn't need to be
              [ $striptracks_debug -ge 1 ] && echo "Debug|This video file doesn't need to be renamed." | log
            fi
          else
            # Nothing to rename
            [ $striptracks_debug -ge 1 ] && echo "Debug|No video files need to be renamed." | log
          fi
        else
          # No '.path' in returned JSON
          striptracks_message="Warn|The '$striptracks_videofile_api' API with ${striptracks_video_api}File id $striptracks_videofile_id returned no path."
          echo "$striptracks_message" | log
          echo "$striptracks_message" >&2
          striptracks_exitstatus=17
        fi
      else
        # 'hasFile' is False in returned JSON
        striptracks_message="Warn|Could not find a video file for $striptracks_video_api id '$striptracks_video_id'"
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        striptracks_exitstatus=17
      fi
  # else
    # striptracks_message="Error|${striptracks_type^} error getting import file list in \"$striptracks_video_folder\" for $striptracks_video_type ID $striptracks_rescan_id. Cannot import remuxed video."
    # echo "$striptracks_message" | log
    # echo "$striptracks_message" >&2
    # striptracks_exitstatus=17
  # fi
    else
      # Error from rescan API
      striptracks_message="Error|The '$striptracks_rescan_api' API with ${striptracks_video_type}Id $striptracks_rescan_id failed."
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      striptracks_exitstatus=17
    fi
  else
    # No video ID means we can't call the API
    striptracks_message="Warn|Missing or empty environment variable: striptracks_video_id='$striptracks_video_id' or striptracks_videofile_id='$striptracks_videofile_id'. Cannot rescan for remuxed video."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=20
  fi
else
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  striptracks_exitstatus=20
fi

end_script
