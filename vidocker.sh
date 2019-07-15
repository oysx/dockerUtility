run(){
	echo -n "$*"
	bash -c "$*"
	echo "==> $?"
}

#check priviledge
if [ "$(id -u)" != "0" ];then
	echo "must run as root user, please use sudo"
	exit 1
fi

#install packages
which brctl >/dev/null
if [ $? != 0 ];then
	echo "install packages required now"
	apt-get install bridge-utils
	if [ $? != 0 ];then
		echo "failed to get package"
		exit 1
	fi
fi

IFINDEX=eth0
IMAGE=$1
#check mandantory parameters
if [ "x$IMAGE" = "x" ];then
	echo "usage: $0 <docker image>"
	exit 1
fi

#check existance of the image
if [ "$(docker images -q $IMAGE)" = "" ];then
	echo "can not find image \"$IMAGE\""
	exit 1
fi

#docker running options
DOCKER_OPTIONS=--privileged=true
USER=oysx
PASSWD=oysx
UID=1000
GID=1000

#remove jail for dhclient in docker instance
apparmor_status | grep dhclient
if [ $? = 0 ];then
	apparmor_parser -R /etc/apparmor.d/sbin.dhclient 
fi

startContainer(){
	IMAGE=$1
	#CONTAINER=$(docker run -u $UID:$GID --group-add=[sudo] --net=none -dt $DOCKER_OPTIONS $IMAGE )
	CONTAINER=$(docker run -u $UID:$GID --net=none -dt $DOCKER_OPTIONS $IMAGE )
	if [ $? != 0 ];then
		echo "start container image $IMAGE failed"
		exit 1
	fi
	CONTAINER=$(expr substr $CONTAINER 1 12)
	echo $CONTAINER
}


setupNetns(){
	#set symbol link to show up netns
	CONTAINER=$1
	OPCODE=$2
	NAMESPACE=$(docker inspect --format='{{ .State.Pid }}' $CONTAINER)
	if [ "$OPCODE" = "add" ];then
		run mkdir -p /var/run/netns
		run ln -s /proc/$NAMESPACE/ns/net /var/run/netns/$NAMESPACE
	else
		run unlink /var/run/netns/$NAMESPACE
	fi
}

findIntf(){
	ip -o link |cut -d\  -f2|grep $1 > /dev/null
	if [ $? = 0 ];then
		return 1
	fi
	return 0
}

createBridge(){
	findIntf $1
	if [ $? = 1 ];then
		echo "already created bridge $1"
		return 1
	fi

	run brctl addbr $1
	run ifconfig $1 up
	return 1
}

moveHostIntf(){
	IFINDEX=$1
	BRIDGE=bridge-$IFINDEX

	bridge link show|cut -d\  -f 2|grep "^$IFINDEX\$"
	#brctl show $BRIDGE | grep "\<$IFINDEX\>" >/dev/null
	if [ $? = 0 ];then
		echo "host interface $IFINDEX already in bridge $BRIDGE"
		return 1
	fi

	run ip addr flush dev $IFINDEX
	run brctl addif $BRIDGE $IFINDEX
}

getMacAddr(){
	ip link show $1|grep -o "link/ether [^[:space:]]*"|cut -d\  -f2
}
setMacAddr(){
	run ip link set address $2 dev $1
}

cloneIntfMacAddress(){
	addr=$(getMacAddr $1)
	echo "$1/$2: host side address is $addr"
	setMacAddr $2 $addr
}

attachToBridge(){
	CONTAINER=`expr substr $1 1 6`
	IFINDEX=$2
	BRIDGE=bridge-$IFINDEX
	HOST_IF=h-$IFINDEX-$CONTAINER
	GUEST_IF=g-$IFINDEX-$CONTAINER

	NAMESPACE=$(docker inspect --format='{{ .State.Pid }}' $CONTAINER)
	if [ $? != 0 ];then
		echo "can not find container $CONTAINER"
		return 0
	fi

	findIntf $BRIDGE
	if [ $? = 0 ];then
		echo "bridge $BRIDGE not exist"
		return 0
	fi

	findIntf $HOST_IF
	if [ $? = 1 ];then
		echo "intf $HOST_IF already exist"
		return 1
	fi

	#create veth pair for container
	run ip link add $HOST_IF type veth peer name $GUEST_IF
	#cloneIntfMacAddress $HOST_IF $GUEST_IF

	run brctl addif $BRIDGE $HOST_IF
	run ifconfig $HOST_IF up

	#move interface into container and setup this interface
	run ip link set $GUEST_IF netns $NAMESPACE name $IFINDEX

	setupNetns $CONTAINER_ID add
	run ip netns exec $NAMESPACE ip link set $IFINDEX up
	#run ip netns exec $NAMESPACE dhclient $IFINDEX 
	setupNetns $CONTAINER_ID remove

	return 1
}

IMAGE=$(docker images -q $IMAGE)
CONTAINER_ID=$(startContainer $IMAGE)
if [ $? != 0 ];then
	exit 1
fi
createBridge bridge-$IFINDEX
moveHostIntf $IFINDEX
attachToBridge $CONTAINER_ID $IFINDEX

#do some setup for this docker instance such as password, sudoer, etc.
docker exec -u root $CONTAINER bash -c "echo '$USER:$PASSWD'|chpasswd"
docker exec -u root $CONTAINER adduser $USER sudo

#instruction to connect to docker instance console
docker exec -it $CONTAINER bash

#instruction to stop and delete containers
#for i in `docker ps -a|grep "$IMAGE"|cut -d\  -f1|xargs `;do docker stop $i;sudo docker rm $i;done

#docker commit -m "comments" $CONTAINER <repo>:<tag>

