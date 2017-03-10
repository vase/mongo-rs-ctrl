#!/bin/sh
# Simple script to manager mongo replica sets

# Environment variables
SERVICE_NAME=${SERVICE_NAME:-mongo}
NETWORK_NAME=${NETWORK_NAME:-mongo}
REPLICA_SETS=${REPLICA_SETS:-rs}
MONGODB_PORT=${MONGODB_PORT:-27017}

set services= master= i=
docker_api() { curl -sN --unix-socket /run/docker.sock http:/v1.26/$*; }

get_primary() {
	services=$(nslookup tasks.$NETWORK_NAME 2>/dev/null | awk "/Addr/ {print \$4\":$MONGODB_PORT\"}")
	for i in $services; do
		[ -n $(mongo $i --quiet --eval 'rs.isMaster().setName' 2>&1) ] \
			&& master=$(mongo $i --quiet --eval "rs.status().members.find(r=>r.state===1).name") \
			&& return
	done || mongo $i --quiet --eval "rs.initiate()" && master=$i \
		|| { echo Database is broken; exit; }
}

add_node() {
	mongo $master --eval "rs.isMaster().ismaster" | grep -q true || get_primary
	mongo $master --eval "rs.add(\"$1\")" >/dev/null && echo +$1
}

del_node() {
	mongo $master --eval "rs.isMaster().ismaster" | grep -q true || get_primary
	mongo $master --eval "rs.remove(\"$1\")" >/dev/null && echo -$1
}

del_down_nodes() {
	mongo $master --eval "rs.isMaster().ismaster" | grep -q true || get_primary
	for i in $(mongo $master --quiet --eval 'rs.status().members.filter(r=>r.state===8).map(r=>r.name).join(" ")'); do
		del_node $i
	done
}

echo -n .. Service $SERVICE_NAME is\  && docker_api services/$SERVICE_NAME \
	| grep -q 'ID' && echo UP || { echo DOWN; exit 1; }

echo -n .. Master -\  && get_primary && echo $master

echo .. Remove down replica sets
del_down_nodes

echo .. Add uninitialized services
for i in $services; do
	mongo $i --quiet --eval 'rs.status().members.find(r=>r.state===1).self' &>/dev/null || add_node $i
done

echo .. Listen for docker container events
set -x
while IFS= read -r l; do
	echo $l | grep -q docker.swarm.service.name\":\"$SERVICE_NAME\" || continue
	case $(echo $l | sed -n 's/.*status":"\([a-z]*\).*/\1/p') in
		start) add_node $(echo $l | sed "s/.*name\":\"\([a-z0-9.]*\)\".*/\1/").$NETWORK_NAME;;
		destroy) del_down_nodes;;
	esac
done <<EOF
$(docker_api events -Gd filters={\"type\":[\"container\"]})
EOF
