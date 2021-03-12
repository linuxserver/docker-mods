#!/bin/bash

# Video remuxing script designed for use with Radarr and Sonarr
# Automatically strips out unwanted audio and subtitle streams, keeping only the desired languages.
#  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks
#  Dev/test: https://github.com/TheCaptain989/radarr-striptracks

# Adapted and corrected from Endoro's post 1/5/2014:
#  https://forum.videohelp.com/threads/343271-BULK-remove-non-English-tracks-from-MKV-container#post2292889
#
# Put a colon `:` in front of every language code.  Expects ISO639-2 codes

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
export striptracks_type=$(printenv | sed -n 's/_eventtype *=.*$//p')
if [[ "${striptracks_type,,}" = "radarr" ]]; then
  export striptracks_video="$radarr_moviefile_path"
  export striptracks_api_endpoint="movie"
  export striptracks_json_quality_root=".movieFile"
  export striptracks_video_type="movie"
  export striptracks_title="$radarr_movie_title ($radarr_movie_year)"
elif [[ "${striptracks_type,,}" = "sonarr" ]]; then
  export striptracks_video="$sonarr_episodefile_path"
  export striptracks_api_endpoint="episodefile"
  export striptracks_json_quality_root=""
  export striptracks_video_type="series"
  export striptracks_title="$sonarr_series_title $(numfmt --format "%02f" ${sonarr_episodefile_seasonnumber:-0})x$(numfmt --format "%02f" ${sonarr_episodefile_episodenumbers:-0}) - $sonarr_episodefile_episodetitles"
else
  echo "Unknown environment: ${striptracks_type}"
  exit 7
fi
export striptracks_api="Rescan${striptracks_video_type^}"
export striptracks_json_key="${striptracks_video_type}Id"
export striptracks_api_endpoint_idname="${striptracks_type,,}_${striptracks_api_endpoint}_id"
export striptracks_api_endpoint_id="${!striptracks_api_endpoint_idname}"
export striptracks_video_idname="${striptracks_type,,}_${striptracks_video_type}_id"
export striptracks_video_id="${!striptracks_video_idname}"
export striptracks_eventtype="${striptracks_type,,}_eventtype"
export striptracks_tempvideo="${striptracks_video}.tmp"
export striptracks_newvideo="${striptracks_video%.*}.mkv"
export striptracks_db="/config/${striptracks_type,,}.db"
if [ ! -f "$striptracks_db" ]; then
  striptracks_db=/config/nzbdrone.db
