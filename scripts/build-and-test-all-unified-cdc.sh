#!/bin/bash

set -e

if [ -z "$DOCKER_COMPOSE" ]; then
    echo setting DOCKER_COMPOSE
    export DOCKER_COMPOSE="docker-compose -f docker-compose-unified.yml -f docker-compose-new-cdc-unified.yml"
else
    echo using existing DOCKER_COMPOSE = $DOCKER_COMPOSE
fi

export GRADLE_OPTIONS="-P excludeCdcLibs=true"

./gradlew $GRADLE_OPTIONS assemble

$DOCKER_COMPOSE stop
$DOCKER_COMPOSE rm --force -v

$DOCKER_COMPOSE build
$DOCKER_COMPOSE up -d mysql postgrespollingpipeline mysqlbinlogpipeline postgreswalpipeline

./scripts/wait-for-mysql.sh

sleep 30

$DOCKER_COMPOSE up -d

./scripts/wait-for-services.sh $DOCKER_HOST_IP 8099

. ./scripts/set-env-mysql.sh
export SPRING_DATASOURCE_URL=jdbc:mysql://${DOCKER_HOST_IP}:3307/eventuate

./gradlew $GRADLE_OPTIONS :eventuate-local-java-jdbc-tests:test

. ./scripts/set-env-postgres-polling.sh
./gradlew $GRADLE_OPTIONS :eventuate-local-java-jdbc-tests:test

. ./scripts/set-env-postgres-wal.sh
export SPRING_DATASOURCE_URL=jdbc:postgresql://${DOCKER_HOST_IP}:5433/eventuate
./gradlew $GRADLE_OPTIONS :eventuate-local-java-jdbc-tests:test

$DOCKER_COMPOSE stop
$DOCKER_COMPOSE rm --force -v
