#!/usr/bin/env bash
  
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -euo pipefail

SPARK_VERSION=${SPARK_VERSION:-2.4.4}
HADOOP_VERSION=${HADOOP_VERSION:-2.8.5}
AWS_VERSION=${AWS_VERSION:-1.11.646}
SPARK_INSTALL_DIR=${SPARK_INSTALL_DIR:-$HOME/bin/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION}}

TMP_BUILD_DIR=/tmp/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION}

download_spark_source() {
    TGZ="spark-${SPARK_VERSION}.tgz"
    echo "Downloading and Extracting ${TGZ}..."
    curl --silent "http://apache.osuosl.org/spark/spark-${SPARK_VERSION}/${TGZ}" \
       | tar -xf -
}

build_spark_dist() {
    echo "Building Distribution..."
    ./dev/make-distribution.sh --name "with-hadoop-${HADOOP_VERSION}" \
                               --pip \
                               --tgz \
                               -Psparkr \
                               -Phive \
                               -Phive-thriftserver \
                               -Pmesos \
                               -Pyarn \
                               -Pkubernetes \
                               -Dorg.slf4j.simpleLogger.LogLevel=warn \
                               -Dhadoop.version=${HADOOP_VERSION} \
                               -Dcommons.httpclient.version=4.5.9 \
                               -q
}

install_spark_dist() {
    echo "Installing to ${SPARK_INSTALL_DIR}..."
    mkdir -p "${SPARK_INSTALL_DIR}"
    cp -r "${TMP_BUILD_DIR}/spark-${SPARK_VERSION}/dist"/* "${SPARK_INSTALL_DIR}"
}

download_dep_jar() {
    NAME=$1
    VERSION=$2
    ORG_PATH=$3
    FULL_NAME="${NAME}-${VERSION}.jar"
    echo "Downloading ${FULL_NAME}..."
    curl --silent \
         --output "dist/jars/${FULL_NAME}" \
         "https://repo1.maven.org/maven2/${ORG_PATH}/${NAME}/${VERSION}/${FULL_NAME}"
    ls -l "dist/jars/${FULL_NAME}"
}

download_aws_deps() {
    ## Hadoop AWS jars
    download_dep_jar hadoop-aws "${HADOOP_VERSION}" org/apache/hadoop

    ## AWS SDK
    download_dep_jar aws-java-sdk "${AWS_VERSION}" com/amazonaws
    download_dep_jar aws-java-sdk-core "${AWS_VERSION}" com/amazonaws
    download_dep_jar aws-java-sdk-s3 "${AWS_VERSION}" com/amazonaws
}

setup_env_vars() {
    echo "Setting SPARK_HOME and PATH in ~/.bash_profile..."
    echo "
export SPARK_HOME=${SPARK_INSTALL_DIR}
export PATH=\${PATH}:\${SPARK_HOME}/bin
" >> ~/.bash_profile

}

update_spark_log_level() {
    echo "Updating spark log level to warn"
    sed -e 's/INFO/WARN/g' \
      < dist/conf/log4j.properties.template \
      > dist/conf/log4j.properties
}

cleanup() {
    echo "Deleting build folder..."
    cd
    rm -rf "${TMP_BUILD_DIR}"
}

main() {
    mkdir -p "${TMP_BUILD_DIR}"
    cd "${TMP_BUILD_DIR}"
    download_spark_source
    cd "spark-${SPARK_VERSION}"
    build_spark_dist
    download_aws_deps
    update_spark_log_level
    install_spark_dist
    setup_env_vars
    echo "Done. Happy Sparking!!!"
}


main
