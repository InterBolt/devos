#!/usr/bin/env bash

rm -rf /root/.config/configstore || true
docker service rm "$(docker service ls -q)" || true
echo "remove CapRover settings directory"
rm -rf /captain || true
echo "leave swarm if you don't want it"
docker swarm leave --force || true
echo "full cleanup of docker"
docker system prune --all --force || true
