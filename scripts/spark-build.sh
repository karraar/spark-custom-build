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

SPARK_VERSION=${SPARK_VERSION:-3.0.0-rc1}
HADOOP_VERSION=${HADOOP_VERSION:-2.8.5}
AWS_VERSION=${AWS_VERSION:-1.11.646}
SPARK_INSTALL_DIR=${SPARK_INSTALL_DIR:-$HOME/bin/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION}}

TMP_BUILD_DIR=/tmp/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION}
PROFILES_DIR="${HOME}"/etc/profile.d

download_spark_source() {
    echo "Downloading Spark..."
    git clone https://github.com/apache/spark.git
    cd spark
    git checkout "v${SPARK_VERSION}"
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
                               -Dorg.slf4j.simpleLogger.LogLevel=error \
                               -Dhadoop.version="${HADOOP_VERSION}" \
                               -Dcommons.httpclient.version=4.5.9
}

install_spark_dist() {
    echo "Installing to ${SPARK_INSTALL_DIR}..."
    mkdir -p "${SPARK_INSTALL_DIR}"
    cp -r "${TMP_BUILD_DIR}/spark/dist"/* "${SPARK_INSTALL_DIR}"
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

write_spark_profile() {
    echo "Setting SPARK_HOME and PATH in ~/.bash_profile..."
    cat << EOF > "${PROFILES_DIR}"/spark.sh
export SPARK_HOME=${SPARK_INSTALL_DIR}
export PATH=\${PATH}:\${SPARK_HOME}/bin
EOF

    cat << EOF >> "${HOME}"/.bash_profile
source ${PROFILES_DIR}/spark.sh
EOF

    # shellcheck source=/dev/null
    source "${PROFILES_DIR}"/spark.sh
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
    if [ -d "${TMP_BUILD_DIR}" ]; then
        rm -rf "${TMP_BUILD_DIR}"
    fi
}

main() {
    cleanup
    mkdir -p "${PROFILES_DIR}" "${TMP_BUILD_DIR}"
    cd "${TMP_BUILD_DIR}"
    download_spark_source
    build_spark_dist
    download_aws_deps
    update_spark_log_level
    install_spark_dist
    write_spark_profile
    cleanup
    echo "Done. Happy Sparking!!!"
}


main
