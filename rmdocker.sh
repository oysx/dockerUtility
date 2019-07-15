#instruction to stop and delete containers
for i in `docker ps -aq|grep "$1"|cut -d\  -f1|xargs `;do docker stop $i;sudo docker rm $i;done
#for i in `docker ps -aq|grep "$1"|cut -d\  -f1|xargs `;do docker stop $i;done

#docker commit -m "comments" $CONTAINER <repo>:<tag>

