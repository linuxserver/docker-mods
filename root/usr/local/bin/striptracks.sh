#!/bin/bash

# Video remuxing script designed for use with Radarr and Sonarr
# Automatically strips out unwanted audio and subtitle streams, keeping only the desired languages.
#  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks
#  Dev/test: https://github.com/TheCaptain989/radarr-striptracks

# Adapted and corrected from Endoro's post 1/5/2014:
#  https://forum.videohelp.com/threads/343271-BULK-remove-non-English-tracks-from-MKV-container#post2292889
#
# Put a colon `:` in front of every language code.  Expects ISO639-2 codes

# NOTE: This has been updated to work with v3 API only.  Far too many complications trying to keep multiple version compatible.

# Dependencies:
#  mkvmerge
#  awk
#  curl
#  jq
#  numfmt
#  stat
#  nice

# Exit codes:
#  0 - success; or test
#  1 - no video file specified on command line
#  2 - no audio language specified on command line
#  3 - no subtitle language specified on command line
#  4 - mkvmerge not found
#  5 - specified video file not found
#  6 - unable to rename video to temp video
#  7 - unknown environment
#  8 - unsupported Radarr/Sonarr version (v2)
# 10 - remuxing completed, but no output file found
# 20 - general error

### Variables
export striptracks_script=$(basename "$0")
export striptracks_pid=$$
export striptracks_arr_config=/config/config.xml
export striptracks_log=/config/logs/striptracks.txt
export striptracks_maxlogsize=512000
export striptracks_maxlog=4
export striptracks_debug=0
export striptracks_langcodes=
export striptracks_type=$(printenv | sed -n 's/_eventtype *=.*$//p')
if [[ "${striptracks_type,,}" = "radarr" ]]; then
  export striptracks_video="$radarr_moviefile_path"
  export striptracks_video_api="movie"
  export striptracks_video_id="${radarr_movie_id}"
  export striptracks_videofile_api="moviefile"
  export striptracks_videofile_id="${radarr_moviefile_id}"
  export striptracks_rescan_id="${radarr_movie_id}"
  export striptracks_json_quality_root=".movieFile"
  export striptracks_video_type="movie"
  export striptracks_profile_type="quality"
  export striptracks_title="$radarr_movie_title ($radarr_movie_year)"
elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
  export striptracks_video="$sonarr_episodefile_path"
  export striptracks_video_api="episode"
  export striptracks_video_id="${sonarr_episodefile_episodeids}"
  export striptracks_videofile_api="episodefile"
  export striptracks_videofile_id="${sonarr_episodefile_id}"
  export striptracks_rescan_id="${sonarr_series_id}"
  export striptracks_json_quality_root=".episodeFile"
  export striptracks_video_type="series"
  export striptracks_profile_type="language"
  export striptracks_title="$sonarr_series_title $(numfmt --format "%02f" ${sonarr_episodefile_seasonnumber:-0})x$(numfmt --format "%02f" ${sonarr_episodefile_episodenumbers:-0}) - $sonarr_episodefile_episodetitles"
else
  echo "Unknown environment: ${striptracks_type}"
  exit 7
