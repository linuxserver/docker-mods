#!/bin/bash

# Video remuxing script designed for use with Radarr and Sonarr
# Automatically strips out unwanted audio and subtitles streams, keeping only the desired languages.
#  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks
#  Dev/test: https://github.com/TheCaptain989/radarr-striptracks

# Adapted and corrected from Endoro's post 1/5/2014:
#  https://forum.videohelp.com/threads/343271-BULK-remove-non-English-tracks-from-MKV-container#post2292889
#
# Option processing taken from Drew Strokes post 3/24/2015:
#  https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
#
# Put a colon `:` in front of every language code.  Expects ISO639-2 codes
#

# NOTE: This has been updated to work with v3 API only.  Far too many complications trying to keep multiple version compatible.

# Dependencies:
#  mkvmerge
#  awk
#  curl
#  jq
#  numfmt
#  stat
#  nice
#  basename

# Exit codes:
#  0 - success; or test
#  1 - no video file specified on command line
#  2 - no audio language specified on command line
#  3 - no subtitles language specified on command line
#  4 - mkvmerge not found
#  5 - specified video file not found
#  6 - unable to rename video to temp video
#  7 - unknown eventtype environment variable
#  8 - unsupported Radarr/Sonarr version (v2)
#  9 - mkvmerge get media info failed
# 10 - remuxing completed, but no output file found
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
unset striptracks_pos_params
# Presence of '*_eventtype' variable sets script mode
export striptracks_type=$(printenv | sed -n 's/_eventtype *=.*$//p')

