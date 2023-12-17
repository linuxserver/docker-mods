#!/bin/bash

# Video remuxing script designed for use with Radarr and Sonarr
# Automatically strips out unwanted audio and subtitles streams, keeping only the desired languages.
#  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks
#  Dev/test: https://github.com/TheCaptain989/radarr-striptracks
#
# Inspired by Endoro's post 1/5/2014:
#  https://forum.videohelp.com/threads/343271-BULK-remove-non-English-tracks-from-MKV-container#post2292889
#
# Put a colon `:` in front of every language code.  Expects ISO639-2 codes

# NOTE: ShellCheck linter directives appear as comments

# Dependencies:
#  mkvmerge
#  mkvpropedit
#  awk
#  curl
#  jq
#  numfmt
#  stat
#  nice
#  basename
#  dirname
#  mktemp

# Exit codes:
#  0 - success; or test
#  1 - no video file specified on command line
#  2 - no audio language specified on command line
#  3 - no subtitles language specified on command line
#  4 - mkvmerge or mkvpropedit not found
#  5 - input video file not found
#  6 - unable to rename temp video to MKV
#  7 - unknown eventtype environment variable
#  8 - unsupported Radarr/Sonarr version (v2)
#  9 - mkvmerge get media info failed
# 10 - remuxing completed, but no output file found
# 11 - source video had no audio or subtitle tracks
# 12 - log file is not writable
# 13 - awk script exited abnormally
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

# Usage function
function usage {
  usage="
$striptracks_script   Version: $striptracks_ver
Video remuxing script that only keeps tracks with the specified languages.
Designed for use with Radarr and Sonarr, but may be used standalone in batch
mode.

Source: https://github.com/TheCaptain989/radarr-striptracks

Usage:
  $0 [{-a|--audio} <audio_languages> [{-s|--subs} <subtitle_languages>] [{-f|--file} <video_file>]] [{-l|--log} <log_file>] [{-d|--debug} [<level>]]

Options and Arguments:
  -a, --audio <audio_languages>    Audio languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   multiple codes may be concatenated.
  -s, --subs <subtitle_languages>  Subtitles languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   multiple codes may be concatenated.
  -f, --file <video_file>          If included, the script enters batch mode
                                   and converts the specified video file.
                                   WARNING: Do not use this argument when called
                                   from Radarr or Sonarr!
  -l, --log <log_file>             Log filename
                                   [default: /config/log/striptracks.txt]
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

Batch Mode:
  In batch mode the script acts as if it were not called from within Radarr
  or Sonarr.  It converts the file specified on the command line and ignores
  any environment variables that are normally expected.  The MKV embedded title
  attribute is set to the basename of the file minus the extension.

Examples:
  $striptracks_script -d 2                      # Enable debugging level 2, audio and
                                           # subtitles languages detected from
                                           # Radarr/Sonarr
  $striptracks_script -a :eng:und -s :eng       # keep English and Unknown audio and
                                           # English subtitles
  $striptracks_script -a :eng:org -s :eng       # keep English and Original* audio and
                                           # English subtitles
                                           # *Only supported in Radarr!
  $striptracks_script :eng \"\"                   # keep English audio and no subtitles
  $striptracks_script -d :eng:kor:jpn :eng:spa  # Enable debugging level 1, keeping
                                           # English, Korean, and Japanese
                                           # audio, and English and Spanish
                                           # subtitles
  $striptracks_script -f \"/movies/path/Finding Nemo (2003).mkv\" -a :eng:und -s :eng
                                           # Batch Mode
                                           # Keep English and Unknown audio and
                                           # English subtitles, converting video
                                           # specified
  $striptracks_script -a :any -s \"\"           # Keep all audio and no subtitles
"
  echo "$usage" >&2
}

# Process arguments
# Taken from Drew Strokes post 3/24/2015:
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
    --help ) # Display usage
      usage
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
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export striptracks_audiokeep="$2"
        shift 2
      else
        echo "Error|Invalid option: $1 requires an argument." >&2
        usage
        exit 2
      fi
    ;;
    -s|--subs ) # Subtitles languages to keep
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export striptracks_subskeep="$2"
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
  export striptracks_profile_type="quality"
  export striptracks_profile_jq=".qualityProfileId"
  # shellcheck disable=SC2154
  export striptracks_title="${radarr_movie_title:-UNKNOWN} (${radarr_movie_year:-UNKNOWN})"
  export striptracks_language_api="language"
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
  export striptracks_profile_type="language"
  export striptracks_profile_jq=".series.languageProfileId"
  # shellcheck disable=SC2154
  export striptracks_title="${sonarr_series_title:-UNKNOWN} $(numfmt --format "%02f" ${sonarr_episodefile_seasonnumber:-0})x$(numfmt --format "%02f" ${sonarr_episodefile_episodenumbers:-0}) - ${sonarr_episodefile_episodetitles:-UNKNOWN}"
  export striptracks_language_api="languageprofile"
  export striptracks_language_jq=".languages[] | select(.allowed).language"
  # export striptracks_language_node="language"
  # # Sonarr requires the episodeIds array
  # export striptracks_sonarr_json=" \"episodeIds\":[.episodes[].id],"
