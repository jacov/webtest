#!/bin/bash
#
# Author: Jacob Baloul <jacob.baloul@acquia.com>
# Date: May 29th, 2015
# Script to check url's for http status code, akamai cache, varnish cache
# and combine into a single PDF report

if test -z "$1"
then
	echo "
	USAGE:
	./$(basename $0) <file-with-urls>

	Example:
	./$(basename $0) urls.txt

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
#
#--# VARIABLES / OVERRIDES
# export OUTDIR="$PWD/outdir"
# export URLS="$OUTDIR/urls.txt"
export URLS="$1" # TODO: read from conf
# export RESULTS_CSV="$OUTDIR/results.csv"
#
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
function getHeaders() {

export URL=$1

#curl -sIXGET \
#-A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.91 Safari/537.11" \
#-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
#-H "Accept-Encoding: gzip,deflate,sdch" \
#-H "Accept-Language: en-US,en;q=0.8" \
#-H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" \
#-H "Pragma: akamai-x-cache-on" \
#-H "Pragma: akamai-x-cache-remote-on" \
#-H "Pragma: akamai-x-check-cacheable" \
#-H "Pragma: akamai-x-get-cache-key" \
#-H "Pragma: akamai-x-get-extracted-values" \
#-H "Pragma: akamai-x-get-nonces" \
#-H "Pragma: akamai-x-get-ssl-client-session-id" \
#-H "Pragma: akamai-x-get-true-cache-key" \
#-H "Pragma: akamai-x-serial-no" \
#${URL}


# check if custom cookie is set in conf file
if test -z "${CUSTOM_COOKIE}"
then
	curl --cookie "${CUSTOM_COOKIE}" -sIXGET -H "Pragma: akamai-x-cache-on" ${URL}
else
	curl -sIXGET -H "Pragma: akamai-x-cache-on" ${URL}
fi

}
################
function testAkamaiCache() {
#
# Test hit / miss & write to results file
#
# TODO: move this Legend into Reports
# TCP_HIT: The object was fresh in cache and object from disk cache.
# TCP_MISS: The object was not in cache, server fetched object from origin.
# TCP_REFRESH_HIT: The object was stale in cache and we successfully refreshed with the origin on an If-Modified-Since request.
# TCP_REFRESH_MISS: Object was stale in cache and refresh obtained a new object from origin in response to our IF-Modified-Since request.
# TCP_REFRESH_FAIL_HIT: Object was stale in cache and we failed on refresh (couldn't reach origin) so we served the stale object.
# TCP_IMS_HIT: IF-Modified-Since request from client and object was fresh in cache and served.
# TCP_NEGATIVE_HIT: Object previously returned a "not found" (or any other negatively cacheable response) and that cached response was a hit for this new request.
# TCP_MEM_HIT: Object was on disk and in the memory cache. Server served it without hitting the disk.
# TCP_DENIED: Denied access to the client for whatever reason
# TCP_COOKIE_DENY: Denied access on cookie authentication (if centralized or decentralized authorization feature is being used in configuration)
export AKAMAI_CACHE_CODE=$(echo "$HEADERS" | grep "X-Cache" | awk '{print $2}')  

if test -z "$AKAMAI_CACHE_CODE"
then
	export AKAMAI_CACHE_CODE="AKAMAI_CACHE_CODE_NULL"
else
	export AKAMAI_CACHE_CODE=$(echo "$HEADERS" | grep "X-Cache" | awk '{print $2}')  
fi


}
################
function testVarnishCache() {
#
# Test Varnish hit / miss
#
export VARNISH_CACHE_CODE=$(echo "$HEADERS" | grep "X-Varnish-Cache:" | awk '{print $2}' | tr -d $'\r' )  

if test -z "$VARNISH_CACHE_CODE"
then
	export VARNISH_CACHE_CODE="VARNISH_MISS_NULL"
else
	export VARNISH_CACHE_CODE=$(echo "$HEADERS" | grep "X-Varnish-Cache:" | awk '{print $2}' | tr -d $'\r' )
fi

}
################
function testHTTPStatusCode() {
	# EXAMPLE: HTTP status codes -> HTTP/1.1 200 OK
	export HTTP_STATUS_CODE=$(echo "$HEADERS" | grep "HTTP/" | awk '{print $2}' | tr -d $'\r')  

if test -z "$HTTP_STATUS_CODE"
then
	export HTTP_STATUS_CODE="HTTP_STATUS_CODE_NULL"
else
	export HTTP_STATUS_CODE=$(echo "$HEADERS" | grep "HTTP/" | awk '{print $2}' | tr -d $'\r')  
fi

}
################
function testMaxAge() {
	# EXAMPLE: max-age -> Cache-Control: max-age=0, no-cache 
	export MAX_AGE=$(echo "$HEADERS" | grep "Cache-Control:" | awk '{print $2}' | sed -e 's/max-age=//g' -e 's/,//g' | tr -d $'\r')  
}
################
function testVarnishCacheHits() {
	# EXAMPLE: Varnish Cache Hits -> X-Varnish-Cache-Hits: 7865
	export VARNISH_CACHE_HITS=$(echo "$HEADERS" | grep "X-Varnish-Cache-Hits:" | awk '{print $2}' | tr -d $'\r')  

if test -z "$VARNISH_CACHE_HITS"
then
	export VARNISH_CACHE_HITS="VARNISH_CACHE_HITS_NULL"
else
	export VARNISH_CACHE_HITS=$(echo "$HEADERS" | grep "X-Varnish-Cache-Hits:" | awk '{print $2}' | tr -d $'\r' )
fi

}
################
function testXAge() {
	# EXAMPLE: X-Age -> X-Age: 7580
	export X_AGE=$(echo "$HEADERS" | grep "X-Age:" | awk '{print $2}' | tr -d $'\r')  

if test -z "$X_AGE"
then
	export X_AGE="X_AGE_NULL"
else
	export X_AGE=$(echo "$HEADERS" | grep "X-Age:" | awk '{print $2}' | tr -d $'\r')  
fi

}
################


