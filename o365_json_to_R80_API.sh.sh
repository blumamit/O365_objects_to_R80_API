#!/bin/bash

## see https://docs.microsoft.com/en-us/office365/enterprise/office-365-ip-web-service
## endpoint json can be downloaded from https://endpoints.office.com/endpoints/Worldwide?ClientRequestId=b10c5ed1-bad1-445f-b386-b919946339a7

#O365 master group object name
group="Group_O365" 

#get all services
jq ".[].serviceArea" $1 | sort -u | cut -d'"' -f2 -> services.txt
####### create O365_batch.sh file ##########
echo '#!/bin/bash' > O365_batch.sh
####### create "Group_O365" group ##########
echo "echo Adding group ${group}" >> O365_batch.sh
echo "mgmt_cli add group name ${group} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh

while read service
do
	echo "echo Adding group ${group}_${service}" >> O365_batch.sh	
	####### create "O365_Service" group ##########
	echo "mgmt_cli add group name ${group}_${service} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
	####### add "O365_Service" group as "Group_O365" subgroup ########
	echo "mgmt_cli set group name ${group} members.add ${group}_${service} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
	
	#get all ipv4 hosts:
	jq ".[] | select (.serviceArea==\"${service}\") | .ips[]" $1 2>/dev/null | cut -d'"' -f2 | grep -P '\d+\.\d+\.\d+\.\d+'| grep '/32$' | sort -u >> ${service}_ipv4_hosts.txt
	while read ipv4Host
	do
		address=`echo "${ipv4Host}" | cut -d'/' -f1`
		echo "echo Adding ipv4 Host ${address} to ${service} group" >> O365_batch.sh
		###### create O365_Service_ipv4_Host object ######
		echo "mgmt_cli add host name ${group}_${service}_IPv4_Host_${address} ip-address ${address} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
		###### add O365_Service_ipv4_Host object to O365_Service group #####
		echo "mgmt_cli set group name ${group}_${service} members.add ${group}_${service}_IPv4_Host_${address} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh				
	done < ${service}_ipv4_hosts.txt

	#get all ipv4 networks:
	jq ".[] | select (.serviceArea==\"${service}\") | .ips[]" $1 2>/dev/null | cut -d'"' -f2 | grep -P '\d+\.\d+\.\d+\.\d+'| grep -v '/32$' | sort -u >> ${service}_ipv4_networks.txt	
	while read ipv4Network
	do
		address=`echo "${ipv4Network}" | cut -d'/' -f1`
		cidr=`echo "${ipv4Network}" | cut -d'/' -f2`
		echo "echo Adding ipv4 Network ${ipv4Network} to ${service} group" >> O365_batch.sh
		###### create O365_Service_ipv4_Network object ######
		echo "mgmt_cli add network name ${group}_${service}_IPv4_Net_${address} subnet ${address} mask-length ${cidr} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
		###### add O365_Service_ipv4_Network object to O365_Service group #####
		echo "mgmt_cli set group name ${group}_${service} members.add ${group}_${service}_IPv4_Net_${address} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh

	done < ${service}_ipv4_networks.txt
	
	#get all ipv6 networks:
	jq ".[] | select (.serviceArea==\"${service}\") | .ips[]" $1 2>/dev/null | cut -d'"' -f2 | grep -vP '\d+\.\d+\.\d+\.\d+' | sort -u >> ${service}_ipv6_networks.txt	
	while read ipv6Network
	do
		address=`echo "${ipv6Network}" | cut -d'/' -f1`
		cidr=`echo "${ipv6Network}" | cut -d'/' -f2`		
		echo "echo Adding ipv6 Network ${ipv6Network} to ${service} group" >> O365_batch.sh		
		###### create O365_Service_ipv6_Network object ######
		echo "mgmt_cli add network name ${group}_${service}_IPv6_Net_${address} subnet ${address} mask-length ${cidr} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
		###### add O365_Service_ipv6_Network object to O365_Service group #####
		echo "mgmt_cli set group name ${group}_${service} members.add ${group}_${service}_IPv6_Net_${address} ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh

	done < ${service}_ipv6_networks.txt	
	
	#get urls:
	jq ".[] | select (.serviceArea==\"${service}\") | .urls[]" $1 2>/dev/null | cut -d'"' -f2 | sort -u >> ${service}_urls.txt
	###### create application-site-category object ######
	echo "echo Adding URL Category ${group}_${service}_URL_Category" >> O365_batch.sh
	echo "mgmt_cli add application-site-category name ${group}_${service}_URL_Category ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
	
	###### add the url-list to the category #######
	echo "echo Adding URL list to Category ${group}_${service}_URL_Category" >>O365_batch.sh
	echo "mgmt_cli add application-site name ${group}_${service}_URL_Group primary-category ${group}_${service}_URL_Category `echo $(cat -n ${service}_urls.txt | awk '{print "url-list."$1" "$2}')` ignore-errors true ignore-warnings true -s id.txt" >> O365_batch.sh
		
done < services.txt

##### create progress percentage indicator #####

awk -v lines=`wc -l O365_batch.sh | cut -d' ' -f1` '/echo/ { print $0, NR*100/lines,"%" } /mgmt_cli/ {print $0}' O365_batch.sh > tmp.txt
mv tmp.txt O365_batch.sh
