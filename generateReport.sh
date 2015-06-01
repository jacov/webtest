#!/bin/bash
#
# Author: Jacob Baloul <jacob.baloul@acquia.com>
# Date: May 29th, 2015
# Script to generate report from webtest.sh / results.csv 
# crunch numbers to html
# and combine into a single PDF report


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

# export CUSTOMER='Sports Illustrated'

export CUSTOMER_SAFE=$(echo "${CUSTOMER}" | sed -e 's/ /-/g')
export REPORT="${CUSTOMER_SAFE}-Site-Report-$(date -j +"%B-%Y-%H%M%S").pdf"


# TODO: urlspider to urls.txt
# export URLS="$OUTDIR/urls.txt"

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
function createCoverPage() {
	# prepare cover page

	# copy logo
	cp $PWD/etc/acquia-logo.jpg ${OUTDIR}/.
	check_error

	# copy + search / replace stuff
	cat $PWD/etc/cover.tpl.html | sed \
		-e "s/_REPLACE_CUSTOMER/${CUSTOMER}/g" 	\
		-e "s/_REPLACE_MONPERIOD/$(date -j -v-30d +"%B %Y")/g" 	\
		-e "s/_REPLACE_PREPDATE/$(date -j +"%B %d, %Y %H:%M:%S")/g" 	> ${OUTDIR}/cover.html
	check_error

	# screenshot cover page
	#--#
	#--# USAGE: webkit2png http://www.google.com/
	#--#	    webkit2png --help
	#--#
#	webkit2png -W 800 -H 600 -F --filename=${OUTDIR}/${sitename} ${uptimeURL}
#	check_error
	webkit2png -W 800 -H 600 -F --filename=${OUTDIR}/0AA-cover ${OUTDIR}/cover.html
	check_error
}
################
function createResultsPage() {
	# prepare Results page
	cat /dev/null > ${OUTDIR}/results.html
	check_error
}
################
function compileResultsPage() {

	# screenshot results page
	#--#
	#--# USAGE: webkit2png http://www.google.com/
	#--#	    webkit2png --help
	#--#
#	webkit2png -W 800 -H 600 -F --filename=${OUTDIR}/${sitename} ${uptimeURL}
#	check_error
	webkit2png -W 800 -H 600 -F --filename=${OUTDIR}/0BB-results ${OUTDIR}/results.html
	check_error
}
################
function createFinalReport() {
# Combine the image screenshots to a single pdf report
convert ${OUTDIR}/*.png -resize 800x600 ${OUTDIR}/${REPORT}
check_error

echo "
	========
	$(date)

	$0 completed successfully!

	Reports available here:
		${OUTDIR}/${REPORT}
		$RESULTS_CSV
	"
}
################
#
# RESULTS_CSV headers and columns
# "HTTP_STATUS_CODE",AKAMAI_CACHE_CODE","VARNISH_CACHE_CODE","VARNISH_CACHE_HITS","MAX_AGE","X_AGE","URL"
# echo ""${HTTP_STATUS_CODE}","${AKAMAI_CACHE_CODE}","${VARNISH_CACHE_CODE}","${VARNISH_CACHE_HITS}","${MAX_AGE}","${X_AGE}","$url"" | tee -a $RESULTS_CSV
#
################
function getHTTPStatusCodeCount() {

echo "
<pre>
Count		Percentage	HTTP_STATUS_CODE" >> ${OUTDIR}/results.html
# TODO: change this -f per code
# HTTP_STATUS_CODE -f 1
tail -n +2 $RESULTS_CSV | cut -f 1 -d ',' | sort -u | grep -v '^$' | tr -d $'\r'| while read code
do

export CODE_COUNT=$(cat $RESULTS_CSV | cut -f 1 -d ',' | grep -e "^${code}" | wc -l) # change -f n
export CODE_DECIMAL=$(echo "scale=2; ${CODE_COUNT}/${TOTAL_URLS}" | bc)
export CODE_PERCENTAGE=$(echo $CODE_DECIMAL*100 | bc )

if [ "$CODE_PERCENTAGE" = "1.00" ]
then
	export CODE_PERCENTAGE="100"
fi

# TODO: change this for every code
export HTTP_STATUS_CODE_COUNT="$CODE_COUNT"
export HTTP_STATUS_CODE_DECIMAL="$CODE_DECIMAL"
export HTTP_STATUS_CODE_PERCENTAGE="$CODE_PERCENTAGE"

echo "${HTTP_STATUS_CODE_COUNT}		${HTTP_STATUS_CODE_PERCENTAGE}%		"$code"" >> ${OUTDIR}/results.html
done

echo "</pre>" >> ${OUTDIR}/results.html

}
################
function getAkamaiCacheCodeCount() {

echo "
<pre>
Count		Percentage	AKAMAI_CACHE_CODE" >> ${OUTDIR}/results.html
# TODO: change this -f per code
# AKAMAI_CACHE_CODE -f 2
tail -n +2 $RESULTS_CSV | cut -f 2 -d ',' | sort -u | grep -v '^$' | tr -d $'\r' | while read code
do

# avoid dups with grep exact match
export CODE_COUNT=$(cat $RESULTS_CSV | cut -f 2 -d ',' | grep -e "^${code}" | wc -l) # change -f n
export CODE_DECIMAL=$(echo "scale=2; ${CODE_COUNT}/${TOTAL_URLS}" | bc)
export CODE_PERCENTAGE=$(echo $CODE_DECIMAL*100 | bc )

if [ "$CODE_PERCENTAGE" = "1.00" ]
then
	export CODE_PERCENTAGE="100"
fi

# TODO: change this for every code
export AKAMAI_CACHE_CODE_COUNT="$CODE_COUNT"
export AKAMAI_CACHE_CODE_DECIMAL="$CODE_DECIMAL"
export AKAMAI_CACHE_CODE_PERCENTAGE="$CODE_PERCENTAGE"

echo "${AKAMAI_CACHE_CODE_COUNT}		${AKAMAI_CACHE_CODE_PERCENTAGE}%		"$code"" >> ${OUTDIR}/results.html

done

echo "</pre>" >> ${OUTDIR}/results.html
}
################
function getVarnishCacheCodeCount() {

echo "
<pre>
Count		Percentage	VARNISH_CACHE_CODE" >> ${OUTDIR}/results.html
# TODO: change this -f per code
# VARNISH_CACHE_CODE -f 3
tail -n +2 $RESULTS_CSV | cut -f 3 -d ',' | sort -u | grep -v '^$' | tr -d $'\r' | while read code # change -f n
do

# grep exact match "^foo$"
export CODE_COUNT=$(cat $RESULTS_CSV | cut -f 3 -d ',' | grep -e "^${code}" | wc -l) # change -f n
export CODE_DECIMAL=$(echo "scale=2; ${CODE_COUNT}/${TOTAL_URLS}" | bc)
export CODE_PERCENTAGE=$(echo $CODE_DECIMAL*100 | bc )

if [ "$CODE_PERCENTAGE" = "1.00" ]
then
	export CODE_PERCENTAGE="100"
fi

# TODO: change this for every code
export VARNISH_CACHE_CODE_COUNT="$CODE_COUNT"
export VARNISH_CACHE_CODE_DECIMAL="$CODE_DECIMAL"
export VARNISH_CACHE_CODE_PERCENTAGE="$CODE_PERCENTAGE"

echo "${VARNISH_CACHE_CODE_COUNT}		${VARNISH_CACHE_CODE_PERCENTAGE}%		"$code"" >> ${OUTDIR}/results.html

done

echo "</pre>" >> ${OUTDIR}/results.html
}
################
function getAvgVarnishCacheHits() {
	echo "TODO: getAvgMaxAge"
}
################
function getAvgMaxAge() {
	echo "TODO: getAvgMaxAge"
}
################
function getAvgXAge() {
	echo "TODO: getAvgXAge"
}
################
function getTotalURLs() {
export TOTAL_URLS=$(tail -n +2 $RESULTS_CSV | wc -l | sed -e 's/ //g')

echo "
<pre>
=========

Total URLs sampled: ${TOTAL_URLS}

=========
</pre>
" >> ${OUTDIR}/results.html
}
################

#
# MAIN
#

# create cover page
createCoverPage 
check_error

# create results page
createResultsPage
check_error


# report stats
#
	# Begin Crunching Numbers
	getTotalURLs
	 check_error
echo ;
	#--# DEBUG
	echo "getHTTPStatusCodeCount"
	getHTTPStatusCodeCount
	 check_error
echo ;
	#--# DEBUG
	echo "getAkamaiCacheCodeCount"
	getAkamaiCacheCodeCount
	 check_error
echo ;
	#--# DEBUG
	echo "getVarnishCacheCodeCount"
	getVarnishCacheCodeCount
	 check_error
echo ;
#	getAvgVarnishCacheHits
#	 check_error
#echo ;
#	getAvgMaxAge
#	 check_error
#echo ;
#	getAvgXAge
#	 check_error
#echo ;

# compile results page
compileResultsPage
check_error

# create the final report
createFinalReport
check_error

exit 0



