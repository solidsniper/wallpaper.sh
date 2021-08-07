#!/usr/bin/env bash
# PATH is needed for crontabs on McOS
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

link="https://source.unsplash.com/random/"

if [ -z ${XDG_CONFIG_HOME+x} ]
then
    XDG_CONFIG_HOME="${HOME}/Library/Preferences/.config"
fi
[ ! -d "${HOME}/Library/Caches/.cache" ] && mkdir "${HOME}/Library/Caches/.cache"
if [ -z ${XDG_CACHE_HOME+x} ]
then
    XDG_CACHE_HOME="${HOME}/Library/Caches/.cache"
fi
confdir="${XDG_CONFIG_HOME}"
if [ ! -d "${confdir}" ]
then
    mkdir -p "${confdir}"
fi
cachedir="${XDG_CACHE_HOME}/wallpaper.sh"
find ${cachedir} -name "*.jpg" -exec rm {}  \; &> /dev/null
if [ ! -d "${cachedir}" ]
then
    mkdir -p "${cachedir}"
fi
export LC_ALL=C
UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)

reddit(){
    useragent="thevinter"
    timeout=60
    if [ ! -f "${confdir}/subreddits" ]
    then
        echo "Please install the subreddits file in ${confdir}"
        exit 2
    fi
    readarray subreddits < "${confdir}/subreddits"
    a=${#subreddits[@]}
    b=$(($RANDOM % $a))
    sub=${subreddits[$b]}
    sort=$2
    top_time=$3
    if [ -z $sort   ]; then
        sort="hot"
    fi

    if [ -z $top_time   ]; then
        top_time=""
    fi
    sub="$(echo -e "${sub}" | tr -d '[:space:]')"
    if [ ! -z $1 ]; then
        sub=$1
    fi
    url="https://www.reddit.com/r/$sub/$sort/.json?raw_json=1&t=$top_time"
    content=`wget -T $timeout -U "$useragent" -q -O - $url`
    urls=$(echo -n "$content"| jq -r '.data.children[]|select(.data.post_hint|test("image")?) | .data.preview.images[0].source.url')
    names=$(echo -n "$content"| jq -r '.data.children[]|select(.data.post_hint|test("image")?) | .data.title')
    ids=$(echo -n "$content"| jq -r '.data.children[]|select(.data.post_hint|test("image")?) | .data.id')
    arrURLS=($urls)
    arrNAMES=($names)
    arrIDS=($ids)
    wait # prevent spawning too many processes
    size=${#arrURLS[@]}
    if [ $size -eq 0 ]; then
        echo The current subreddit is not valid.
        exit 1
    fi
    idx=$(($RANDOM % $size))
    target_url=${arrURLS[$idx]}
    target_name=${arrNAMES[$idx]}
    target_id=${arrIDS[$idx]}
    ext=`echo -n "${target_url##*.}"|cut -d '?' -f 1`
    newname=`echo $target_name | sed "s/^\///;s/\// /g"`_"$subreddit"_$target_id.$ext
    wget -T $timeout -U "$useragent" --no-check-certificate -q -P down -O "${cachedir}/wallpaper"${UUID}".jpg" $target_url &>/dev/null
}

unsplash() {
    local search="${search// /_}"

    if [ ! -z $height ] || [ ! -z $width ]; then
        link="${link}${width}x${height}";
    else
        link="${link}1920x1080";
    fi

    if [ ! -z $search ]
    then
        link="${link}/?${search}"
    fi
    wget -q -O "${cachedir}/wallpaper"${UUID}".jpg" $link
}

usage(){
    echo "Usage: wallpaper.sh   [-s | --search <string>]
                            [-h | --height <height>]
                            [-w | --width <width>]
                            [-r | --subreddit <subreddit>]
                            [-l | --link <source>]
                            [-d | --directory]"
    exit 2
}

set_wallpaper_one() {
    osascript -e 'tell application "Finder" to set desktop picture to POSIX file "'"${cachedir}/wallpaper"${UUID}".jpg"'"'
}

set_wallpaper() {
    osascript -e 'tell application "System Events" to tell every desktop to set picture to "'"${cachedir}/wallpaper"${UUID}".jpg"'"'
}

set=true

PARSED_ARGUMENTS=$("$(brew --prefix gnu-getopt)"/bin/getopt -a -n $0 -o h:w:s:l:r:c:d:m:pkn --long search:,height:,width:,subreddit:,link -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
    usage
    exit
fi
while :
do
    case "${1}" in
        -s | --search)    search=${2} ; shift 2 ;;
        -h | --height)    height=${2} ; shift 2 ;;
        -w | --width)     width=${2} ; shift 2 ;;
        -l | --link)      link=${2} ; shift 2 ;;
        -r | --subreddit) sub=${2} ; shift 2 ;;
        -- | '') shift; break ;;
        *) echo "Unexpected option: $1 - this should not happen." ; usage ;;
    esac
done

if [ -z $dir ]; then
    if [ $link = "reddit" ] || [ ! -z $sub ]; then
        reddit "$sub"
    else
        unsplash
    fi
fi

if [ $set = true ]; then
	set_wallpaper
fi
