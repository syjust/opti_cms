#!/bin/bash

#################
# ENVIRONNEMENT #
#################
export jpg_cmd="jpegoptim"
export jpg_min_version="1.2.0"
export jpg_opt=" -m90 --strip-all"
export jpg_bench_opt="
    -m90_--strip-all_--dest=%1
    -m80_--strip-all_--dest=%1
    -m70_--strip-all_--dest=%1
    -m60_--strip-all_--dest=%1
    -m50_--strip-all_--dest=%1
    -m40_--strip-all_--dest=%1
    -m30_--strip-all_--dest=%1
    -m20_--strip-all_--dest=%1
    -m10_--strip-all_--dest=%1
"

export png_cmd="optipng"
export png_min_version="0.7.5"
export png_opt=" -o5 -strip all"
export png_bench_opt="
    -o2_-strip_all_-dir_%1
    -o3_-strip_all_-dir_%1
    -o4_-strip_all_-dir_%1
    -o5_-strip_all_-dir_%1
    -o6_-strip_all_-dir_%1
    -o7_-strip_all_-dir_%1
    -o7_-zm1-9_-strip_all_-dir_%1
"

export OPTIMIZED_FILE_NAME="./`basename ${0/.sh/.txt}`"
export default_path="./"

###################
# Basic Functions #
###################

function quit() {
    echo
	echo -e "ERROR: $1"
    usage
	exit 1
}

function usage() {
    echo
    echo "USAGE : $0 [OPTIONS] [PATH_OR_FILE]"
    echo
    echo "WHERE OPTIONS are :"
    echo "-h|--help      print this message and exit"
    echo "-t|--test      dry run (do not apply changes) - NOT YET ALREADY IMPLEMENTED"
    echo "-f|--force     force overwrite already existing images - NOT YET ALREADY IMPLEMENTED"
    echo "-d|--debug     debug mode (very verbose) - NOT YET ALREADY IMPLEMENTED"
    echo "-b|--benchmark test series of compression on a single file (single file arg is required)"
    echo
    echo "AND WEHRE PATH_OR_FILE can be :"
    echo "  * a single folder"
    echo "  * a list of folders"
    echo "  * a single file"
    echo "  * a list of file"
    echo "Default is current folder : $default_path"
    echo
}

function debug() {
    if [ $DEBUG -eq 1 ] ; then
        echo -e "DEBUG: $1"
    fi
}

export -f quit
export -f usage
export -f debug

################################
# ARGUMENTS (OPTIONS & PATHES) #
################################
TEST=0
DEBUG=0
BENCHMARK=0
FORCE=0
while [ ! -z $1 -a "x-" == "x${1:0:1}" ] ; do
    case $1 in
        -h|--help)      usage       ; exit 0 ;;
        -t|--test)      TEST=1      ; shift ;;
        -d|--debug)     DEBUG=1     ; shift ;;
        -f|--force)     FORCE=1     ; shift ;;
        -b|--benchmark) BENCHMARK=1 ; shift ;;
        *) quit "'$1' bad argument" ;;
    esac
done

if [ ! -z "$1" ] ; then
	PATHES="$@"
else
	PATHES="$default_path"
fi

##################
# Test Functions #
##################

function pngVersion() {
    echo `$png_cmd --version | awk '$1 ~ /OptiPNG/ {print $3}'`
}

function jpgVersion() {
    echo `$jpg_cmd --version | awk '$1 ~ /jpegoptim/ {print $2}' | sed 's/^v//;'`
}

export -f pngVersion
export -f jpgVersion

#########
# Tests #
#########
for i in {jpg,png} ; do
    cmd="${i}_cmd"
    min_version="${i}_min_version"
    get_version="${i}Version"
	x=`which ${!cmd}`
	[ -z "$x" ] && quit "'${!cmd}' ($cmd) Not found"
	[ -x "$x" ] || quit "'$x' is not executable"
	debug "$cmd (${!cmd}) => $x : executable found !"
    version="`$get_version`"
    if [ ${version//./} -lt ${!min_version//./} ] ; then
        quit "Min version '$min_version' of ${!cmd} ($cmd) is requiered. '$version' was found !"
    else
        debug "${!cmd} ($cmd) version is ok : '$version' >= '$min_version'"
    fi
done
[ ! -e $OPTIMIZED_FILE_NAME ] && touch $OPTIMIZED_FILE_NAME
[ ! -e $OPTIMIZED_FILE_NAME ] && quit "$OPTIMIZED_FILE_NAME not exists"

####################
# Script Functions #
####################
function optimize() {
	local type="$1"
	local file="$2"
    local with="optimIt"
    if [ $BENCHMARK -eq 1 ] ; then
        with="benchIt"
    fi
	if [ -e "$file" ] ; then
		case $type in
			jpg) jpgIze $with "$file" || pngIze $with "$file" ;;
			png) pngIze $with "$file" || jpgIze $with "$file" ;;
		esac
	else
		echo "'$file' not found" >&2
		return 1
	fi
}