fi
export striptracks_rescan_api="Rescan${striptracks_video_type^}"
export striptracks_json_key="${striptracks_video_type}Id"
export striptracks_eventtype="${striptracks_type,,}_eventtype"
export striptracks_tempvideo="${striptracks_video}.tmp"
export striptracks_newvideo="${striptracks_video%.*}.mkv"
striptracks_isocodemap='{"languages":[{"language":{"id":-1,"name":"Any","iso639-2":["ara","bul","zho","chi","ces","cze","dan","nld","dut","eng","fin","fra","fre","deu","ger","ell","gre","heb","hin","hun","isl","ice","ita","jpn","kor","lit","nor","pol","por","ron","rom","rus","spa","swe","tha","tur","vie","und"]}},{"language":{"id":-2,"name":"Original","iso639-2":["ara","bul","zho","chi","ces","cze","dan","nld","dut","eng","fin","fra","fre","deu","ger","ell","gre","heb","hin","hun","isl","ice","ita","jpn","kor","lit","nor","pol","por","ron","rom","rus","spa","swe","tha","tur","vie","und"]}},{"language":{"id":27,"name":"Hindi","iso639-2":["hin"]}},{"language":{"id":26,"name":"Arabic","iso639-2":["ara"]}},{"language":{"id":0,"name":"Unknown","iso639-2":["und"]}},{"language":{"id":13,"name":"Vietnamese","iso639-2":["vie"]}},{"language":{"id":17,"name":"Turkish","iso639-2":["tur"]}},{"language":{"id":14,"name":"Swedish","iso639-2":["swe"]}},{"language":{"id":3,"name":"Spanish","iso639-2":["spa"]}},{"language":{"id":11,"name":"Russian","iso639-2":["rus"]}},{"language":{"id":18,"name":"Portuguese","iso639-2":["por"]}},{"language":{"id":12,"name":"Polish","iso639-2":["pol"]}},{"language":{"id":15,"name":"Norwegian","iso639-2":["nor"]}},{"language":{"id":24,"name":"Lithuanian","iso639-2":["lit"]}},{"language":{"id":21,"name":"Korean","iso639-2":["kor"]}},{"language":{"id":8,"name":"Japanese","iso639-2":["jpn"]}},{"language":{"id":5,"name":"Italian","iso639-2":["ita"]}},{"language":{"id":9,"name":"Icelandic","iso639-2":["isl","ice"]}},{"language":{"id":22,"name":"Hungarian","iso639-2":["hun"]}},{"language":{"id":23,"name":"Hebrew","iso639-2":["heb"]}},{"language":{"id":20,"name":"Greek","iso639-2":["ell","gre"]}},{"language":{"id":4,"name":"German","iso639-2":["deu","ger"]}},{"language":{"id":2,"name":"French","iso639-2":["fra","fre"]}},{"language":{"id":19,"name":"Flemish","iso639-2":["nld","dut"]}},{"language":{"id":16,"name":"Finnish","iso639-2":["fin"]}},{"language":{"id":1,"name":"English","iso639-2":["eng"]}},{"language":{"id":7,"name":"Dutch","iso639-2":["nld","dut"]}},{"language":{"id":6,"name":"Danish","iso639-2":["dan"]}},{"language":{"id":25,"name":"Czech","iso639-2":["ces","cze"]}},{"language":{"id":10,"name":"Chinese","iso639-2":["zho","chi"]}}]}'

