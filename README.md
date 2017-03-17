Docker swarm mode mongo replica sets controller
===============================================
Minimal shell scripts to manage mongo replica sets in mongo controller.

Usage
-----
Take a look at ctrl.sh to see what environment variables can be passed in.

    docker network create -d overlay mongo
    docker service create --name mongo --replicas 3 --network mongo -p 27017:27017 mongo mongod --replSet rs
    docker service create --name mongo-ctrl --constraint node.role==manager --network mongo --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock vase/mongo-rs-ctrl