############
# 
#   MAIN
#
############

# reset outdir
if test -d $OUTDIR
then
	rm -fr $OUTDIR
	mkdir -p $OUTDIR
	check_error
else
	mkdir -p $OUTDIR
	check_error
fi

# check that webkit2png exists
export WEBKIT2PNG=`which webkit2png`
if test -x $WEBKIT2PNG
then
	echo "webkit2png exists"
else
	echo "webkit2png does NOT exist"
	echo "brew install webkit2png"
	exit 1
fi 

# check that imagemagick (convert) exists
export IMAGEMAGIK=`which convert`
if test -x $IMAGEMAGIK
then
	echo "imagemagick exists"
else
	echo "imagemagick does NOT exist"
	echo "brew install imagemagick"
	exit 1
fi 

# check that wget exists
export WGET=`which webkit2png`
if test -x $WGET
then
	echo "wget exists"
else
	echo "wget does NOT exist"
	echo "brew install wget"
	exit 1
fi 


# HEADER tests logic here

# TODO: echo "results file exists do you want to overwrite (save a backup)?" | read yesno
#	Y/N
# reset results file
echo ""HTTP_STATUS_CODE","AKAMAI_CACHE_CODE","VARNISH_CACHE_CODE","VARNISH_CACHE_HITS","MAX_AGE","X_AGE","REQUEST_TIME","URL"" > ${RESULTS_CSV}

# begin looping through urls and grabbing headers
cat ${URLS} | sort -u | while read url
do

	#--# DEBUG:
	#--# url='http://cdn-css.si.com/sites/all/themes/custom/si_desktop/assets/images/header/logo-white.png' ; echo $url

	export HEADERS=$(getHeaders $url)
	export REQUEST_TIME=$(date -j +"%Y-%m-%d %H:%M:%S")

	#--# DEBUG:
	#--# echo "$HEADERS"	

	# Parse Headers, run tests, and get results
	#
	# Test Akamai
	testAkamaiCache
	check_error
	#
	# Test Varnish
	testVarnishCache
	check_error
	#
	# Test HTTP Status Code
	testHTTPStatusCode
	check_error
	#
	# Test max-age
	testMaxAge
	check_error
	#
	# get Varnish Cache Hits
	testVarnishCacheHits
	check_error
	#
	# Test X-Age
	testXAge
	check_error
	#

	# Write the results to file
	 echo ""${HTTP_STATUS_CODE}","${AKAMAI_CACHE_CODE}","${VARNISH_CACHE_CODE}","${VARNISH_CACHE_HITS}","${MAX_AGE}","${X_AGE}","${REQUEST_TIME}","$url"" | tee -a $RESULTS_CSV
	check_error

done
# end loop

#
# Create Reports
#
  # report stats
  # ./generateReport.sh
  # check_error


check_error
echo "$(basename $0) completed successfully!"
exit 0
#--# END