# jpgIze
#
# @param $1 as $with cmd (optimIt or benchIt)
# @param $2 as $file as file to optim / bench
#
function jpgIze() {
	$1 jpg_cmd jpg_opt "$2"
}

# pngIze
#
# @param $1 as $with cmd (optimIt or benchIt)
# @param $2 as $file as file to optim / bench
#
function pngIze() {
	$1 png_cmd png_opt "$2"
}

# optimIt
#
# @param $1 as $cmd (jpg_cmd or png_cmd)
# @param $2 as $opt (jpg_opt or png_opt)
# @param $3 as $file as file to optim
#
function optimIt() {
	local cmd="${!1}"
	local opt="${!2}"
	local file="$3"
    local f=`egrep "$file:....-..-..:(jpg|png):optim:$opt$" $OPTIMIZED_FILE_NAME`
    if [ ! -z "$f" ] ; then
        echo "$f" \
            | sed 's/^\(.*\):\(....-..-..\):\(jpg\|png\):optim:\('"$opt"'\)$/file "\1" already optimized at "\2" as "\3" fileType with following options "\4"./'
    else
        $cmd $opt "$file" && echo "$file:`date "+%Y-%m-%d"`:${1%%_*}:optim:$opt" >> $OPTIMIZED_FILE_NAME
    fi
}

# benchIt
#
# @param $1 as $cmd (jpg_cmd or png_cmd)
# @param $2 as $opt (jpg_opt or png_opt)
# @param $3 as $file as file to bench
#
function benchIt() {
	local cmd="${!1}"
	local options="${!2}"
	local file="$3"
    local ext="${file##*.}"
    local d f dest ret mk=0
    for opts in $options ; do
        f=`egrep "$file:....-..-..:(jpg|png):bench:$opts$" $OPTIMIZED_FILE_NAME`
        if [ ! -z "$f" ] ; then
            echo "$f" \
                | sed 's/^\(.*\):\(....-..-..\):\(jpg\|png\):bench:\('"$opts"'\)$/file "\1" already benchmarked at "\2" as "\3" fileType with following options "\4"./'
        else
            dest="$1/`echo "${opts}" | sed 's/\(-\|=\|%1\)//g;s/_$//'`"
            [ ! -d "$dest" ] && mk=1 && mkdir -p $dest
            opt="`echo "${opts//_/ }" | sed 's#%1#'"$dest"'#'`"
            $cmd $opt "$file"
            ret=$?
            if [ $ret -eq 0 ] ; then
                echo "$file:`date "+%Y-%m-%d"`:${1%%_*}:bench:$opts" >> $OPTIMIZED_FILE_NAME
            else
                # dir was just created but cmd failed
                if [ $mk -eq 1 ] ; then
                    for d in $dest $1 ; do
                        # test if dir is empty, then remove it
                        [ "$(ls -A $d)" ] || rm -r $d
                    done
                fi
                return $ret
            fi
        fi
    done
}

export -f optimize
export -f jpgIze
export -f pngIze
export -f optimIt
export -f benchIt

################
# START SCRIPT #
################
if [ $BENCHMARK -eq 1 ] ; then
    # ensure that a file is passed as argument
    [ -f "$PATHES" ] || quit "'$PATHES' is not a valid file : --benchmark need a single file as argument !!!"
    # define bench_opt as default
    export jpg_opt="$jpg_bench_opt"
    export png_opt="$png_bench_opt"
    # launch default as jpg even if it's a png because it will be launched as well in fine.
    echo "BENCHMARK on '$PATHES'"
    optimize jpg "$PATHES"
else
    for path in $PATHES ; do
        find $path -iname "*jpg" -exec bash -c 'optimize "$0" "$1"' jpg {} \;
        find $path -iname "*jpeg" -exec bash -c 'optimize "$0" "$1"' jpg {} \;
        find $path -iname "*png" -exec bash -c 'optimize "$0" "$1"' png {} \;
    done
fi
