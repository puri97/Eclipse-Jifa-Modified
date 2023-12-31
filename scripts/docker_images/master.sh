#! /bin/sh
# Copyright (c) 2021 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0
#
# SPDX-License-Identifier: EPL-2.0
#

export JAVA_HOME=/usr/lib/jvm/java-11/

DEPLOY_ROOT=/home/admin/jifa-master/

MASTER_ZIP=master-1.0.zip

FRONTEND_ZIP=frontend-1.0.zip

cd $DEPLOY_ROOT
mkdir target
mv jifa.tgz target
cd target

tar -xf jifa.tgz

mkdir -p /home/admin/logs
mkdir -p /home/admin/.ssh/
cp artifacts/config/jifa-ssh-key.pub /home/admin/.ssh/

mv artifacts/${MASTER_ZIP} ./
unzip ${MASTER_ZIP}

export JAVA_OPTS="""\
-server -Xms5g -Xmx5g -XX:MaxNewSize=3g                                      \
-XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=45 -XX:G1HeapRegionSize=8m   \
-XX:+ExplicitGCInvokesConcurrent -XX:ParallelGCThreads=4                     \
-Xlog:gc:/home/admin/logs/gc.log -Xlog:gc*                                   \
-Dsun.rmi.dgc.server.gcInterval=2592000000                                   \
-Dsun.rmi.dgc.client.gcInterval=2592000000                                   \
-XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m                             \
-XX:ReservedCodeCacheSize=256m                                               \
-XX:MaxDirectMemorySize=512m                                                 \
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/home/admin/logs            \
-XX:ErrorFile=/home/admin/logs/hs_err_pid%p.log                              \
-Dproject.name=jifa-parser                                                   \
-Djdk.tls.client.protocols=TLSv1.2                                           \
"""

export MASTER_OPTS="""\
-Dlog4j.configurationFile=log4j2-test.xml \
-Djifa.master.config=master-config.json  \
"""

mkdir frontend
mv artifacts/${FRONTEND_ZIP} frontend
cd frontend
unzip ${FRONTEND_ZIP}

# start nginx
nginx -c $DEPLOY_ROOT/nginx.conf

cd ..
# start master
./master-1.0/bin/master