### Functions
function usage {
  usage="
$striptracks_script
Video remuxing script designed for use with Radarr and Sonarr

Source: https://github.com/TheCaptain989/radarr-striptracks

Usage:
  $0 [-d] <audio_languages> <subtitle_languages>

Options and Arguments:
  -d                     enable debug logging
  <audio_languages>      ISO639-2 code(s) prefixed with a colon \`:\`
                         Multiple codes may be concatenated.
  <subtitle_languages>   ISO639-2 code(s) prefixed with a colon \`:\`
                         Multiple codes may be concatenated.

Examples:
  $striptracks_script :eng:und :eng              # keep English and Undetermined audio and
                                            # English subtitles
  $striptracks_script :eng \"\"                    # keep English audio and no subtitles
  $striptracks_script -d :eng:kor:jpn :eng:spa   # Enable debugging, keeping English, Korean,
                                            # and Japanese audio, and English and
                                            # Spanish subtitles
"
  echo "$usage" >&2
}
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
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting video information for $striptracks_video_api '$striptracks_video_id'. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/$striptracks_video_api/$striptracks_video_id'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/$striptracks_video_api/$striptracks_video_id")
  [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM .hasFile)" = "true" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Get video file information
function get_videofile_info {
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting video file information for $striptracks_videofile_api id '$striptracks_videofile_id'. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/$striptracks_videofile_api/$striptracks_videofile_id'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/$striptracks_videofile_api/$striptracks_videofile_id")
  [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM .path)" != "null" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}
# Initiate Rescan request
function rescan {
  striptracks_message="Info|Calling ${striptracks_type^} API to rescan ${striptracks_video_type}, try #$i"
  echo "$striptracks_message" | log
  [ $striptracks_debug -eq 1 ] && echo "Debug|Forcing rescan of $striptracks_json_key '$striptracks_rescan_id', try #$i. Calling ${striptracks_type^} API '$striptracks_rescan_api' using POST and URL '$striptracks_api_url/v3/command'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
    -d "{\"name\": \"$striptracks_rescan_api\", \"$striptracks_json_key\": $striptracks_rescan_id}" \
    -X POST "$striptracks_api_url/v3/command")
  [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
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
    [ $striptracks_debug -eq 1 ] && echo "Debug|Checking job $striptracks_jobid completion, try #$i. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/command/$striptracks_jobid'" | log
    striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
      -X GET "$striptracks_api_url/v3/command/$striptracks_jobid")
    [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
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
        [ $striptracks_debug -eq 1 ] && echo "Debug|Job not done.  Waiting 1 second." | log
        sleep 1
      fi
    fi
  done
  return $striptracks_return
}
# Get language/quality profiles
function get_profiles {
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting list of $striptracks_profile_type profiles. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/${striptracks_profile_type}Profile'" | log
  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/${striptracks_profile_type}Profile")
  # This returns A LOT of data, and it is normally not needed
  # [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $striptracks_result | jq -crM '.message?')" != "NotFound" ]; then
    local striptracks_return=0
  else
    local striptracks_return=1
  fi
  return $striptracks_return
}

# Process options
while getopts ":d" opt; do
  case ${opt} in
    d ) # For debug purposes only
      striptracks_message="Debug|Enabling debug logging."
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
      striptracks_debug=1
      printenv | sort | sed 's/^/Debug|/' | log
    ;;
  esac
done
shift $((OPTIND -1))

# Check for required binaries
if [ ! -f "/usr/bin/mkvmerge" ]; then
  striptracks_message="Error|/usr/bin/mkvmerge is required by this script"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 4
fi

# Check for config file
if [ -f "$striptracks_arr_config" ]; then
  # Read *arr config.xml
  [ $striptracks_debug -eq 1 ] && echo "Debug|Reading from ${striptracks_type^} config file '$striptracks_arr_config'" | log
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
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting ${striptracks_type^} version. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/system/status'" | log
  striptracks_arr_version=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/system/status" | jq -crM .version)
  [ $striptracks_debug -eq 1 ] && echo "Debug|Detected ${striptracks_type^} version $striptracks_arr_version" | log

  # Requires API v3
  if [ "${striptracks_arr_version/.*/}" = "2" ]; then
    # Radarr/Sonarr version 2
    striptracks_message="Error|This script does not support ${striptracks_type^} version ${striptracks_arr_version}. Please upgrade."
    echo "$striptracks_message" | log
    echo "$striptracks_message" >&2
    exit 8
  fi

  # Get RecycleBin
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting ${striptracks_type^} RecycleBin. Calling ${striptracks_type^} API using GET and URL '$striptracks_api_url/v3/config/mediamanagement'" | log
  striptracks_recyclebin=$(curl -s -H "X-Api-Key: $striptracks_apikey" \
    -X GET "$striptracks_api_url/v3/config/mediamanagement" | jq -crM .recycleBin)
  [ $striptracks_debug -eq 1 ] && echo "Debug|Detected ${striptracks_type^} RecycleBin '$striptracks_recyclebin'" | log
else
  # No config file means we can't call the API.  Best effort at this point.
  striptracks_message="Warn|Unable to locate ${striptracks_type^} config file: '$striptracks_arr_config'"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Handle Test event
if [[ "${!striptracks_eventtype}" = "Test" ]]; then
  echo "Info|${striptracks_type^} event: ${!striptracks_eventtype}" | log
  echo "Info|Script was test executed successfully." | log
  exit 0
fi

# Check if called from within Radarr/Sonarr
if [ -z "$striptracks_video" ]; then
  striptracks_message="Error|No video file specified! Not called from Radarr/Sonarr?"
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
# Check for URL
if [ -n "$striptracks_api_url" ]; then
  # Get quality/language profile info
  if get_profiles; then
    striptracks_profiles="$striptracks_result"
    # Get video profile
    if get_video_info; then
      # Per environment logic
      if [[ "${striptracks_type,,}" = "radarr" ]]; then
        striptracks_profileid="$(echo $striptracks_result | jq -crM .qualityProfileId)"
        striptracks_languages=$(echo $striptracks_profiles | jq -crM ".[] | select(.id == $striptracks_profileid) | .language.id")
      elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
        striptracks_profileid="$(echo $striptracks_result | jq -crM .series.languageProfileId)"
        striptracks_languages=$(echo $striptracks_profiles | jq -crM ".[] | select(.id == $striptracks_profileid) | .languages | .[] | select(.allowed).language.id")
      else
        # Should never fire due to previous check, but just in case
        striptracks_message "Error|Unknown environment: ${striptracks_type}"
        echo "$striptracks_message" | log
        echo "$striptracks_message" >&2
        exit 7
      fi
      striptracks_profilename=$(echo $striptracks_profiles | jq -crM ".[] | select(.id == $striptracks_profileid).name")
      [ $striptracks_debug -eq 1 ] && echo "Debug|Detected $striptracks_profile_type profile '$striptracks_profilename' id '$striptracks_profileid'" | log
      [ $striptracks_debug -eq 1 ] && echo "Debug|Detected language ids of '$(echo ${striptracks_languages})'" | log
      # Lookup ISO codes
      for i in $striptracks_languages; do
        striptracks_langcodes+=$(echo $striptracks_isocodemap | jq -jcrM ".languages | .[] | select(.language.id == $i) | .language | \":\(.\"iso639-2\"[])\"")
      done
      [ $striptracks_debug -eq 1 ] && echo "Debug|Mapped language codes '$(echo ${striptracks_languages})' to ISO639-2 code string '$striptracks_langcodes'" | log
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
  # No URL means we can't call the API
  striptracks_message="Warn|Unable to determine ${striptracks_type^} API URL."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
fi

# Check for command line options; will override the detected languages
if [ -z "$1" -a -z "$striptracks_langcodes" ]; then
  striptracks_message="Error|No audio languages specified!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  exit 2
elif [ -z "$1" ]; then
  striptracks_audiokeep="$striptracks_langcodes"
else
  striptracks_audiokeep="$1"
fi
if [ -z "$2" -a -z "$striptracks_langcodes" ]; then
  striptracks_message="Error|No subtitles languages specified!"
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  usage
  exit 3
elif [ -z "$2" ]; then
  striptracks_subskeep="$striptracks_langcodes"
else
  striptracks_subskeep="$2"
fi

#### BEGIN MAIN
striptracks_filesize=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_video"))
striptracks_message="Info|${striptracks_type^} event: ${!striptracks_eventtype}, Video: $striptracks_video, Size: $striptracks_filesize, AudioKeep: $striptracks_audiokeep, SubsKeep: $striptracks_subskeep"
echo "$striptracks_message" | log

# Rename the original video file to a temporary name
[ $striptracks_debug -eq 1 ] && echo "Debug|Renaming: \"$striptracks_video\" to \"$striptracks_tempvideo\"" | log
mv -f "$striptracks_video" "$striptracks_tempvideo" 2>&1 | log
striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
  striptracks_message="ERROR[$striptracks_return]: Unable to rename video: \"$striptracks_video\" to temp video: \"$striptracks_tempvideo\". Halting."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  exit 6
}

# Read in the output of mkvmerge info extraction
[ $striptracks_debug -eq 1 ] && echo "Debug|Executing: /usr/bin/mkvmerge -J \"$striptracks_tempvideo\"" | log
striptracks_json=$(/usr/bin/mkvmerge -J "$striptracks_tempvideo")
striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
  striptracks_message="ERROR[$striptracks_return]: Error executing mkvmerge."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
}

# This and the modified AWK script are a hack, and I know it.  JQ is crazy hard to learn, BTW.
# Mimic the mkvmerge --identify-verbose option that has been deprecated
striptracks_json_processed=$(echo $striptracks_json | jq -jcrM '
( if (.chapters | .[] | .num_entries) then
    "Chapters: \(.chapters | .[] | .num_entries) entries\n"
  else
    ""
  end
),
( .tracks |
  .[] |
  ( "Track ID \(.id): \(.type) (\(.codec)) [",
    ( [.properties | to_entries | .[] | "\(.key):\(.value | tostring | gsub(" "; "\\s"))"] | join(" ")),
    "]\n" )
)
')
[ $striptracks_debug -eq 1 ] && echo "$striptracks_json_processed" | awk '{print "Debug|"$0}' | log

echo "$striptracks_json_processed" | awk -v Debug=$striptracks_debug \
-v OrgVideo="$striptracks_video" \
-v TempVideo="$striptracks_tempvideo" \
-v MKVVideo="$striptracks_newvideo" \
-v Title="$striptracks_title" \
-v AudioKeep="$striptracks_audiokeep" \
-v SubsKeep="$striptracks_subskeep" '
BEGIN {
  MKVMerge="/usr/bin/mkvmerge"
  FS="[\t\n: ]"
  IGNORECASE=1
}
/^Track ID/ {
  FieldCount=split($0, Fields)
  if (Fields[1]=="Track") {
    NoTr++
    Track[NoTr, "id"]=Fields[3]
    Track[NoTr, "typ"]=Fields[5]
    if (Fields[6]~/^\(/) {
      Track[NoTr, "code"]=substr(Line,1,match(Line,/\)/))
      sub(/^[^\(]+/,"",Track[NoTr, "code"])
    }
    if (Track[NoTr, "typ"]=="video") VidCnt++
    if (Track[NoTr, "typ"]=="audio") AudCnt++
    if (Track[NoTr, "typ"]=="subtitles") SubsCnt++
    for (i=6; i<=FieldCount; i++) {
      if (Fields[i]=="language") Track[NoTr, "lang"]=Fields[++i]
    }
  }
}
/^Chapters/ {
  Chapters=$3
}
END {
  if (!NoTr) { print "Error|No tracks found in \""TempVideo"\"" > "/dev/stderr"; exit }
  if (!AudCnt) AudCnt=0; if (!SubsCnt) SubsCnt=0
  print "Info|Original tracks: "NoTr" (audio: "AudCnt", subtitles: "SubsCnt")"
  if (Chapters) print "Info|Chapters: "Chapters
  for (i=1; i<=NoTr; i++) {
    if (Debug) print "Debug|i:"i,"Track ID:"Track[i,"id"],"Type:"Track[i,"typ"],"Lang:"Track[i, "lang"],"Code:"Track[i, "code"]
    if (Track[i, "typ"]=="audio") {
      if (AudioKeep~Track[i, "lang"]) {
        AudKpCnt++
        print "Info|Keeping audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "code"]
        if (AudioCommand=="") {
          AudioCommand=Track[i, "id"]
        } else {
          AudioCommand=AudioCommand","Track[i, "id"]
        }
      # Special case if there is only one audio track, even if it was not specified
      } else if (AudCnt==1) {
        AudKpCnt++
        print "Info|Keeping only audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "code"]
        AudioCommand=Track[i, "id"]
      # Special case if there were multiple tracks, none were selected, and this is the last one.
      } else if (AudioCommand=="" && Track[i, "id"]==AudCnt) {
        AudKpCnt++
        print "Info|Keeping last audio track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "code"]
        AudioCommand=Track[i, "id"]
      } else {
        if (Debug) print "Debug|\tRemove:", Track[i, "typ"], "track", Track[i, "id"], Track[i, "lang"]
      }
    } else {
      if (Track[i, "typ"]=="subtitles") {
        if (SubsKeep~Track[i, "lang"]) {
          SubsKpCnt++
          print "Info|Keeping subtitle track "Track[i, "id"]": "Track[i, "lang"]" "Track[i, "code"]
          if (SubsCommand=="") {
            SubsCommand=Track[i, "id"]
          } else {
            SubsCommand=SubsCommand","Track[i, "id"]
          }
        } else {
          if (Debug) print "Debug|\tRemove:", Track[i, "typ"], "track", Track[i, "id"], Track[i, "lang"]
        }
      }
    }
  }
  if (!AudKpCnt) AudKpCnt=0; if (!SubsKpCnt) SubsKpCnt=0
  print "Info|Kept tracks: "AudKpCnt+SubsKpCnt+VidCnt" (audio: "AudKpCnt", subtitles: "SubsKpCnt")"
  if (AudioCommand=="") {
    # This should never happen, but belt and suspenders
    CommandLine="-A"
  } else {
    CommandLine="-a "AudioCommand
  }
  if (SubsCommand=="") {
    CommandLine=CommandLine" -S"
  } else {
    CommandLine=CommandLine" -s "SubsCommand
  }
  if (Debug) print "Debug|Executing: nice "MKVMerge" --title \""Title"\" -q -o \""MKVVideo"\" "CommandLine" \""TempVideo"\""
  Result=system("nice "MKVMerge" --title \""Title"\" -q -o \""MKVVideo"\" "CommandLine" \""TempVideo"\"")
  if (Result>1) print "Error|"Result" remuxing \""TempVideo"\"" > "/dev/stderr"
}' | log

#### END MAIN

# Check for script completion and non-empty file
if [ -s "$striptracks_newvideo" ]; then
  # Use Recycle Bin if configured
  if [ "$striptracks_recyclebin" ]; then
    [ $striptracks_debug -eq 1 ] && echo "Debug|Recycling: \"$striptracks_tempvideo\" to \"${striptracks_recyclebin%/}/$(basename "$striptracks_video")"\" | log
    mv "$striptracks_tempvideo" "${striptracks_recyclebin%/}/$(basename "$striptracks_video")" 2>&1 | log
    striptracks_return=$?; [ "$striptracks_return" != 0 ] && {
      striptracks_message="ERROR[$striptracks_return]: Unable to move video: \"$striptracks_tempvideo\" to Recycle Bin: \"${striptracks_recyclebin%/}\""
      echo "$striptracks_message" | log
      echo "$striptracks_message" >&2
    }
  else
    [ $striptracks_debug -eq 1 ] && echo "Debug|Deleting: \"$striptracks_tempvideo\"" | log
    rm "$striptracks_tempvideo" 2>&1 | log
  fi
else
  striptracks_message="Error|Unable to locate or invalid remuxed file: \"$striptracks_newvideo\". Undoing rename."
  echo "$striptracks_message" | log
  echo "$striptracks_message" >&2
  [ $striptracks_debug -eq 1 ] && echo "Debug|Renaming: \"$striptracks_tempvideo\" to \"$striptracks_video\"" | log
  mv -f "$striptracks_tempvideo" "$striptracks_video" 2>&1 | log
  exit 10
fi

striptracks_filesize=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_newvideo"))
striptracks_message="Info|New size: $striptracks_filesize"
echo "$striptracks_message" | log

#### Call Radarr/Sonarr API to RescanMovie/RescanSeries
# Check for URL
if [ -n "$striptracks_api_url" ]; then
  # Check for video IDs
  if [ "$striptracks_video_id" -a "$striptracks_videofile_id" ]; then
    # Get video file info
    if get_videofile_info; then
      # Save original quality
      striptracks_original_quality=$(echo $striptracks_result | jq -crM .quality)
      [ $striptracks_debug -eq 1 ] && echo "Debug|Detected quality '$(echo $striptracks_original_quality | jq -crM .quality.name)'." | log
      # Loop a maximum of twice
      #  Radarr needs to Rescan twice when the file extension changes
      #  (.avi -> .mkv for example)
      for ((i=1; $i <= 2; i++)); do
        # Scan the disk for the new movie file
        if rescan; then
          # Give it a beat
          sleep 1
          # Check that the Rescan completed
          if check_rescan; then
            # Get new video file id
            if get_video_info; then
              # Get new video file ID
              striptracks_videofile_id=$(echo $striptracks_result | jq -crM ${striptracks_json_quality_root}.id)
              [ $striptracks_debug -eq 1 ] && echo "Debug|Set new video file id '$striptracks_videofile_id'." | log
              # Get new video file info
              if get_videofile_info; then
                # Check that the file didn't get lost in the Rescan.
                # If we lost the quality information, put it back
                if [ "$(echo $striptracks_result | jq -crM .quality.quality.name)" != "$(echo $striptracks_original_quality | jq -crM .quality.name)" ]; then
                  [ $striptracks_debug -eq 1 ] && echo "Debug|Updating from quality '$(echo $striptracks_result | jq -crM .quality.quality.name)' to '$(echo $striptracks_original_quality | jq -crM .quality.name)'. Calling ${striptracks_type^} API using PUT and URL '$striptracks_api_url/v3/$striptracks_videofile_api/editor'" | log
                  striptracks_result=$(curl -s -H "X-Api-Key: $striptracks_apikey" -H "Content-Type: application/json" \
                    -d "{\"${striptracks_videofile_api}Ids\":[${striptracks_videofile_id}],\"quality\":$striptracks_original_quality}" \
                    -X PUT "$striptracks_api_url/v3/$striptracks_videofile_api/editor")
                  [ $striptracks_debug -eq 1 ] && echo "API returned: $striptracks_result" | awk '{print "Debug|"$0}' | log
                  # Check that the returned result shows the update
                  if [ "$(echo $striptracks_result | jq -crM .[].quality.quality.name)" = "$(echo $striptracks_original_quality | jq -crM .quality.name)" ]; then
                    # Updated successfully
                    [ $striptracks_debug -eq 1 ] && echo "Debug|Successfully updated quality to '$(echo $striptracks_result | jq -crM .[].quality.quality.name)'." | log
                    break
                  else
                    striptracks_message="Warn|Unable to update ${striptracks_type^} $striptracks_video_api '$striptracks_title' to quality '$(echo $striptracks_original_quality | jq -crM .quality.name)'"
                    echo "$striptracks_message" | log
                    echo "$striptracks_message" >&2
                  fi
                else
                  # The quality is already correct
                  [ $striptracks_debug -eq 1 ] && echo "Debug|Quality of '$(echo $striptracks_original_quality | jq -crM .quality.name)' remained unchanged." | log
                  break
                fi
              else
                # No '.path' in returned JSON
                striptracks_message="Warn|The '$striptracks_videofile_api' API with ${striptracks_video_api}File id $striptracks_videofile_id returned no path."
                echo "$striptracks_message" | log
                echo "$striptracks_message" >&2
              fi
            else
              # 'hasFile' is False in returned JSON.
              striptracks_message="Warn|The '$striptracks_video_api' API with id $striptracks_video_id returned a false hasFile (Normal with Radarr on try #1)."
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
