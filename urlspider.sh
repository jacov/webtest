#!/bin/bash
#
# Author: Jacob Baloul <jacob.baloul@acauia.com>
# Date: May 29th, 2015
# Description: Script to crawl a site and extract all URLs
#
#

export SITE2CRAWL=$1
export CRAWLTIME=$2
export URLS="$3"

# OVERRIDES set in conf
#export OUTDIR='outdir'
#export WGETLOG="$OUTDIR/wgetlog.txt"
#--# export URLS="urls.txt"
#--# export URLS="$OUTDIR/urls.txt"
#export URLS_ASSETS="$OUTDIR/urls_assets.txt"
#export URLS_ASSETS_TMP="$OUTDIR/urls_assets_tmp.txt"
#export URLS_ALL="$OUTDIR/urls_all.txt"


# to avoid sed errors on non standard chars
export LC_CTYPE=C 
export LANG=C


if test -z "$1"
then
	echo "
	USAGE:
	./$(basename $0) <site-to-crawl> <crawl-time-seconds> <urls-file>

	Example 2 minute crawl:
	./$(basename $0) http://www.si.com 120 urls.txt

	Example 1 hour crawl:
	./$(basename $0) http://www.si.com 3600 urls.txt

	NOTE:
	The more crawl time specified, the more URLs will be craweled and discovered. 
	Large sites may take a very long time to crawl.

	"
	exit 1
fi

################
# first things first, load conf file
if test -e $PWD/etc/webtest.conf
then
	source $PWD/etc/webtest.conf
	if test $? -gt 0; then
		echo "$0 ERROR: cannot load configuration file @ $PWD/etc/webtest.conf"
		exit 1
	fi
else
	echo "Conf file missing: $PWD/etc/webtest.conf"
	exit 1
fi
################
#
# FUNCTIONS
#
################
function check_error() {
if test $? -gt 0
then
	echo "$0 exited with errors"
	exit 1
fi
}
################
function calcURLs() {
export CURRENT_URL_COUNT="$(cat ${WGETLOG} | grep -a "URL:" | awk '{print $3}' | sed -e 's/URL://g' | grep -v '^$' | sort -u | wc -l | sed -e 's/ //g')"
#--# export URLS_REMAINING="$(echo "$CRAWLCOUNT-$CURRENT_URL_COUNT" |bc)"
}
################

export SpiderLogo='
 ___  ___  ________  ___               ________  ________  ___  ________  _______   ________     
|\  \|\  \|\   __  \|\  \             |\   ____\|\   __  \|\  \|\   ___ \|\  ___ \ |\   __  \    
\ \  \\\  \ \  \|\  \ \  \            \ \  \___|\ \  \|\  \ \  \ \  \_|\ \ \   __/|\ \  \|\  \   
 \ \  \\\  \ \   _  _\ \  \            \ \_____  \ \   ____\ \  \ \  \ \\ \ \  \_|/_\ \   _  _\  
  \ \  \\\  \ \  \\  \\ \  \____        \|____|\  \ \  \___|\ \  \ \  \_\\ \ \  \_|\ \ \  \\  \| 
   \ \_______\ \__\\ _\\ \_______\        ____\_\  \ \__\    \ \__\ \_______\ \_______\ \__\\ _\ 
    \|_______|\|__|\|__|\|_______|       |\_________\|__|     \|__|\|_______|\|_______|\|__|\|__|
                                         \|_________|                                            
'

################
#
# MAIN
#

# capture start time
export CRAWLSTART="$(date)"
export CRAWLEND="$(date -j -v +${CRAWLTIME}S)"

mkdir -p $OUTDIR
check_error

# crawl site and find all urls
#
# wget --spider --recursive --output-file=${WGETLOG} -O - ${URL}

#wget -q ${URL} -O - | \
#    tr "\t\r\n'" '   "' | \
#    grep -i -o '<a[^>]\+href[ ]*=[ \t]*"\(ht\|f\)tps\?:[^"]\+"' | \
#    sed -e 's/^.*"\([^"]\+\)".*$/\1/g' >> ${WGETLOG}

#wget --spider --recursive -q ${URL} -O - 	|  \   
#	tr "\t\r\n'" '   "' 	|  \
#	grep -i -o '<a[^>]\+href[ ]*=[ \t]*"\(ht\|f\)tps\?:[^"]\+"' |  \
#	sed -e 's/^.*"\([^"]\+\)".*$/\1/g' -e 's/.*href="//' -e 's/".*//' | \ 
#	grep '^[a-zA-Z].*'
# JOB1
> ${WGETLOG} # reset wgetlog
wget --spider --recursive --no-verbose --output-file=${WGETLOG} ${SITE2CRAWL} &
export JOB1_PID=$!
disown $JOB1_PID

# JOB2
# give the craweler some time...
sleep $CRAWLTIME &
export JOB2_PID=$!

export JOBSTATUS="RUNNING"

while test "$JOBSTATUS" == "RUNNING"
do 
	calcURLs
	clear
	echo "


	$SpiderLogo


	Crawl Started: $CRAWLSTART 
	Estimated End Time: $CRAWLEND

	Crawling for $CRAWLTIME seconds...

		->> $CURRENT_URL_COUNT URLs found

	spider is crawling site, please wait...
	"
	sleep 5
	
	# test if crawltime sleep command is complete
	# jobs %2 # &>/dev/null 
	ps -p $JOB2_PID &>/dev/null
	if test $? -gt 0
	then
	 echo "Crawler Completed"
	 export JOBSTATUS="DONE"
	fi
done

#--# wait %2 # wait for the crawl time
echo "

=================

Shutting down spider...

"
if test -z "$JOB1_PID"
then
	check_error
	echo "done"
else
	kill -9 $JOB1_PID # kill the crawler
	check_error
	echo "...done"
fi


# extract URLs from wget log
cat ${WGETLOG} | grep -a "URL:" | awk '{print $3}' | sed -e 's/URL://g' | grep -v '^$' | sort -u > ${URLS}
check_error

# find all external http calls and assets in source, this will take time depending on the amount of URLs
echo "
...
finding all external http calls and assets in source, 
this will take time depending on the amount of URLs

please wait...

"
cat /dev/null > $URLS_ASSETS_TMP
check_error
cat ${URLS} | while read url
do
	curl -s $url | grep href | sed -e 's/.*href="//' -e 's/".*//' | grep '^[a-zA-Z].*' | sort -u | grep "http" >> $URLS_ASSETS_TMP
done

# extract unique URLs from assets and external URLs
cat $URLS_ASSETS_TMP | sort -u > $URLS_ASSETS
check_error


# combine all unique URLs into one file
cat $URLS $URLS_ASSETS | sort -u > $URLS_ALL
check_error

echo "

======================

Date: $(date)

$(basename $0) completed successfully!

The following files contain URLs:

$(wc -l $URLS)
$(wc -l $URLS_ASSETS)
$(wc -l $URLS_ALL)

======================
"

check_error

exit 0

