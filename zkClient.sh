#!/bin/bash

ID=$(docker run -dt ubuntu:14.04.3)

#NS=$(docker inspect  --format='{{.State.Pid}}' $ID)
#ip link add zkClient.host type veth peer name zkClient.guest
#ifconfig zkClient.host up
#ip link set zkClient.guest netns $NS name eth1
#brctl addbr zkClient.br
#brctl addif zkClient.br zkClient.host
#ifconfig zkClient.br up

docker network create -d bridge --subnet 172.25.0.0/16 zkClient.br
docker network connect zkClient.br $ID
#docker network inspect zkClient.br

docker exec -it --privileged $ID bash
