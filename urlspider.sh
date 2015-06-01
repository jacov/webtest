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

# TODO: set in conf
export OUTDIR='outdir'
export WGETLOG="$OUTDIR/wgetlog.txt"
#--# export URLS="urls.txt"
#--# export URLS="$OUTDIR/urls.txt"
export URLS_ASSETS="$OUTDIR/urls_assets.txt"
export URLS_ASSETS_TMP="$OUTDIR/urls_assets_tmp.txt"
export URLS_ALL="$OUTDIR/urls_all.txt"


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




mkdir -p $OUTDIR

# crawl site and find all urls
wget --spider --recursive --no-verbose --output-file=${WGETLOG} ${SITE2CRAWL} &

echo "
	Crawl Started: $(date) 

	crawling for $CRAWLTIME seconds.

	Estimated End Time: $(date -j -v +${CRAWLTIME}S)

	For progress, run the following command:
	  # watch -d 'wc -l $OUTDIR/* ; echo ; ls -ltr $OUTDIR'


crawling site, please wait...

"

sleep $CRAWLTIME
kill %1

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

# extract URLs from wget log
cat ${WGETLOG} | grep -a "URL:" | awk '{print $3}' | sed -e 's/URL://g' | grep -v '^$' | sort -u > ${URLS}


# find all external http calls and assets in source, this will take time depending on the amount of URLs
echo "...
finding all external http calls and assets in source, 
this will take time depending on the amount of URLs

please wait..."
cat /dev/null > $URLS_ASSETS_TMP
cat ${URLS} | while read url
do
	curl -s $url | grep href | sed -e 's/.*href="//' -e 's/".*//' | grep '^[a-zA-Z].*' | sort -u | grep "http" >> $URLS_ASSETS_TMP
done

# extract unique URLs from assets and external URLs
cat $URLS_ASSETS_TMP | sort -u > $URLS_ASSETS


# combine all unique URLs into one file
cat $URLS $URLS_ASSETS | sort -u > $URLS_ALL

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

exit 0