# Usage function
function usage {
  usage="
$striptracks_script   Version: $striptracks_ver
Video remuxing script that only keeps tracks with the specified languages.
Designed for use with Radarr and Sonarr, but may be used standalone in batch mode.

Source: https://github.com/TheCaptain989/radarr-striptracks

Usage:
  $0 [OPTIONS] [<audio_languages> [<subtitle_languages>]]
  $0 [OPTIONS] {-f|--file} <video_file> {-a|--audio} <audio_languages> {-s|--subs} <subtitle_languages>

Options and Arguments:
  -d, --debug [<level>]            enable debug logging
                                   Level is optional, default of 1 (low)
  -a, --audio <audio_languages>    audio languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   Multiple codes may be concatenated.
  -s, --subs <subtitle_languages>  subtitles languages to keep
                                   ISO639-2 code(s) prefixed with a colon \`:\`
                                   Multiple codes may be concatenated.
  -f, --file <video_file>          if included, the script enters batch mode
                                   and converts the specified video file.
                                   WARNING: Do not use this argument when called
                                   from Radarr or Sonarr!
      --help                       display this help and exit
      --version                    display script version and exit
      
When audio_languages and subtitle_languages are omitted the script detects the audio
or subtitle languages configured in the Radarr or Sonarr profile.  When used on the command
line, they override the detected codes.  They are also accepted as positional parameters
for backwards compatibility.

Batch Mode:
  In batch mode the script acts as if it were not called from within Radarr
  or Sonarr.  It converts the file specified on the command line and ignores
  any environment variables that are normally expected.  The MKV embedded title
  attribute is set to the basename of the file minus the extension.

Examples:
  $striptracks_script -d 2                       # Enable debugging level 2, audio and subtitles
                                            # languages detected from Radarr/Sonarr
  $striptracks_script -a :eng:und -s :eng        # keep English and Unknown audio and
                                            # English subtitles
  $striptracks_script -a :eng:org -s :eng        # keep English and Original audio and
                                            # English subtitles
  $striptracks_script :eng \"\"                    # keep English audio and no subtitles
  $striptracks_script -d :eng:kor:jpn :eng:spa   # Enable debugging level 1, keeping English, Korean,
                                            # and Japanese audio, and English and
                                            # Spanish subtitles
  $striptracks_script -f \"/path/to/movies/Finding Nemo (2003).mkv\" -a :eng:und -s :eng
                                            # Batch Mode
                                            # Keep English and Unknown audio and
                                            # English subtitles, converting video specified

"
  echo "$usage" >&2
}

# Process arguments
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
    -*|--*=) # Unknown option
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

# Check for and assign positional arguments
if [ -n "$1" ]; then
  striptracks_audiokeep="$1"
fi
if [ -n "$2" ]; then
  striptracks_subskeep="$2"
fi

## Mode specific variables
if [[ "${striptracks_type,,}" = "batch" ]]; then
  # Batch mode
  export batch_eventtype="Convert"
  export striptracks_title="$(basename "$striptracks_video" ".${striptracks_video##*.}")"
elif [[ "${striptracks_type,,}" = "radarr" ]]; then
  # Radarr mode
  export striptracks_video="$radarr_moviefile_path"
  export striptracks_video_api="movie"
  export striptracks_video_id="${radarr_movie_id}"
  export striptracks_videofile_api="moviefile"
  export striptracks_videofile_id="${radarr_moviefile_id}"
  export striptracks_rescan_id="${radarr_movie_id}"
  export striptracks_json_quality_root=".movieFile"
  export striptracks_video_type="movie"
  export striptracks_profile_type="quality"
  export striptracks_title="${radarr_movie_title:-UNKNOWN} (${radarr_movie_year:-UNKNOWN})"
  export striptracks_language_api="language"
elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
  # Sonarr mode
  export striptracks_video="$sonarr_episodefile_path"
  export striptracks_video_api="episode"
  export striptracks_video_id="${sonarr_episodefile_episodeids}"
  export striptracks_videofile_api="episodefile"
  export striptracks_videofile_id="${sonarr_episodefile_id}"
  export striptracks_rescan_id="${sonarr_series_id}"
  export striptracks_json_quality_root=".episodeFile"
  export striptracks_video_type="series"
  export striptracks_profile_type="language"
  export striptracks_title="${sonarr_series_title:-UNKNOWN} $(numfmt --format "%02f" ${sonarr_episodefile_seasonnumber:-0})x$(numfmt --format "%02f" ${sonarr_episodefile_episodenumbers:-0}) - ${sonarr_episodefile_episodetitles:-UNKNOWN}"
  export striptracks_language_api="languageprofile"
else
  # Called in an unexpected way
  echo -e "Error|Unknown or missing '*_eventtype' environment variable: ${striptracks_type}\nNot called from Radarr/Sonarr.\nTry using Batch Mode option: -f <file>"
  exit 7
fi
export striptracks_rescan_api="Rescan${striptracks_video_type^}"
export striptracks_json_key="${striptracks_video_type}Id"
export striptracks_eventtype="${striptracks_type,,}_eventtype"
export striptracks_tempvideo="${striptracks_video}.tmp"
export striptracks_newvideo="${striptracks_video%.*}.mkv"
# If this were defined directly in Radarr or Sonarr this would not be needed here
striptracks_isocodemap='{"languages":[{"language":{"name":"Any","iso639-2":["ara","bul","zho","chi","ces","cze","dan","nld","dut","eng","fin","fra","fre","deu","ger","ell","gre","heb","hin","hun","isl","ice","ita","jpn","kor","lit","nor","pol","por","ron","rom","rus","spa","swe","tha","tur","vie","und"]}},{"language":{"name":"Arabic","iso639-2":["ara"]}},{"language":{"name":"Bulgarian","iso639-2":["bul"]}},{"language":{"name":"Chinese","iso639-2":["zho","chi"]}},{"language":{"name":"Czech","iso639-2":["ces","cze"]}},{"language":{"name":"Danish","iso639-2":["dan"]}},{"language":{"name":"Dutch","iso639-2":["nld","dut"]}},{"language":{"name":"English","iso639-2":["eng"]}},{"language":{"name":"Finnish","iso639-2":["fin"]}},{"language":{"name":"Flemish","iso639-2":["nld","dut"]}},{"language":{"name":"French","iso639-2":["fra","fre"]}},{"language":{"name":"German","iso639-2":["deu","ger"]}},{"language":{"name":"Greek","iso639-2":["ell","gre"]}},{"language":{"name":"Hebrew","iso639-2":["heb"]}},{"language":{"name":"Hindi","iso639-2":["hin"]}},{"language":{"name":"Hungarian","iso639-2":["hun"]}},{"language":{"name":"Icelandic","iso639-2":["isl","ice"]}},{"language":{"name":"Italian","iso639-2":["ita"]}},{"language":{"name":"Japanese","iso639-2":["jpn"]}},{"language":{"name":"Korean","iso639-2":["kor"]}},{"language":{"name":"Lithuanian","iso639-2":["lit"]}},{"language":{"name":"Norwegian","iso639-2":["nor"]}},{"language":{"name":"Polish","iso639-2":["pol"]}},{"language":{"name":"Portuguese","iso639-2":["por"]}},{"language":{"name":"Romanian","iso639-2":["rum","ron"]}},{"language":{"name":"Russian","iso639-2":["rus"]}},{"language":{"name":"Spanish","iso639-2":["spa"]}},{"language":{"name":"Swedish","iso639-2":["swe"]}},{"language":{"name":"Thai","iso639-2":["tha"]}},{"language":{"name":"Turkish","iso639-2":["tur"]}},{"language":{"name":"Vietnamese","iso639-2":["vie"]}},{"language":{"name":"Unknown","iso639-2":["und"]}}]}'

### Functions

# Can still go over striptracks_maxlog if read line is too long
#  Must include whole function in subshell for read to work!
function log {(
  while read
  do
    echo $(date +"%Y-%-m-%-d %H:%M:%S.%1N")\|"[$striptracks_pid]$REPLY" >>"$striptracks_log"
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
  read -d \< striptracks_xml_entity striptracks_xml_content
}
# Get video information
function get_video_info {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting video information for $striptracks_video_api '$striptracks_video_id'. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/$striptracks_video_api/$striptracks_video_id'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/$striptracks_video_api/$striptracks_video_id")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/$striptracks_video_api/$striptracks_video_id\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM .hasFile)" = "true" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get video file information
function get_videofile_info {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting video file information for $striptracks_videofile_api id '$striptracks_videofile_id'. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/$striptracks_videofile_api/$striptracks_videofile_id'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/$striptracks_videofile_api/$striptracks_videofile_id")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/$striptracks_videofile_api/$striptracks_videofile_id\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM .path)" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Initiate Rescan request
function rescan {
  striptracks_message="Info|Calling ${striptracks_type^} API to rescan ${striptracks_video_type}, try #$loop"
  echo "$striptracks_message" | log
  [ $striptracks_debug -ge 1 ] && echo "Debug|Forcing rescan of $striptracks_video_api '$striptracks_rescan_id', try #$loop. Calling ${striptracks_type^} API '$striptracks_rescan_api' using POST and URL '$striptracks_api_url/v3/command' with data {\"name\": \"$striptracks_rescan_api\", \"$striptracks_json_key\": $striptracks_rescan_id}" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
    -d "{\"name\": \"$striptracks_rescan_api\", \"$striptracks_json_key\": $striptracks_rescan_id}" \
    -X POST "$striptracks_api_url/v3/command")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/command\" with data {\"name\": \"$striptracks_rescan_api\", \"$striptracks_json_key\": $striptracks_rescan_id}"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  striptracks_jobid="$(echo $striptracks_result | jq -crM .id)"
  if [ "$striptracks_jobid" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Check result of rescan job
function check_rescan {
  local i=0
  for ((i=1; i <= 15; i++)); do
    [ $striptracks_debug -ge 1 ] && echo "Debug|Checking job $striptracks_jobid completion, try #$i. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/command/$striptracks_jobid'" | log
    striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
      -X GET "$striptracks_api_url/v3/command/$striptracks_jobid")
    local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
      local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/command/$striptracks_jobid\""
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
    [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
    if [ "$(echo $striptracks_result | jq -crM .status)" = "completed" ]; then
      local striptracks_return=0
      break
    else
      if [ "$(echo $striptracks_result | jq -crM .status)" = "failed" ]; then
        local striptracks_return=2
        break
      else
        # It may have timed out, so let's wait a second
        local striptracks_return=1
        [ $striptracks_debug -ge 1 ] && echo "Debug|Job not done.  Waiting 1 second." | log
        sleep 1
      fi
    fi
  done
  return $striptracks_return
}
# Get language/quality profiles
function get_profiles {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of $striptracks_profile_type profiles. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/${striptracks_profile_type}Profile'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/${striptracks_profile_type}Profile")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/${striptracks_profile_type}Profile\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  # This returns A LOT of data, and it is normally not needed
  [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.message?')" != "NotFound" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get language codes
function get_language_codes {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting list of language codes. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/${striptracks_language_api}'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/${striptracks_language_api}")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] curl error when calling: \"$striptracks_api_url/v3/${striptracks_language_api}\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 3 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.[] | .name')" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Read in the output of mkvmerge info extraction
function get_mediainfo {
  [ $striptracks_debug -ge 1 ] && echo "Debug|Executing: /usr/bin/mkvmerge -J \"$1\"" | log
  striptracks_json=$(/usr/bin/mkvmerge -J "$1")
  local striptracks_return2=$?; [ "$striptracks_return2" != 0 ] && {
    local striptracks_message="Error|[$striptracks_return2] Error executing mkvmerge."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "mkvmerge returned: $striptracks_json" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_json | jq -crM '.container.supported')" == "true" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
### End Functions

# Check for required binaries
if [ ! -f "/usr/bin/mkvmerge" ]; then
  striptracks_message="Error|/usr/bin/mkvmerge is required by this script"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 4
fi

# Log Debug state
if [ $striptracks_debug -ge 1 ]; then
  striptracks_message="Debug|Enabling debug logging level ${striptracks_debug}. Starting ${striptracks_type^} run for: $striptracks_title"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Log environment
[ $striptracks_debug -ge 2 ] && printenv | sort | sed 's/^/Debug|/' | log

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

  [[ $striptracks_bindaddress = "*" ]] && striptracks_bindaddress=localhost

  # Build URL to Radarr/Sonarr API
  striptracks_api_url="http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api"

  # Check Radarr/Sonarr version
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting ${striptracks_type^} version. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/system/status'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/system/status")
  striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
    striptracks_message="Error|[$striptracks_return] curl or jq error when parsing: \"$striptracks_api_url/v3/system/status\" | jq -crM .version"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  striptracks_arr_version="$(echo $striptracks_result | jq -crM .version)"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Detected ${striptracks_type^} version $striptracks_arr_version" | log

  # Requires API v3
  if [ "${striptracks_arr_version/.*/}" = "2" ]; then
    # Radarr/Sonarr version 2
    striptracks_message="Error|This script does not support ${striptracks_type^} version ${striptracks_arr_version}. Please upgrade."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    exit 8
  fi

  # Get RecycleBin
  [ $striptracks_debug -ge 1 ] && echo "Debug|Getting ${striptracks_type^} RecycleBin. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/config/mediamanagement'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/config/mediamanagement")
  striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
    striptracks_message="Error|[$striptracks_return] curl or jq error when parsing: \"$striptracks_api_url/v3/config/mediamanagement\" | jq -crM .recycleBin"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  striptracks_recyclebin="$(echo $striptracks_result | jq -crM .recycleBin)"
  [ $striptracks_debug -ge 1 ] && echo "Debug|Detected ${striptracks_type^} RecycleBin '$striptracks_recyclebin'" | log
else
  # No config file means we can't call the API.  Best effort at this point.
  striptracks_message="Warn|Unable to locate ${striptracks_type^} config file: '$striptracks_arr_config'"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Handle Test event
if [[ "${!striptracks_eventtype}" = "Test" ]]; then
  echo "Info|${striptracks_type^} event: ${!striptracks_eventtype}" | log
  striptracks_message="Info|Script was test executed successfully."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 0
fi

# Check if video file variable is blank
if [ -z "$striptracks_video" ]; then
  striptracks_message="Error|No video file detected! radarr_moviefile_path or sonarr_episodefile_path environment variable missing or -f option not specified on command line."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage 
  exit 1
fi

# Check if source video exists
if [ ! -f "$striptracks_video" ]; then
  striptracks_message="Error|Input file not found: \"$striptracks_video\""
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 5
fi

#### Detect languages configured in Radarr/Sonarr
# Bypass language detection if using batch mode
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Cannot detect languages in batch mode." | log
# Check for URL
elif [ -n "$striptracks_api_url" ]; then
  # Get language codes
  if get_language_codes; then
    striptracks_lang_codes="$striptracks_result"
    # Get quality/language profile info
    if get_profiles; then
      striptracks_profiles="$striptracks_result"
      # Get video profile
      if get_video_info; then
        # Per environment logic
        if [[ "${striptracks_type,,}" = "radarr" ]]; then
          striptracks_lang_codes="$striptracks_lang_codes"
          striptracks_profileId="$(echo $striptracks_result | jq -crM .qualityProfileId)"
          striptracks_languages="$(echo $striptracks_profiles | jq -cM "[.[] | select(.id == $striptracks_profileId) | .language]")"
        elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
          striptracks_lang_codes="$(echo $striptracks_lang_codes | jq -crM "[.[0].languages[].language]")"
          striptracks_profileId="$(echo $striptracks_result | jq -crM .series.languageProfileId)"
          striptracks_languages="$(echo $striptracks_profiles | jq -crM "[.[] | select(.id == $striptracks_profileId) | .languages[] | select(.allowed).language]")"
        else
          # Should never fire due to previous checks, but just in case
          striptracks_message "Error|Unknown environment detected late: ${striptracks_type}"
          echo "$striptracks_message" | log
          echo "$striptracks_message" >&2
          exit 7
        fi
        striptracks_profileName="$(echo $striptracks_profiles | jq -crM ".[] | select(.id == $striptracks_profileId).name")"
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected $striptracks_profile_type profile '(${striptracks_profileId}) ${striptracks_profileName}'" | log
        striptracks_proflangNames="$(echo $striptracks_languages | jq -crM "[.[].name]")"
        [ $striptracks_debug -ge 1 ] && echo "Debug|Detected $striptracks_profile_type profile language(s) '$(echo $striptracks_languages | jq -crM '[.[] | "(\(.id | tostring)) \(.name)"] | join(",")')'" | log
        # Get originalLanguage of video from Radarr
        striptracks_orglangName="$(echo $striptracks_result | jq -crM .originalLanguage.name)"
        if [ -n "$striptracks_orglangName" ]; then
          striptracks_orglangCode="$(echo $striptracks_isocodemap | jq -jcrM ".languages[] | select(.language.name == \"$striptracks_orglangName\") | .language | \":\(.\"iso639-2\"[])\"")"
          [ $striptracks_debug -ge 1 ] && echo "Debug|Detected original video language of '$striptracks_orglangName ($striptracks_orglangCode)' from $striptracks_video_type '$striptracks_video_id'" | log
        fi
        # Map language names to ISO code(s) used by mkvmerge
        unset striptracks_proflangCodes
        for striptracks_templang in $(echo $striptracks_proflangNames | jq -crM ".[]"); do
          # Convert 'Original' profile selection to specific video language (Radarr only)
          if [[ "$striptracks_templang" = "Original" ]]; then
            striptracks_templang="$striptracks_orglangName"
          fi
          striptracks_proflangCodes+="$(echo $striptracks_isocodemap | jq -jcrM ".languages[] | select(.language.name == \"$striptracks_templang\") | .language | \":\(.\"iso639-2\"[])\"")"
        done
        [ $striptracks_debug -ge 1 ] && echo "Debug|Mapped profile language(s) '$(echo $striptracks_proflangNames | jq -crM "join(\",\")")' to ISO639-2 code string '$striptracks_proflangCodes'" | log
      else
        # 'hasFile' is False in returned JSON.
        striptracks_message="Warn|The '$striptracks_video_api' API with id $striptracks_video_id returned a false hasFile."
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
      fi
    else
      # Get Profiles API failed
      striptracks_message="Warn|Unable to retrieve $striptracks_profile_type profiles from ${striptracks_type^} API"
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    fi
  else
    # Get language codes API failed
    striptracks_message="Warn|Unable to retrieve language codes from  '$striptracks_language_api' API (returned a null name)."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  fi
else
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Final assignment of audio and subtitles options
if [ -n "$striptracks_audiokeep" ]; then
  # Allows ordered argument on command line to override detected languages
  # plus special handling of ':org' code
  [ $striptracks_debug -ge 1 ] && [[ "$striptracks_audiokeep" ~= :org ]] && echo "Debug|:org specified for audio. Using new code string of ${striptracks_audiokeep//:org/${striptracks_orglangCode}}" | log
  striptracks_audiokeep="${striptracks_audiokeep//:org/${striptracks_orglangCode}}"
elif [ -n "$striptracks_proflangCodes" ]; then
  striptracks_audiokeep="$striptracks_proflangCodes"
else
  striptracks_message="Error|No audio languages specified or detected!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  exit 2
fi

if [ -n "$striptracks_subskeep" ]; then
  # Allows ordered argument on command line to override detected languages
  # plus special handling of ':org' code
  [ $striptracks_debug -ge 1 ] && [[ "$striptracks_subskeep" ~= :org ]] && echo "Debug|:org specified for subtitles. Using new code string of ${striptracks_subskeep//:org/${striptracks_orglangCode}}" | log
  striptracks_subskeep="${striptracks_subskeep//:org/${striptracks_orglangCode}}"
elif [ -n "$striptracks_proflangCodes" ]; then
  striptracks_subskeep="$striptracks_proflangCodes"
else
  striptracks_message="Error|No subtitles languages specified or detected!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  exit 3
fi

#### BEGIN MAIN
striptracks_filesize=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_video"))
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
      ""
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
  striptracks_message="Error|Container format '$(echo $striptracks_json | jq -crM .container.type)' is unsupported by mkvmerge. Unable to continue."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 9
fi

# Rename the original video file to a temporary name
[ $striptracks_debug -ge 1 ] && echo "Debug|Renaming: \"$striptracks_video\" to \"$striptracks_tempvideo\"" | log
mv -f "$striptracks_video" "$striptracks_tempvideo" 2>&1 | log
striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
  striptracks_message="Error|[$striptracks_return] Unable to rename video: \"$striptracks_video\" to temp video: \"$striptracks_tempvideo\". Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 6
}

# Process video file
echo "$striptracks_json_processed" | awk -v Debug=$striptracks_debug \
-v OrgVideo="$striptracks_video" \
-v TempVideo="$striptracks_tempvideo" \
-v MKVVideo="$striptracks_newvideo" \
-v Title="$striptracks_title" \
-v AudioKeep="$striptracks_audiokeep" \
-v SubsKeep="$striptracks_subskeep" '
# Array join function, based on GNU docs
function join(array, sep,    i, ret) {
  for (i in array)
    if (!ret)
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
  if (!NoTr) {
    print "Error|No tracks found in \""TempVideo"\"" > "/dev/stderr"
    exit
  }
  if (!AudCnt) AudCnt=0; if (!SubsCnt) SubsCnt=0
  print "Info|Original tracks: "NoTr" (audio: "AudCnt", subtitles: "SubsCnt")"
  if (Chapters) print "Info|Chapters: "Chapters
  for (i = 1; i <= NoTr; i++) {
    if (Debug >= 2) print "Debug|i:"i,"Track ID:"Track[i,"id"],"Type:"Track[i,"typ"],"Lang:"Track[i, "lang"],"Codec:"Track[i, "codec"]
    if (Track[i, "typ"] == "audio") {
      if (AudioKeep ~ Track[i, "lang"]) {
        print "Info|Keeping audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      # Special case if there is only one audio track, even if it was not specified
      } else if (AudCnt == 1) {
        print "Info|Keeping only audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      # Special case if there were multiple tracks, none were selected, and this is the last one.
      } else if (length(AudioCommand) == 0 && Track[i, "id"] == AudCnt) {
        print "Info|Keeping last audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
        AudioCommand[i] = Track[i, "id"]
      } else
        AudRmvLog[i] = Track[i, "id"]": "Track[i, "lang"]" "Track[i, "codec"]
    } else {
      if (Track[i, "typ"] == "subtitles") {
        if (SubsKeep ~ Track[i, "lang"]) {
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
  if (length(AudioCommand) == 0) {
    # This should never happen, but belt and suspenders
    # Prevents errors during mkvmerge execution
    CommandLine = "-A"
  } else
    CommandLine = "-a " join(AudioCommand, ",")
  if (length(SubsCommand) == 0)
    CommandLine = CommandLine" -S"
  else
    CommandLine = CommandLine" -s " join(SubsCommand, ",")
  if (Debug >= 1) print "Debug|Executing: nice "MKVMerge" --title \""Title"\" -q -o \""MKVVideo"\" "CommandLine" \""TempVideo"\""
  Result = system("nice "MKVMerge" --title \""Title"\" -q -o \""MKVVideo"\" "CommandLine" \""TempVideo"\"")
  if (Result>1) print "Error|["Result"] remuxing \""TempVideo"\"" > "/dev/stderr"
}' | log
#### END MAIN

# Check for script completion and non-empty file
if [ -s "$striptracks_newvideo" ]; then
  # Use Recycle Bin if configured
  if [ "$striptracks_recyclebin" ]; then
    [ $striptracks_debug -ge 1 ] && echo "Debug|Recycling: \"$striptracks_tempvideo\" to \"${striptracks_recyclebin%/}/$(basename "$striptracks_video")"\" | log
    mv "$striptracks_tempvideo" "${striptracks_recyclebin%/}/$(basename "$striptracks_video")" 2>&1 | log
    striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
      striptracks_message="Error|[$striptracks_return] Unable to move video: \"$striptracks_tempvideo\" to Recycle Bin: \"${striptracks_recyclebin%/}\""
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
  else
    [ $striptracks_debug -ge 1 ] && echo "Debug|Deleting: \"$striptracks_tempvideo\"" | log
    rm "$striptracks_tempvideo" 2>&1 | log
    striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
      striptracks_message="Error|[$striptracks_return] Unable to delete temporary video: \"$striptracks_tempvideo\""
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
  fi
else
  striptracks_message="Error|Unable to locate or invalid remuxed file: \"$striptracks_newvideo\". Undoing rename."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  [ $striptracks_debug -ge 1 ] && echo "Debug|Renaming: \"$striptracks_tempvideo\" to \"$striptracks_video\"" | log
  mv -f "$striptracks_tempvideo" "$striptracks_video" 2>&1 | log
  striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
    striptracks_message="Error|[$striptracks_return] Unable to move video: \"$striptracks_tempvideo\" to \"$striptracks_video\""
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  }
  exit 10
fi

striptracks_filesize=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_newvideo"))
striptracks_message="Info|New size: $striptracks_filesize"
echo "$striptracks_message" | log

#### Call Radarr/Sonarr API to RescanMovie/RescanSeries
# Check for URL
if [ "$striptracks_type" = "batch" ]; then
  [ $striptracks_debug -ge 1 ] && echo "Debug|Cannot use API in batch mode." | log
elif [ -n "$striptracks_api_url" ]; then
  # Check for video IDs
  if [ "$striptracks_video_id" -a "$striptracks_videofile_id" ]; then
    # Get video file info
    if get_videofile_info; then
      # Save original quality
      striptracks_original_quality="$(echo $striptracks_result | jq -crM .quality)"
      [ $striptracks_debug -ge 1 ] && echo "Debug|Detected quality '$(echo $striptracks_original_quality | jq -crM .quality.name)'." | log
      # Loop a maximum of twice
      #  Radarr needs to Rescan twice when the file extension changes
      #  (.avi -> .mkv for example)
      for ((loop=1; $loop <= 2; loop++)); do
        # Scan the disk for the new movie file
        if rescan; then
          # Give it a beat
          sleep 1
          # Check that the Rescan completed
          if check_rescan; then
            # Get new video file id
            if get_video_info; then
              # Get new video file ID
              striptracks_videofile_id="$(echo $striptracks_result | jq -crM ${striptracks_json_quality_root}.id)"
              [ $striptracks_debug -ge 1 ] && echo "Debug|Set new video file id '$striptracks_videofile_id'." | log
              # Get new video file info
              if get_videofile_info; then
                striptracks_videofile_info="$striptracks_result"
                # Check that the file didn't get lost in the Rescan.
                # If we lost the quality information, put it back
                if [ "$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)" != "$(echo $striptracks_original_quality | jq -crM .quality.name)" ]; then
                  [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from quality '$(echo $striptracks_videofile_info | jq -crM .quality.quality.name)' to '$(echo $striptracks_original_quality | jq -crM .quality.name)'. Calling ${striptracks_type^} API using PUT and URL '$striptracks_api_url/v3/$striptracks_videofile_api/editor' with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"quality\":$striptracks_original_quality}" | log
                  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
                    -d "{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"quality\":$striptracks_original_quality}" \
                    -X PUT "$striptracks_api_url/v3/$striptracks_videofile_api/editor")
                  striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
                    striptracks_message="Error|[$striptracks_return] curl error when calling: \"$striptracks_api_url/v3/$striptracks_videofile_api/editor\" with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"quality\":$striptracks_original_quality}"
                    echo "$striptracks_message" | log
                    echo "$striptracks_message" >&2
                  }
                  [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
                  # Check that the returned result shows the update
                  if [ "$(echo $striptracks_result | jq -crM .[].quality.quality.name)" = "$(echo $striptracks_original_quality | jq -crM .quality.name)" ]; then
                    # Updated successfully
                    [ $striptracks_debug -ge 1 ] && echo "Debug|Successfully updated quality to '$(echo $striptracks_result | jq -crM .[].quality.quality.name)'." | log
                    loop=2
                  else
                    striptracks_message="Warn|Unable to update ${striptracks_type^} $striptracks_video_api '$striptracks_title' to quality '$(echo $striptracks_original_quality | jq -crM .quality.name)'"
                    echo "$striptracks_message" | log
                    echo "$striptracks_message" >&2
                  fi
                else
                  # The quality is already correct
                  [ $striptracks_debug -ge 1 ] && echo "Debug|Quality of '$(echo $striptracks_original_quality | jq -crM .quality.name)' remained unchanged." | log
                  loop=2
                fi
                # Check the languages returned
                # If we stripped out other languages, remove them from Radarr
                # Only works in Radarr (no per-episode edit function in Sonarr)
                unset striptracks_json
                if get_mediainfo "$striptracks_newvideo"; then
                  # Build array of full name languages
                  striptracks_final_langcodes="$(echo $striptracks_json | jq -crM ".tracks[] | select(.type == \"audio\") | .properties.language")"
                  unset striptracks_newvideo_languages
                  for i in $striptracks_final_langcodes; do
                    striptracks_newvideo_languages+="$(echo $striptracks_isocodemap | jq -crM ".languages[] | .language | select((.\"iso639-2\"[]) == \"$i\") | select(.name != \"Any\" and .name != \"Original\").name")"
                  done
                  if [ -n "$striptracks_newvideo_languages" ]; then
                    # Covert to standard JSON
                    striptracks_json_languages="$(echo $striptracks_lang_codes | jq -crM "map(select(.name | inside(\"$striptracks_newvideo_languages\")) | {id, name})")"
                    # Check languages for Radarr
                    if [ "$(echo $striptracks_videofile_info | jq -crM .languages)" != "null" ]; then
                      if [ "$(echo $striptracks_videofile_info | jq -crM ".languages")" != "$striptracks_json_languages" ]; then
                        [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from language(s) '$(echo $striptracks_videofile_info | jq -crM "[.languages[].name] | join(\",\")")' to '$(echo $striptracks_json_languages | jq -crM "[.[].name] | join(\",\")")'. Calling ${striptracks_type^} API using PUT and URL '$striptracks_api_url/v3/$striptracks_videofile_api/editor' with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"languages\":${striptracks_json_languages}}" | log
                        striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
                          -d "{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"languages\":${striptracks_json_languages}}" \
                          -X PUT "$striptracks_api_url/v3/$striptracks_videofile_api/editor")
                        striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
                          striptracks_message="Error|[$striptracks_return] curl error when calling: \"$striptracks_api_url/v3/$striptracks_videofile_api/editor\" with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"languages\":${striptracks_json_languages}}"
                          echo "$striptracks_message" | log
                          echo "$striptracks_message" >&2
                        }
                        [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
                      else
                        # The languages are already correct
                        [ $striptracks_debug -ge 1 ] && echo "Debug|Language(s) '$(echo $striptracks_json_languages | jq -crM "[.[].name] | join(\",\")")' remained unchanged." | log
                      fi
                    # Check languages for Sonarr
                    elif [ "$(echo $striptracks_videofile_info | jq -crM .language)" != "null" ]; then
                      if [ "$(echo $striptracks_videofile_info | jq -crM ".language")" != "$(echo $striptracks_json_languages | jq -crM ".[0]")" ]; then
                        [ $striptracks_debug -ge 1 ] && echo "Debug|Updating from language '$(echo $striptracks_videofile_info | jq -crM ".language.name")' to '$(echo $striptracks_json_languages | jq -crM ".[0].name")'. Calling ${striptracks_type^} API using PUT and URL '$striptracks_api_url/v3/$striptracks_videofile_api/editor' with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"language\":$(echo $striptracks_json_languages | jq -crM ".[0]")}" | log
                        striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
                          -d "{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"language\":$(echo $striptracks_json_languages | jq -crM ".[0]")}" \
                          -X PUT "$striptracks_api_url/v3/$striptracks_videofile_api/editor")
                        striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
                          striptracks_message="Error|[$striptracks_return] curl error when calling: \"$striptracks_api_url/v3/$striptracks_videofile_api/editor\" with data {\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"languages\":$(echo $striptracks_json_languages | jq -crM ".[0]")}"
                          echo "$striptracks_message" | log
                          echo "$striptracks_message" >&2
                        }
                        [ $striptracks_debug -ge 2 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
                      else
                        # The languages are already correct
                        [ $striptracks_debug -ge 1 ] && echo "Debug|Language '$(echo $striptracks_json_languages | jq -crM ".[0].name")' remained unchanged." | log
                      fi
                    else
                      # Some unknown JSON formatting
                      striptracks_message="Warn|The '$striptracks_videofile_api' API returned unknown JSON language location."
                      echo "$striptracks_message" | log
                      echo "$striptracks_message" >&2
                    fi
                  else
                    # Video language not in striptracks_isocodemap
                    striptracks_message="Warn|Video language code(s) '${striptracks_newvideo_languages//$'\n'/,}' not found in the ISO Codemap. Cannot evaluate."
                    echo "$striptracks_message" | log
                    echo "$striptracks_message" >&2
                  fi
                else
                  # Get media info failed
                  striptracks_message="Error|Could not get media info from new video file. Can't check resulting languages."
                  echo "$striptracks_message" | log
                  echo "$striptracks_message" >&2
                fi
              else
                # No '.path' in returned JSON
                striptracks_message="Warn|The '$striptracks_videofile_api' API with ${striptracks_video_api}File id $striptracks_videofile_id returned no path."
                echo "$striptracks_message" | log
                echo "$striptracks_message" >&2
              fi
            else
              # 'hasFile' is False in returned JSON.
              striptracks_message="Warn|The '$striptracks_video_api' API with id $striptracks_video_id returned a false 'hasFile' (Normal with Radarr on try #1)."
              echo "$striptracks_message" | log
              echo "$striptracks_message" >&2
            fi
          else
            # Timeout or failure
            striptracks_message="Warn|${striptracks_type^} job ID $striptracks_jobid timed out or failed."
            echo "$striptracks_message" | log
            echo "$striptracks_message" >&2
          fi
        else
          # Error from API
          striptracks_message="Error|The '$striptracks_rescan_api' API with $striptracks_json_key $striptracks_video_id failed."
          echo "$striptracks_message" | log
          echo "$striptracks_message" >&2
        fi
      done
    else
      # No '.path' in returned JSON
      striptracks_message="Warn|The '$striptracks_videofile_api' API with ${striptracks_video_api}File id $striptracks_videofile_id returned no path."
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    fi
  else
    # No video ID means we can't call the API
    striptracks_message="Warn|Missing or empty environment variable: striptracks_video_id='$striptracks_video_id' or striptracks_videofile_id='$striptracks_videofile_id'"
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
  fi
else
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Cool bash feature
striptracks_message="Info|Completed in $(($SECONDS/60))m $(($SECONDS%60))s"
echo "$striptracks_message" | log