else
  # Called in an unexpected way
  echo -e "Error|Unknown or missing '*_eventtype' environment variable: ${striptracks_type}\nNot called from Radarr/Sonarr.\nTry using Batch Mode option: -f <file>"
  exit 7
fi
export striptracks_rescan_api="Rescan${striptracks_video_type^}"
export striptracks_eventtype="${striptracks_type,,}_eventtype"
export striptracks_newvideo="${striptracks_video%.*}.mkv"
# If this were defined directly in Radarr or Sonarr this would not be needed here
# shellcheck disable=SC2089
striptracks_isocodemap='{"languages":[{"language":{"name":"Any","iso639-2":["any"]}},{"language":{"name":"Arabic","iso639-2":["ara"]}},{"language":{"name":"Bengali","iso639-2":["ben"]}},{"language":{"name":"Bosnian","iso639-2":["bos"]}},{"language":{"name":"Bulgarian","iso639-2":["bul"]}},{"language":{"name":"Catalan","iso639-2":["cat"]}},{"language":{"name":"Chinese","iso639-2":["zho","chi"]}},{"language":{"name":"Croatian","iso639-2":["hrv"]}},{"language":{"name":"Czech","iso639-2":["ces","cze"]}},{"language":{"name":"Danish","iso639-2":["dan"]}},{"language":{"name":"Dutch","iso639-2":["nld","dut"]}},{"language":{"name":"English","iso639-2":["eng"]}},{"language":{"name":"Estonian","iso639-2":["est"]}},{"language":{"name":"Finnish","iso639-2":["fin"]}},{"language":{"name":"Flemish","iso639-2":["nld","dut"]}},{"language":{"name":"French","iso639-2":["fra","fre"]}},{"language":{"name":"German","iso639-2":["deu","ger"]}},{"language":{"name":"Greek","iso639-2":["ell","gre"]}},{"language":{"name":"Hebrew","iso639-2":["heb"]}},{"language":{"name":"Hindi","iso639-2":["hin"]}},{"language":{"name":"Hungarian","iso639-2":["hun"]}},{"language":{"name":"Icelandic","iso639-2":["isl","ice"]}},{"language":{"name":"Indonesian","iso639-2":["ind"]}},{"language":{"name":"Italian","iso639-2":["ita"]}},{"language":{"name":"Japanese","iso639-2":["jpn"]}},{"language":{"name":"Korean","iso639-2":["kor"]}},{"language":{"name":"Latvian","iso639-2":["lav"]}},{"language":{"name":"Lithuanian","iso639-2":["lit"]}},{"language":{"name":"Malayalam","iso639-2":["mal"]}},{"language":{"name":"Norwegian","iso639-2":["nno","nob","nor"]}},{"language":{"name":"Persian","iso639-2":["fas","per"]}},{"language":{"name":"Polish","iso639-2":["pol"]}},{"language":{"name":"Portuguese","iso639-2":["por"]}},{"language":{"name":"Portuguese (Brazil)","iso639-2":["por"]}},{"language":{"name":"Romanian","iso639-2":["rum","ron"]}},{"language":{"name":"Russian","iso639-2":["rus"]}},{"language":{"name":"Serbian","iso639-2":["srp"]}},{"language":{"name":"Slovak","iso639-2":["slk","slo"]}},{"language":{"name":"Spanish","iso639-2":["spa"]}},{"language":{"name":"Spanish (Latino)","iso639-2":["spa"]}},{"language":{"name":"Swedish","iso639-2":["swe"]}},{"language":{"name":"Tamil","iso639-2":["tam"]}},{"language":{"name":"Telugu","iso639-2":["tel"]}},{"language":{"name":"Thai","iso639-2":["tha"]}},{"language":{"name":"Turkish","iso639-2":["tur"]}},{"language":{"name":"Ukrainian","iso639-2":["ukr"]}},{"language":{"name":"Vietnamese","iso639-2":["vie"]}},{"language":{"name":"Unknown","iso639-2":["und"]}}]}'