fi
export striptracks_recyclebin=$(sqlite3 $striptracks_db 'SELECT Value FROM Config WHERE Key="recyclebin"')
RET=$?; [ "$RET" != 0 ] && >&2 echo "WARNING[$RET]: Unable to read recyclebin information from database \"$striptracks_db\""

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
  >&2 echo "$usage"
}
# Can still go over striptracks_maxlog if read line is too long
#  Must include whole function in subshell for read to work!
function log {(
  while read
  do
    echo $(date +"%Y-%-m-%-d %H:%M:%S.%1N")\|"[$striptracks_pid]$REPLY" >>"$striptracks_log"
    local FILESIZE=$(stat -c %s "$striptracks_log")
    if [ $FILESIZE -gt $striptracks_maxlogsize ]
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
  read -d \< ENTITY CONTENT
}
# Get video information
function get_video_info {
  [ $striptracks_debug -eq 1 ] && echo "Debug|Getting video information for $striptracks_api_endpoint '$striptracks_api_endpoint_id'. Calling ${striptracks_type^} API using GET and URL 'http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/$striptracks_api_endpoint/$striptracks_api_endpoint_id?apikey=(removed)'" | log
  RESULT=$(curl -s -H "Content-Type: application/json" \
    -X GET http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/$striptracks_api_endpoint/$striptracks_api_endpoint_id?apikey=$striptracks_apikey)
  [ $striptracks_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
  if [ "$(echo $RESULT | jq -crM .path)" != "null" ]; then
    local RET=0
  else
    local RET=1
  fi
  return $RET
}
# Initiate API Rescan request
function rescan {
  MSG="Info|Calling ${striptracks_type^} API to rescan ${striptracks_video_type}, try #$i"
  echo "$MSG" | log
  [ $striptracks_debug -eq 1 ] && echo "Debug|Forcing rescan of $striptracks_json_key '$striptracks_video_id', try #$i. Calling ${striptracks_type^} API '$striptracks_api' using POST and URL 'http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/command?apikey=(removed)'" | log
  RESULT=$(curl -s -d "{name: '$striptracks_api', $striptracks_json_key: $striptracks_video_id}" -H "Content-Type: application/json" \
    -X POST http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/command?apikey=$striptracks_apikey)
  [ $striptracks_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
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
    [ $striptracks_debug -eq 1 ] && echo "Debug|Checking job $JOBID completion, try #$i. Calling ${striptracks_type^} API using GET and URL 'http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/command/$JOBID?apikey=(removed)'" | log
    RESULT=$(curl -s -H "Content-Type: application/json" \
      -X GET http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/command/$JOBID?apikey=$striptracks_apikey)
    [ $striptracks_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
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
while getopts ":d" opt; do
  case ${opt} in
    d ) # For debug purposes only
      MSG="Debug|Enabling debug logging."
      echo "$MSG" | log
      >&2 echo "$MSG"
      striptracks_debug=1
      printenv | sort | sed 's/^/Debug|/' | log
    ;;
  esac
done
shift $((OPTIND -1))

# Check for required command line options
if [ -z "$1" ]; then
  MSG="Error|No audio languages specified!"
  echo "$MSG" | log
  >&2 echo "$MSG"
  usage
  exit 2
fi

if [ -z "$2" ]; then
  MSG="Error|No subtitles languages specified!"
  echo "$MSG" | log
  >&2 echo "$MSG"
  usage
  exit 3
fi

# Check for required binaries
if [ ! -f "/usr/bin/mkvmerge" ]; then
  MSG="Error|/usr/bin/mkvmerge is required by this script"
  echo "$MSG" | log
  >&2 echo "$MSG"
  exit 4
fi

# Handle Test event
if [[ "${!striptracks_eventtype}" = "Test" ]]; then
  echo "Info|${striptracks_type^} event: ${!striptracks_eventtype}" | log
  echo "Info|Script was test executed successfully." | log
  exit 0
fi

# Check if called from within Radarr/Sonarr
if [ -z "$striptracks_video" ]; then
  MSG="Error|No video file specified! Not called from Radarr/Sonarr?"
  echo "$MSG" | log
  >&2 echo "$MSG"
  usage 
  exit 1
fi

# Check if source video exists
if [ ! -f "$striptracks_video" ]; then
  MSG="Error|Input file not found: \"$striptracks_video\""
  echo "$MSG" | log
  >&2 echo "$MSG"
  exit 5
fi

#### BEGIN MAIN
FILESIZE=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_video"))
MSG="Info|${striptracks_type^} event: ${!striptracks_eventtype}, Video: $striptracks_video, Size: $FILESIZE, AudioKeep: $1, SubsKeep: $2"
echo "$MSG" | log

# Rename the original video file to a temporary name
[ $striptracks_debug -eq 1 ] && echo "Debug|Renaming: \"$striptracks_video\" to \"$striptracks_tempvideo\"" | log
mv -f "$striptracks_video" "$striptracks_tempvideo" | log
RET=$?; [ "$RET" != 0 ] && {
  MSG="ERROR[$RET]: Unable to rename video: \"$striptracks_video\" to temp video: \"$striptracks_tempvideo\". Halting."
  echo "$MSG" | log
  >&2 echo "$MSG"
  exit 6
}

# Read in the output of mkvmerge info extraction
[ $striptracks_debug -eq 1 ] && echo "Debug|Executing: /usr/bin/mkvmerge -J \"$striptracks_tempvideo\"" | log
JSON=$(/usr/bin/mkvmerge -J "$striptracks_tempvideo")
RET=$?; [ "$RET" != 0 ] && {
  MSG="ERROR[$RET]: Error executing mkvmerge."
  echo "$MSG" | log
  >&2 echo "$MSG"
}

# This and the modified AWK script are a hack, and I know it.  JQ is crazy hard to learn, BTW.
# Mimic the mkvmerge --identify-verbose option that has been deprecated
JSON_PROCESSED=$(echo $JSON | jq -jcrM '
( if (.chapters | .[] | .num_entries) then
    "Chapters: \(.chapters | .[] | .num_entries) entries\n"
  else
    ""
  end
),
( .tracks |
  .[] |
  ( "Track ID \(.id): \(.type) (\(.codec)) [",
    ( [.properties | to_entries |.[] | "\(.key):\(.value | tostring | gsub(" "; "\\s"))"] | join(" ")),
    "]\n" )
)
')
[ $striptracks_debug -eq 1 ] && echo "$JSON_PROCESSED" | awk '{print "Debug|"$0}' | log

echo "$JSON_PROCESSED" | awk -v Debug=$striptracks_debug \
-v OrgVideo="$striptracks_video" \
-v TempVideo="$striptracks_tempvideo" \
-v MKVVideo="$striptracks_newvideo" \
-v Title="$striptracks_title" \
-v AudioKeep="$1" \
-v SubsKeep="$2" '
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
    [ $striptracks_debug -eq 1 ] && echo "Debug|Moving: \"$striptracks_tempvideo\" to \"${striptracks_recyclebin%/}/$(basename "$striptracks_video")"\" | log
    mv "$striptracks_tempvideo" "${striptracks_recyclebin%/}/$(basename "$striptracks_video")" | log
  else
    [ $striptracks_debug -eq 1 ] && echo "Debug|Deleting: \"$striptracks_tempvideo\"" | log
    rm "$striptracks_tempvideo" | log
  fi
else
  MSG="Error|Unable to locate or invalid remuxed file: \"$striptracks_newvideo\". Undoing rename."
  echo "$MSG" | log
  >&2 echo "$MSG"
  [ $striptracks_debug -eq 1 ] && echo "Debug|Renaming: \"$striptracks_tempvideo\" to \"$striptracks_video\"" | log
  mv -f "$striptracks_tempvideo" "$striptracks_video" | log
  exit 10
fi

FILESIZE=$(numfmt --to iec --format "%.3f" $(stat -c %s "$striptracks_newvideo"))
MSG="Info|New size: $FILESIZE"
echo "$MSG" | log

# Call Radarr/Sonarr API to RescanMovie/RescanSeries
if [ -f "$striptracks_arr_config" ]; then
  # Read *arr config.xml
  while read_xml; do
    [[ $ENTITY = "Port" ]] && striptracks_port=$CONTENT
    [[ $ENTITY = "UrlBase" ]] && striptracks_urlbase=$CONTENT
    [[ $ENTITY = "BindAddress" ]] && striptracks_bindaddress=$CONTENT
    [[ $ENTITY = "ApiKey" ]] && striptracks_apikey=$CONTENT
  done < $striptracks_arr_config

  [[ $striptracks_bindaddress = "*" ]] && striptracks_bindaddress=localhost
  
  # Check for video ID
  if [ "$striptracks_video_id" ]; then
    # Call API
    if [ "${striptracks_type,,}" = "radarr" ] && get_video_info; then
      # Save original quality
      ORGQUALITY=$(echo $RESULT | jq -crM ${striptracks_json_quality_root}.quality)
    fi
    # Loop a maximum of twice
    for ((i=1; $i <= 2; i++)); do
      # Scan the disk for the new movie file
      if rescan; then
        # Check that the Rescan completed
        if check_rescan; then
          # This whole section doesn't work under Sonarr because the episodefile_id changes after the RescanSeries if the filename changes
          # Should look into just using a PUT to change everything at once instead of a Rescan.
          if [ "${striptracks_type,,}" = "radarr" ]; then
            if get_video_info; then
              # Check that the file didn't get lost in the Rescan.
              #  Radarr sometimes needs to Rescan twice when the file extension changes
              #  (.avi -> .mkv for example)
              if [ "$(echo $RESULT | jq -crM .hasFile)" = "true" ]; then
                # If we lost the quality information, put it back
                #  NOTE: This "works" with Radarr in that the change shows up in the GUI, but only until the page changes.
                #  It doesn't seem to write the info permanently. Maybe an API bug?
                if [ "$(echo $RESULT | jq -crM ${striptracks_json_quality_root}.quality.quality.name)" = "Unknown" ]; then
                  [ $striptracks_debug -eq 1 ] && echo "Debug|Updating quality to '$(echo $ORGQUALITY | jq -crM .quality.name)'. Calling ${striptracks_type^} API using PUT and URL 'http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/$striptracks_api_endpoint/$striptracks_video_id?apikey=(removed)'" | log
                  RESULT=$(curl -s -d "$(echo $RESULT | jq -crM "${striptracks_json_quality_root}.quality=$ORGQUALITY")" -H "Content-Type: application/json" \
                    -X PUT http://$striptracks_bindaddress:$striptracks_port$striptracks_urlbase/api/$striptracks_api_endpoint/$striptracks_video_id?apikey=$striptracks_apikey)
                  [ $striptracks_debug -eq 1 ] && echo "API returned: $RESULT" | awk '{print "Debug|"$0}' | log
                  if [ "$(echo $RESULT | jq -crM ${striptracks_json_quality_root}.quality.quality.name)" = "Unknown" ]; then
                    MSG="Warn|Unable to update ${striptracks_type^} $striptracks_api_endpoint '$striptracks_title' to quality '$(echo $ORGQUALITY | jq -crM .quality.name)'"
                    echo "$MSG" | log
                    >&2 echo "$MSG"
                  fi
                fi
                # The video record is [now] good
                break
              else
                # Loop again because there was no file
                continue
              fi
            else
              # No 'path' in returned JSON.
              MSG="Warn|The '$striptracks_api' API with $striptracks_api_endpoint $striptracks_api_endpoint_id returned no path."
              echo "$MSG" | log
              >&2 echo "$MSG"
            fi
          else
            # Didn't do anything because we're in Sonarr
            break
          fi
        else
          # Timeout or failure
          MSG="Warn|${striptracks_type^} job ID $JOBID timed out or failed."
          echo "$MSG" | log
          >&2 echo "$MSG"
        fi
      else
        # Error from API
        MSG="Error|The '$striptracks_api' API with $striptracks_json_key $striptracks_video_id failed."
        echo "$MSG" | log
        >&2 echo "$MSG"
      fi
    done
  else
    # No video ID means we can't call the API
    MSG="Warn|Missing environment variable: $striptracks_video_idname"
    echo "$MSG" | log
    >&2 echo "$MSG"
  fi
else
  # No config file means we can't call the API
  MSG="Warn|Unable to locate ${striptracks_type^} config file: '$striptracks_arr_config'"
  echo "$MSG" | log
  >&2 echo "$MSG"
fi

# Cool bash feature
MSG="Info|Completed in $(($SECONDS/60))m $(($SECONDS%60))s"
echo "$MSG" | log
