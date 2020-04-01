#!/usr/bin/env bash

set -eo pipefail

HADOOP_VERSION=${HADOOP_VERSION:-2.8.5}
HADOOP_INSTALL_DIR=${HADOOP_INSTALL_DIR:-$HOME/bin/hadoop-${HADOOP_VERSION}}

TMP_BUILD_DIR=/tmp/hadoop-${HADOOP_VERSION}
PROFILES_DIR="${HOME}"/etc/profile.d

install_protobuf() {
    PROTO_VERSION=2.5.0
    if ! command -v protoc >/dev/null 2>&1 -o [ "$(protoc --version)" == "libprotoc ${PROTO_VERSION}" ]; then

        PROTO_TGZ="protobuf-${PROTO_VERSION}.tar.gz"
        echo "Downloading ${PROTO_TGZ} ..."
        curl --silent \
             --location \
             "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTO_VERSION}/${PROTO_TGZ}" \
           | tar -xf -

        echo "Building Protobuff ${PROTO_VERSION} ..."
        cd protobuf-${PROTO_VERSION}
        ./configure --silent
        make --silent --jobs install >/dev/null 2>&1
        protoc --version
        cd ..
        rm -rf protobuf-${PROTO_VERSION}
    fi
}

write_java_profile() {
    echo "Setting JAVA environment variables..."
    cat << EOF > "${PROFILES_DIR}"/java.sh
export JAVA_HOME=/Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home/
export PATH=\${PATH}:\${JAVA_HOME}/bin
EOF

    cat << EOF >> "${HOME}"/.bash_profile
source ${PROFILES_DIR}/java.sh
EOF
}

install_or_check_java() {

    if ! brew cask list adoptopenjdk8; then
        echo "Install OpenJDK8..."
        brew tap AdoptOpenJDK/openjdk
        brew cask install adoptopenjdk8
        write_java_profile
    fi

    if [ -z "${JAVA_HOME}" ]; then
        if [ -f "${PROFILES_DIR}"/java.sh ]; then
            # shellcheck source=/dev/null
            source "${PROFILES_DIR}"/java.sh
        else
            write_java_profile
            # shellcheck source=/dev/null
            source "${PROFILES_DIR}"/java.sh
        fi
    fi

    if [ -z "${JAVA_HOME}" ]; then
        echo "JAVA_HOME is not set, exiting"
        exit 1
    fi
}

install_prerequisites() {
    echo "Installing prerequisites ..."
    if [ -z "$(brew --version)" ]; then
        echo "Installing brew..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"   
    fi

    brew update
    brew upgrade
    install_or_check_java
    brew install -f r sbt maven gcc autoconf automake libtool cmake snappy gzip bzip2 zlib openssl

    OPENSSL_ROOT_DIR=$(brew --prefix)/opt/openssl@1.1
    OPENSSL_INCLUDE_DIR="${OPENSSL_ROOT_DIR}/include"
    OPENSSL_SSL_LIBRARY="${OPENSSL_ROOT_DIR}/lib"
    export OPENSSL_ROOT_DIR OPENSSL_INCLUDE_DIR OPENSSL_SSL_LIBRARY

    install_protobuf
}

install_hadoop() {
    if [ -d hadoop ]; then
        rm -rf hadoop
    fi

    echo "Downloading Hadoop-${HADOOP_VERSION} ..."
    git clone https://github.com/apache/hadoop.git
    cd hadoop
    git checkout "rel/release-${HADOOP_VERSION}"

    echo "Patch OpenSSL 1.1"
    curl https://issues.apache.org/jira/secure/attachment/12875105/HADOOP-14597.04.patch | git apply

    echo "Building Hadoop-${HADOOP_VERSION} ..."
    mvn package --quiet \
                -Pdist,native \
                -DskipTests \
                -Dmaven.javadoc.skip=true

    echo "Installing Hadoop-${HADOOP_VERSION} ..."
    cp -R "hadoop-dist/target/hadoop-${HADOOP_VERSION}" "${HADOOP_INSTALL_DIR}"
}

write_hadoop_profile() {
    echo "Setting hadoop environment variables..."
    cat << EOF > "${PROFILES_DIR}"/hadoop.sh
export HADOOP_VERSION=${HADOOP_VERSION}
export HADOOP_HOME=${HADOOP_INSTALL_DIR}
export HADOOP_OPTS="-Djava.library.path=\${HADOOP_HOME}/lib/native"
export LD_LIBRARY_PATH=\${HADOOP_HOME}/lib/native\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export JAVA_LIBRARY_PATH=\${JAVA_LIBRARY_PATH}:\${HADOOP_HOME}/lib/native
export PATH=\${PATH}:\${HADOOP_HOME}/bin
EOF

    cat << EOF >> "${HOME}"/.bash_profile
source ${PROFILES_DIR}/hadoop.sh
EOF

    # shellcheck source=/dev/null
    source "${PROFILES_DIR}"/hadoop.sh
}

cleanup() {
    echo "Deleting build folder: ${TMP_BUILD_DIR} ..."
    cd
    if [ -d "${TMP_BUILD_DIR}" ]; then
        rm -rf "${TMP_BUILD_DIR}"
    fi
}

main() {
    mkdir -p "${PROFILES_DIR}"
    mkdir -p "${TMP_BUILD_DIR}"
    cd "${TMP_BUILD_DIR}"
    install_prerequisites
    install_hadoop
    write_hadoop_profile
    hadoop checknative -a
    cleanup
    echo "Done. Happy Hadooping!!!"
}
    

main