### Functions

# Can still go over striptracks_maxlog if read line is too long
## Must include whole function in subshell for read to work!
function log {(
  while read -r
  do
    # shellcheck disable=2046
    echo $(date +"%Y-%-m-%-d %H:%M:%S.%1N")"|[$striptracks_pid]$REPLY" >>"$striptracks_log"
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
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.version?')" != "null" ]; then
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
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
    --get "$url" )
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
  for ((i=1; i <= 2; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Forcing rescan of $striptracks_video_type '$striptracks_rescan_id'. Calling ${striptracks_type^} API using POST and URL '$url' with data $data" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcrM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      [ $striptracks_debug -ge 1 ] && echo "Debug|Database is locked. Waiting 1 minute." | log
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
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
# Get language/quality profiles
function get_profiles {
  local url="$striptracks_api_url/${striptracks_profile_type}Profile"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of $striptracks_profile_type profiles. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  # This returns A LOT of data, and it is normally not needed
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
  local url="$striptracks_api_url/${striptracks_language_api}"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of language codes. Calling ${striptracks_type^} API using GET and URL '$url'" | log
  unset striptracks_result
  striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --get "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
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
  for ((i=1; i <= 2; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Deleting or recycling \"$striptracks_video\". Calling ${striptracks_type^} API using DELETE and URL '$url'" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
       -H "Content-Type: application/json" \
       -H "Accept: application/json" \
       -X DELETE "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcrM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      [ $striptracks_debug -ge 1 ] && echo "Debug|Database is locked. Waiting 1 minute." | log
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
    # local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url?${temp_id:+$temp_id&}folder=$striptracks_video_folder&filterExistingFiles=false\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
    # echo "$striptracks_message" | log
    # echo "$striptracks_message" >&2
  # }
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
  for ((i=1; i <= 2; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from quality '$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)' to '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)' and release group '$(echo $striptracks_videofile_info | jq -crM '.releaseGroup | select(. != null)')' to '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'. Calling ${striptracks_type^} API using PUT and URL '$url' with data $data" | log
    unset striptracks_result
    striptracks_result=$(curl -s --fail-with-body -H "X-Api-Key: $striptracks_apikey" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      -X PUT "$url")
    local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
      local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    # Exit loop if database is not locked, else wait 1 minute
    if [[ ! "$(echo $striptracks_result | jq -jcrM .message?)" =~ database\ is\ locked ]]; then
      break
    else
      [ $striptracks_debug -ge 1 ] && echo "Debug|Database is locked. Waiting 1 minute." | log
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
# Read in the output of mkvmerge info extraction
function get_mediainfo {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: /usr/bin/mkvmerge -J \"$1\"" | log
  unset striptracks_json
  striptracks_json=$(/usr/bin/mkvmerge -J "$1" 2>&1)
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message="Error|[$striptracks_curlret] Error executing mkvmerge. It returned: $striptracks_json"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "mkvmerge returned: $striptracks_json" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_json | jq -crM '.container.supported')" = "true" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
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
    # local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url&$data\"\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    -X PUT "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -H "Content-Type: application/json" \
		-H "Accept: application/json" \
    -d "$data" \
    -X PUT "$url")
  local striptracks_curlret=$?; [ $striptracks_curlret -ne 0 ] && {
    local striptracks_message=$(echo -e "[$striptracks_curlret] curl error when calling: \"$url\" with data $data\nWeb server returned: $(echo $striptracks_result | jq -jcrM .message?)" | awk '{print "Error|"$0}')
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
  touch "$striptracks_log" 2>&1
fi

# Check that the log file is writable
if [ ! -w "$striptracks_log" ]; then
  echo "Error|Log file '$striptracks_log' is not writable or does not exist." >&2
  striptracks_log=/dev/null
  striptracks_exitstatus=12
fi

# Check for required binaries
if [ ! -f "/usr/bin/mkvmerge" ]; then
  striptracks_message="Error|/usr/bin/mkvmerge is required by this script"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 4
fi
if [ ! -f "/usr/bin/mkvpropedit" ]; then
  striptracks_message="Error|/usr/bin/mkvpropedit is required by this script"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 4
fi

# Log Debug state
if [ $striptracks_debug -ge 1 ]; then
  striptracks_message="Debug|Enabling debug logging level ${striptracks_debug}. Starting ${striptracks_type^} run for: $striptracks_title"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Log environment
[ $striptracks_debug -ge 2 ] && printenv | sort | sed 's/^/Debug|/' | log

# Handle Test event
if [[ "${!striptracks_eventtype}" = "Test" ]]; then
  echo "Info|${striptracks_type^} event: ${!striptracks_eventtype}" | log
  striptracks_message="Info|Script was test executed successfully."
  echo "$striptracks_message" | log
  echo "$striptracks_message"
  end_script 0
fi

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

  # Check for localhost
  [[ $striptracks_bindaddress = "*" ]] && striptracks_bindaddress=localhost

  # Build URL to Radarr/Sonarr API
  striptracks_api_url="http://$striptracks_bindaddress:$striptracks_port${striptracks_urlbase:+/$striptracks_urlbase}/api/v3"

  # Check Radarr/Sonarr version
  if get_version; then
    striptracks_arr_version="$(echo $striptracks_result | jq -crM .version)"
    [ $striptracks_debug -ge 1 ] && echo "Debug|Detected ${striptracks_type^} version $striptracks_arr_version" | log
  fi

  # Requires API v3
  if [ "${striptracks_arr_version/.*/}" = "2" ]; then
    # Radarr/Sonarr version 2
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
  striptracks_message="Error|No video file detected! radarr_moviefile_path or sonarr_episodefile_path environment variable missing and -f option not specified on command line."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage 
  end_script 1
fi

# Check if source video exists
if [ ! -f "$striptracks_video" ]; then
  striptracks_message="Error|Input file not found: \"$striptracks_video\""
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
  # Get language codes
  if get_language_codes; then
    striptracks_lang_codes="$striptracks_result"
    # Fix for Sonarr code formatting
    if [ "${striptracks_type,,}" = "sonarr" ]; then
      striptracks_lang_codes="$(echo $striptracks_lang_codes | jq -crM '[.[0].languages[].language]')"
    fi
    # Get quality/language profile info
    if get_profiles; then
      striptracks_profiles="$striptracks_result"
      # Get video profile
      if get_video_info; then
        # This is not necessary, as this is normally set in the environment. However, this is needed  for testing.
        striptracks_videofile_id="$(echo $striptracks_result | jq -crM .${striptracks_json_quality_root}.id)"
        # Get language name(s) from video profile ID
        striptracks_profileId="$(echo $striptracks_result | jq -crM $striptracks_profile_jq)"
        striptracks_languages="$(echo $striptracks_profiles | jq -cM "[.[] | select(.id == $striptracks_profileId) | $striptracks_language_jq]")"
        striptracks_profileName="$(echo $striptracks_profiles | jq -crM ".[] | select(.id == $striptracks_profileId).name")"
        striptracks_proflangNames="$(echo $striptracks_languages | jq -crM '[.[].name]')"
        # Get originalLanguage of video from Radarr (returns null for Sonarr)
        striptracks_orglangName="$(echo $striptracks_result | jq -crM .originalLanguage.name)"
        # Get video file info. Needed to save the original quality.
        get_videofile_info
        striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
          # No '.path' in returned JSON
          striptracks_message="Warn|The '$striptracks_videofile_api' API with id $striptracks_videofile_id returned no path."
          echo "$striptracks_message" | log
          echo "$striptracks_message" >&2
          striptracks_exitstatus=20
        }
        # Save original metadata
        striptracks_original_metadata="$(echo $striptracks_result | jq -crM '{quality, releaseGroup}')"
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected quality '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)'" | log
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected release group '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'" | log
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected $striptracks_profile_type profile '(${striptracks_profileId}) ${striptracks_profileName}'" | log
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected $striptracks_profile_type profile language(s) '$(echo $striptracks_languages | jq -crM '[.[] | "(\(.id | tostring)) \(.name)"] | join(",")')'" | log
        if [ -n "$striptracks_orglangName" -a "$striptracks_orglangName" != "null" ]; then
          # shellcheck disable=SC2090
          striptracks_orglangCode="$(echo $striptracks_isocodemap | jq -jcrM ".languages[] | select(.language.name == \"$striptracks_orglangName\") | .language | \":\(.\"iso639-2\"[])\"")"
          [ $striptracks_debug -ge 1 ] && echo "Debug|Detected original video language of '$striptracks_orglangName ($striptracks_orglangCode)' from $striptracks_video_type '$striptracks_rescan_id'" | log
        fi
        # Map language names to ISO code(s) used by mkvmerge
        unset striptracks_proflangCodes
        for striptracks_templang in $(echo $striptracks_proflangNames | jq -crM '.[]'); do
          # Convert 'Original' profile selection to specific video language (Radarr only)
          if [[ "$striptracks_templang" = "Original" ]]; then
            striptracks_templang="$striptracks_orglangName"
          fi
          # shellcheck disable=SC2090
          striptracks_proflangCodes+="$(echo $striptracks_isocodemap | jq -jcrM ".languages[] | select(.language.name == \"$striptracks_templang\") | .language | \":\(.\"iso639-2\"[])\"")"
        done
        [ $striptracks_debug -ge 1 ] && echo "Debug|Mapped profile language(s) '$(echo $striptracks_proflangNames | jq -crM "join(\",\")")' to ISO639-2 code string '$striptracks_proflangCodes'" | log
      else
        # 'hasFile' is False in returned JSON.
        striptracks_message="Warn|The '$striptracks_video_api' API with id $striptracks_video_id returned a false hasFile."
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        striptracks_exitstatus=17
      fi
    else
      # Get Profiles API failed
      striptracks_message="Warn|Unable to retrieve $striptracks_profile_type profiles from ${striptracks_type^} API"
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      striptracks_exitstatus=17
    fi
  else
    # Get language codes API failed
    striptracks_message="Warn|Unable to retrieve language codes from '$striptracks_language_api' API (curl error or returned a null name)."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    striptracks_exitstatus=17
  fi
else
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  striptracks_exitstatus=20
fi

# Special handling for ':org' code from command line.  This is only valid in Radarr!
if [[ "$striptracks_audiokeep" =~ :org ]]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Command line ':org' code specified for audio. Changing '${striptracks_audiokeep}' to '${striptracks_audiokeep//:org/${striptracks_orglangCode}}'" | log
  striptracks_audiokeep="${striptracks_audiokeep//:org/${striptracks_orglangCode}}"
  if [ "${striptracks_type,,}" = "sonarr" -o "${striptracks_type,,}" = "batch" ]; then
    striptracks_message="Warn|:org code specified for audio, but this is undefined for Sonarr and Batch mode! Unexpected behavior may result."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  fi
fi
if [[ "$striptracks_subskeep" =~ :org ]]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Command line ':org' specified for subtitles. Changing '${striptracks_subskeep}' to '${striptracks_subskeep//:org/${striptracks_orglangCode}}'" | log
  striptracks_subskeep="${striptracks_subskeep//:org/${striptracks_orglangCode}}"
  if [ "${striptracks_type,,}" = "sonarr" -o "${striptracks_type,,}" = "batch" ]; then
    striptracks_message="Warn|:org code specified for subtitles, but this is undefined for Sonarr and Batch mode! Unexpected behavior may result."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  fi
fi

# Final assignment of audio and subtitles options
## Guard clause
if [ -z "$striptracks_audiokeep" -a -z "$striptracks_proflangCodes" ]; then
  striptracks_message="Error|No audio languages specified or detected!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  end_script 2
fi
## Allows command line argument to override detected languages
if [ -z "$striptracks_audiokeep" -a -n "$striptracks_proflangCodes" ]; then
  striptracks_audiokeep="$striptracks_proflangCodes"
fi

## Guard clause
if [ -z "$striptracks_subskeep" -a -z "$striptracks_proflangCodes" ]; then
  striptracks_message="Info|No subtitles languages specified or detected. Removing all subtitles found."
  echo "$striptracks_message" | log
  striptracks_subskeep="null"
fi
## Allows command line argument to override detected languages
if [ -z "$striptracks_subskeep" -a -n "$striptracks_proflangCodes" ]; then
  striptracks_subskeep="$striptracks_proflangCodes"
fi

#### BEGIN MAIN
# shellcheck disable=SC2046
striptracks_filesize=$(stat -c %s "${striptracks_video}" | numfmt --to iec --format "%.3f")
striptracks_message="Info|${striptracks_type^} event: ${!striptracks_eventtype}, Video: $striptracks_video, Size: $striptracks_filesize, AudioKeep: $striptracks_audiokeep, SubsKeep: $striptracks_subskeep"
echo "$striptracks_message" | log

# Read in the output of mkvmerge info extraction
if get_mediainfo "$striptracks_video"; then
  # This and the modified AWK script are a hack, and I know it.  JQ is crazy hard to learn, BTW.
  # Mimic the mkvmerge --identify-verbose option that has been deprecated
  striptracks_json_processed=$(echo $striptracks_json | jq -jcrM '
  ( if (.chapters[] | .num_entries) then
      "Chapters: \(.chapters[] | .num_entries) entries\n"
    else
      empty
    end
  ),
  ( .tracks[] |
    ( "Track ID \(.id): \(.type) (\(.codec)) [",
      ( [.properties | to_entries[] | "\(.key):\(.value | tostring | gsub(" "; "\\s"))"] | join(" ")),
      "]\n"
    )
  )
  ')
  [ $striptracks_debug -ge 1 ] && echo "$striptracks_json_processed" | awk '{print "Debug|"$0}' | log
else
  # Get media info failed
  if [ "$(echo $striptracks_json | jq -crM '.container.supported')" = "false" ]; then
    striptracks_message="Error|Container format '$(echo $striptracks_json | jq -crM .container.type)' is unsupported by mkvmerge. Unable to continue."
  else
    striptracks_message="Error|mkvmerge error. Unable to continue."
  fi
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 9
fi

# Process video file
echo "$striptracks_json_processed" | awk -v Debug=$striptracks_debug \
-v Video="$striptracks_video" \
-v TempVideo="$striptracks_tempvideo" \
-v Title="$striptracks_title" \
-v AudioKeep="$striptracks_audiokeep" \
-v SubsKeep="$striptracks_subskeep" '
# Exit codes: 0 success; 1 No tracks in source file; 2 No tracks removed; 3 How did we get here?
# Array join function, based on GNU docs
function join(array, sep,    i, ret) {
  for (i in array)
    if (ret == "")
      ret = array[i]
    else
      ret = ret sep array[i]
  return ret
}
BEGIN {
  MKVMerge = "/usr/bin/mkvmerge"
  FS = "[\t\n: ]"
  IGNORECASE = 1
}
/^Track ID/ {
  FieldCount = split($0, Fields)
  if (Fields[1] == "Track") {
    NoTr++
    Track[NoTr, "id"] = Fields[3]
    Track[NoTr, "typ"] = Fields[5]
    # This is inelegant and I know it
    # Finds the codec in parenthesis
    if (Fields[6] ~ /^\(/) {
      for (i = 6; i <= FieldCount; i++) {
        Track[NoTr, "codec"] = Track[NoTr, "codec"]" "Fields[i]
        if (match(Fields[i], /\)$/))
          break
      }
      sub(/^ /, "", Track[NoTr, "codec"])
    }
    if (Track[NoTr, "typ"] == "video") VidCnt++
    if (Track[NoTr, "typ"] == "audio") AudCnt++
    if (Track[NoTr, "typ"] == "subtitles") SubsCnt++
    for (i = 6; i <= FieldCount; i++) {
      if (Fields[i] == "language")
        Track[NoTr, "lang"] = Fields[++i]
    }
    if (Track[NoTr, "lang"] == "")
      Track[NoTr, "lang"] = "und"
  }
}
/^Chapters/ {
  Chapters = $3
}
END {
  # Source video had no tracks
  if (!NoTr) {
    exit 1
  }
  if (!AudCnt) AudCnt=0; if (!SubsCnt) SubsCnt=0
  print "Info|Original tracks: "NoTr" (audio: "AudCnt", subtitles: "SubsCnt")"
  if (Chapters) print "Info|Chapters: "Chapters
  for (i = 1; i <= NoTr; i++) {
    if (Debug >= 2) print "Debug|i:"i,"Track ID:"Track[i,"id"],"Type:"Track[i,"typ"],"Lang:"Track[i, "lang"],"Codec:"Track[i, "codec"]
    if (Track[i, "typ"] == "audio") {
      # Keep track if it matches command line selection, or if it is matches pseudo code ":any"
      if (AudioKeep ~ Track[i, "lang"] || AudioKeep ~ ":any") {
        print "Info|Keeping audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      # Special case if there is only one audio track, even if it was not selected
      } else if (AudCnt == 1) {
        print "Warn|No audio tracks matched! Keeping only audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      # Special case if there were multiple tracks, none were selected, and this is the last one.
      } else if (length(AudioCommand) == 0 && Track[i, "id"] == AudCnt) {
        print "Warn|No audio tracks matched! Keeping last audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      # Special case for mis and zxx
      } else if (":mis:zxx" ~ Track[i, "lang"]) {
        print "Info|Keeping special audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      } else
        AudRmvLog[i] = Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
    } else {
      if (Track[i, "typ"] == "subtitles") {
        if (SubsKeep ~ Track[i, "lang"] || SubsKeep ~ ":any") {
          print "Info|Keeping subtitles track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
          SubsCommand[i] = Track[i, "id"]
        } else
          SubsRmvLog[i] = Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
      }
    }
  }
  if (length(AudRmvLog) != 0) print "Info|Removed audio tracks: " join(AudRmvLog, ",")
  if (length(SubsRmvLog) != 0) print "Info|Removed subtitles tracks: " join(SubsRmvLog, ",")
  print "Info|Kept tracks: "length(AudioCommand)+length(SubsCommand)+VidCnt" (audio: "length(AudioCommand)", subtitles: "length(SubsCommand)")"
  # All tracks matched/no tracks removed.
  if (length(AudioCommand)+length(SubsCommand)+VidCnt == NoTr) {
    if (Debug >= 1) print "Debug|No tracks will be removed from video \""Video"\""
    # Only skip remux if already MKV.
    if (match(Video, /\.mkv$/)) {
      exit 2
    }
    if (Debug >= 1) print "Debug|Source video is not MKV. Remuxing anyway."
  }
  # This should never happen, but belt and suspenders
  if (length(AudioCommand) == 0) {
    print "Warn|Script encountered an error when determining audio tracks to keep and must close."
    exit 3
  }
  CommandLine = "-a " join(AudioCommand, ",")
  if (length(SubsCommand) == 0)
    CommandLine = CommandLine" -S"
  else
    CommandLine = CommandLine" -s " join(SubsCommand, ",")
  if (Debug >= 1) print "Debug|Executing: nice "MKVMerge" --title \""Title"\" -q -o \""TempVideo"\" "CommandLine" \""Video"\""
  Result = system("nice "MKVMerge" --title \""Title"\" -q -o \""TempVideo"\" "CommandLine" \""Video"\"")
  if (Result > 1) print "Error|["Result"] remuxing \""Video"\"" > "/dev/stderr"
}' | log
#### END MAIN

# Check awk exit code
striptracks_return="${PIPESTATUS[1]}"
[ $striptracks_debug -ge 2 ] && echo "Debug|awk exited with code: $striptracks_return" | log
[ $striptracks_return -ne 0 ] && {
  case "$striptracks_return" in
    1) # Source video had no tracks
       striptracks_message="Error|The original video \"$striptracks_video\" had no audio or subtitle tracks!"
       echo "$striptracks_message" | log
       echo "$striptracks_message" >&2
       end_script 11
    ;;
    2) # All tracks matched/no tracks removed and already MKV.  Remuxing not performed.
       striptracks_message="Info|No tracks would be removed from video. Setting Title only and exiting."
       echo "$striptracks_message" | log
       [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: /usr/bin/mkvpropedit -q --edit info --set \"title=$striptracks_title\" \"$striptracks_video\"" | log
       /usr/bin/mkvpropedit -q --edit info --set "title=$striptracks_title" "$striptracks_video" 2>&1 | log
       end_script 0
    ;;
    *) striptracks_message="Error|[$striptracks_return] Script exited abnormally."
       echo "$striptracks_message" | log
       echo "$striptracks_message" >&2
       end_script 13
    ;;
  esac
}

# Check for non-empty file
if [ ! -s "$striptracks_tempvideo" ]; then
  striptracks_message="Error|Unable to locate or invalid remuxed file: \"$striptracks_tempvideo\".  Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 10
fi

# Just delete the original video if running in batch mode
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Deleting: \"$striptracks_video\"" | log
  rm "$striptracks_video" 2>&1 | log
  striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
    striptracks_message="Error|[$striptracks_return] Error when deleting video: \"$striptracks_video\""
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

# Another check for the temporary file, to make sure it wasn't deleted
if [ ! -f "$striptracks_tempvideo" ]; then
  striptracks_message="Error|${striptracks_type^} deleted the temporary remuxed file: \"$striptracks_tempvideo\".  Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 10
fi

# Rename the temporary video file to MKV
[ $striptracks_debug -ge 1 ] && echo "Debug|Renaming: \"$striptracks_tempvideo\" to \"$striptracks_newvideo\"" | log
mv -f "$striptracks_tempvideo" "$striptracks_newvideo" 2>&1 | log
striptracks_return=$?; [ $striptracks_return -ne 0 ] && {
  striptracks_message="Error|[$striptracks_return] Unable to rename temp video: \"$striptracks_tempvideo\" to: \"$striptracks_newvideo\".  Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  end_script 6
}

# shellcheck disable=SC2046
striptracks_filesize=$(stat -c %s "${striptracks_newvideo}" | numfmt --to iec --format "%.3f")
striptracks_message="Info|New size: $striptracks_filesize"
echo "$striptracks_message" | log

#### Call Radarr/Sonarr API to RescanMovie/RescanSeries
# Check for URL
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Cannot use API in batch mode." | log
elif [ -n "$striptracks_api_url" ]; then
  # Check for video IDs
  if [ "$striptracks_video_id" -a "$striptracks_videofile_id" ]; then
    ##### Leaving this here (and all supporting functions and variables) in case the single file import job problem can be resolved.
    ##### See GitHub Issue #50.  Importing directly is a much better way than rescanning.
    # Scan for files to import into Radarr/Sonarr
    # if get_import_info; then
      # # Build JSON data
      # [ $striptracks_debug -ge 1 ] && echo "Debug|Building JSON data to import" | log
      # striptracks_json=$(echo $striptracks_result | jq -jcrM "
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
        striptracks_videofile_id="$(echo $striptracks_result | jq -crM .${striptracks_json_quality_root}.id)"
        [ $striptracks_debug -ge 1 ] && echo "Debug|Set new video file id '$striptracks_videofile_id'." | log
        # Get new video file info
        if get_videofile_info; then
          striptracks_videofile_info="$striptracks_result"
          # Check that the file didn't get lost in the Rescan.
          # TODO: In Radarr, losing customFormats and customFormatScore
          # Put back the missing metadata
          set_metadata
          # Check that the returned result shows the updates
          if [ "$(echo $striptracks_result | jq -crM .[].quality.quality.name)" = "$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)" ]; then
            # Updated successfully
            [ $striptracks_debug -ge 1 ] && echo "Debug|Successfully updated quality to '$(echo $striptracks_result | jq -crM .[].quality.quality.name)'." | log
            [ $striptracks_debug -ge 1 ] && echo "Debug|Successfully updated release group to '$(echo $striptracks_result | jq -crM '.[].releaseGroup | select(. != null)')'." | log
          else
            striptracks_message="Warn|Unable to update ${striptracks_type^} $striptracks_video_api '$striptracks_title' to quality '$(echo $striptracks_original_metadata | jq -crM .quality.quality.name)' or release group to '$(echo $striptracks_original_metadata | jq -crM '.releaseGroup | select(. != null)')'"
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
            striptracks_exitstatus=17
          fi

          # Check the languages returned
          # If we stripped out other languages, remove them from Radarr
          # Only works in Radarr (no per-episode edit function in Sonarr)
          if get_mediainfo "$striptracks_newvideo"; then
            # Build array of full name languages
            striptracks_newvideo_langcodes="$(echo $striptracks_json | jq -crM '.tracks[] | select(.type == "audio") | .properties.language')"
            unset striptracks_newvideo_languages
            for i in $striptracks_newvideo_langcodes; do
              # shellcheck disable=SC2090
              striptracks_newvideo_languages+="$(echo $striptracks_isocodemap | jq -crM ".languages[] | .language | select((.\"iso639-2\"[]) == \"$i\") | select(.name != \"Any\" and .name != \"Original\").name")"
            done
            if [ -n "$striptracks_newvideo_languages" ]; then
              # Covert to standard JSON
              striptracks_json_languages="$(echo $striptracks_lang_codes | jq -crM "map(select(.name | inside(\"$striptracks_newvideo_languages\")) | {id, name})")"
              # Check languages for Radarr
              if [ "$(echo $striptracks_videofile_info | jq -crM .languages)" != "null" ]; then
                if [ "$(echo $striptracks_videofile_info | jq -crM ".languages")" != "$striptracks_json_languages" ]; then
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
              # Check languages for Sonarr
              elif [ "$(echo $striptracks_videofile_info | jq -crM .language)" != "null" ]; then
                if [ "$(echo $striptracks_videofile_info | jq -crM ".language")" != "$(echo $striptracks_json_languages | jq -crM ".[0]")" ]; then
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
            else
              # Video language not in striptracks_isocodemap
              striptracks_message="Warn|Video language code(s) '${striptracks_newvideo_langcodes//$'\n'/,}' not found in the ISO Codemap. Cannot evaluate."
              echo "$striptracks_message" | log
              echo "$striptracks_message" >&2
              striptracks_exitstatus=20
            fi
          else
            # Get media info failed
            striptracks_message="Error|Could not get media info from new video file. Can't check resulting languages."
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
            striptracks_exitstatus=9
          fi
          # Get list of videos that could be renamed
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
            fi
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
        striptracks_message="Warn|The '$striptracks_video_api' API with id $striptracks_video_id returned a false 'hasFile'."
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
