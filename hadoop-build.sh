#!/usr/bin/env bash

set -euo pipefail

HADOOP_VERSION=${HADOOP_VERSION:-2.8.5}
HADOOP_INSTALL_DIR=${HADOOP_INSTALL_DIR:-$HOME/bin/hadoop-${HADOOP_VERSION}}

TMP_BUILD_DIR=/tmp/hadoop-${HADOOP_VERSION}

install_protobuf() {
    PROTO_VERSION=2.5.0

    echo "Downloading Protobuff ${PROTO_VERSION} ..."
    wget "https://github.com/google/protobuf/releases/download/v${PROTO_VERSION}/protobuf-${PROTO_VERSION}.tar.gz"
    tar -xf protobuf-${PROTO_VERSION}.tar.gz
    rm protobuf-${PROTO_VERSION}.tar.gz

    echo "Building Protobuff ${PROTO_VERSION} ..."
    cd protobuf-${PROTO_VERSION}
    ./configure --silent
    make --silent install
    protoc --version
    cd ..
    rm -rf protobuf-${PROTO_VERSION}
}

install_prerequisites() {
    echo "Install prerequisites ..."
    brew install wget gcc autoconf automake libtool cmake snappy gzip bzip2 zlib openssl
    ln -f -s /usr/local/include/opt/openssl/include/openssl /usr/local/include/openssl
    install_protobuf
}

install_hadoop() {
    echo "Downloading Hadoop-${HADOOP_VERSION} ..."
    git clone https://github.com/apache/hadoop.git
    cd hadoop
    git checkout "branch-${HADOOP_VERSION}"

    echo "Building Hadoop-${HADOOP_VERSION} ..."
    mvn package --quiet \
                -Pdist,native \
                -DskipTests \
                -Dlog4j.logger=WARN

    echo "Installing Hadoop-${HADOOP_VERSION} ..."
    cp -R "hadoop-dist/target/hadoop-${HADOOP_VERSION}" "${HADOOP_INSTALL_DIR}"
}

setup_env_vars() {
    echo "Setting HADOOP environment variables in ${HOME}/.bash_profile..."
    echo '
export HADOOP_VERSION='${HADOOP_VERSION}'
export HADOOP_HOME='${HADOOP_INSTALL_DIR}'
export HADOOP_OPTS="-Djava.library.path=${HADOOP_HOME}/lib/native"
export LD_LIBRARY_PATH=${HADOOP_HOME}/lib/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export JAVA_LIBRARY_PATH=${JAVA_LIBRARY_PATH}:${HADOOP_HOME}/lib/native
export PATH=${PATH}:${HADOOP_HOME}/bin
' >> "${HOME}/.bash_profile"
}

cleanup() {
    echo "Deleting build folder..."
    cd
    rm -rf "${TMP_BUILD_DIR}"
}

main() {
    mkdir -p "${TMP_BUILD_DIR}"
    cd "${TMP_BUILD_DIR}"
    install_prerequisites
    install_hadoop
    setup_env_vars
    source ~/.bash_profile
    hadoop checknative -a
    cleanup
    echo "Done. Happy Hadooping!!!"
}
    

main
