#/bin/sh
DOMAIN_PATTERN="googlebot\.com"
LIST_NAME="/root/script/list"
LIST=`cat $LIST_NAME`
DATE=`date '+%Y%m%d%H'`
MONTH=`date '+%Y%m'`
USER_AGENT="/root/script/verity_ip/user_agent_list"
WHITE_IP="/root/script/verity_ip/white_ip_list"

function CreateHtmlFile() {
	echo "<!DOCTYPE html><html><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge">" > verity_ip_$DATE.html
	echo "<title>Verity Result</title><link href="../css/style.css" rel="stylesheet" type="text/css" />" >> verity_ip_$DATE.html
	echo "<script src="http://libs.baidu.com/jquery/1.9.0/jquery.js"></script><script src="../js/main.js"></script>" >> verity_ip_$DATE.html
	echo "</head>" >> verity_ip_$DATE.html
	echo "<body><table class=\"cltable\" border=\"0\" cellspacing=\"1\" cellpadding=\"0\"><thead><tr><th class=\"col1\">Domain Name</th><th class=\"col2\">IP</th><th class=\"col3\">Host Info</th><th class=\"col4\">User Agent</th></tr></thead><tbody>" >> verity_ip_$DATE.html
	HTML_DATA_NUM=`cat ./verity_ip.html_temp | awk '{ print $1}' | wc -l`
	for((m=1;m<=HTML_DATA_NUM;m=m+1))
	do
		HTML_DATA=$(cat ./verity_ip.html_temp | awk 'NR=='$m'')
		echo "$HTML_DATA" >> verity_ip_$DATE.html
	done
	echo "</tbody></table></body></html>" >> verity_ip_$DATE.html
} 

function VerityIp() {
    cat $ACCESSLOG |
    grep -v -f $WHITE_IP |
    grep -f $USER_AGENT | 
    cut -d ' ' -f 1 |
    sort -u |
    while read IP; do
    	RESULT=`host $IP | grep $DOMAIN_PATTERN`
        if [[ ! -n "$RESULT" ]]; then
        	GEOIP_LOCATION_INFO=`geoiplookup $IP | sed 'N;s/\n/:/' | cut -f2 -d ':'| sed 's/\,/;/'`
       		GEOIP_INFO="$GEOIP_LOCATION_INFO"
       		HOST_INFO=`host $IP`
       		USER_AGENT_INFO=`cat $ACCESSLOG | grep $IP |cut -d '"' -f 6 | sort -u`
       		MORE_INFO=`cat $ACCESSLOG | grep $IP | sort -u | cut -d '[' -f2 | sed 's/$/&<br\ \/>/g'`
       		echo "$WEBSITE_NAME,$IP,$GEOIP_INFO,$HOST_INFO,$USER_AGENT_INFO" >> ./verity_ip.log_temp
       		echo "deny $IP;" >> ./verity_ip.config_temp
       		echo "<tr><td>$WEBSITE_NAME</td><td><a class="view_more" href='#$n' rel='$n'>$IP</a></td><td><div class=\"geoinfo\">$GEOIP_INFO</div><div class=\"hostinfo\">$HOST_INFO</div></td><td>$USER_AGENT_INFO</td></tr>" >> ./verity_ip.html_temp
            echo "<tr id='more_$n'><td colspan=12>$MORE_INFO</td></tr>" >> ./verity_ip.html_temp
        fi
    done
}

function CopyResult() {
	cat verity_ip.log_temp |
	sort -u > verity_ip_$DATE.log
	cat verity_ip.config_temp |
	grep -v "deny\ \-\;" |
	sort -u > verity_ip_$DATE.config	
	rm verity_ip.html_temp 
	rm verity_ip.log_temp
	rm verity_ip.config_temp
	cp verity_ip_$DATE.config /usr/local/nginx/conf/block_ip/verity_ip_$DATE.conf
	nginx -t
	if [[ $? = 0 ]]; then
		amh nginx reload >> /dev/null
		echo "amh nginx service reloaded."
	else
		echo "Error: The nginx config exist problems, please fix it before reload the amh nginx service."
		break
	fi
	if [[ ! -d "/home/wwwroot/index/web/verity_ip/$MONTH/" ]]; then
		mkdir -p /home/wwwroot/index/web/verity_ip/$MONTH/
	fi
	cp verity_ip_$DATE.log /home/wwwroot/index/web/verity_ip/$MONTH/verity_ip_$DATE.csv
	cp verity_ip_$DATE.html /home/wwwroot/index/web/verity_ip/$MONTH/verity_ip_$DATE.html
}



function Main() {
	cd /root/verity_ip_temp/
	for WEBSITE_NAME in $LIST
	do
		if [[ -d "/home/wwwroot/$WEBSITE_NAME/" ]]; then
			ACCESSLOG=/home/wwwroot/$WEBSITE_NAME/log/access.log
			VerityIp
		fi
	done
	CreateHtmlFile
	CopyResult
	find /home/wwwroot/index/web/verity_ip/20* -size -600c -exec rm {} \;
}

Main
