#!/bin/bash
#instruction to iter containers
op=$1
if [ "x$op" = "x" ];then
	echo "usage: $0 <operation>"
	exit 1
fi

for op in $*;do
	if [ "${op:0:1}" = "-" ];then
		filter=${op:1};
		continue;
	fi
	#for i in `docker ps -aq|cut -d\  -f1|xargs `;do echo "docker $op $i";done
	for i in `docker ps -aqf name=$filter |cut -d\  -f1|xargs `;do docker $op $i;done
done


