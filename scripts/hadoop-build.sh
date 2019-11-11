#!/usr/bin/env bash

set -euo pipefail

HADOOP_VERSION=${HADOOP_VERSION:-2.8.5}
HADOOP_INSTALL_DIR=${HADOOP_INSTALL_DIR:-$HOME/bin/hadoop-${HADOOP_VERSION}}

TMP_BUILD_DIR=/tmp/hadoop-${HADOOP_VERSION}

install_protobuf() {
    PROTO_VERSION=2.5.0

    PROTO_TGZ="protobuf-${PROTO_VERSION}.tar.gz"
    echo "Downloading ${PROTO_TGZ} ..."
    curl --location --silent \
         "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTO_VERSION}/${PROTO_TGZ}" \
       | tar -xf -

    echo "Building Protobuff ${PROTO_VERSION} ..."
    cd protobuf-${PROTO_VERSION}
    ./configure --silent
    make --silent --jobs install >/dev/null 2>&1
    protoc --version
    cd ..
    rm -rf protobuf-${PROTO_VERSION}
}

install_prerequisites() {
    echo "Install prerequisites ..."
    brew install maven gcc autoconf automake libtool cmake snappy gzip bzip2 zlib openssl
    ln -f -s /usr/local/include/opt/openssl/include/openssl /usr/local/include/openssl
    install_protobuf
}

patch_hadoop_bzip2() {
    echo '
diff --git a/hadoop-common-project/hadoop-common/src/CMakeLists.txt b/hadoop-common-project/hadoop-common/src/CMakeLists.txt
index c93bfe78546..a46b7534e9d 100644
--- a/hadoop-common-project/hadoop-common/src/CMakeLists.txt
+++ b/hadoop-common-project/hadoop-common/src/CMakeLists.txt
@@ -50,8 +50,8 @@ get_filename_component(HADOOP_ZLIB_LIBRARY ${ZLIB_LIBRARIES} NAME)

 # Look for bzip2.
 set(STORED_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
-hadoop_set_find_shared_library_version("1")
-find_package(BZip2 QUIET)
+hadoop_set_find_shared_library_version("1.0")
+find_package(BZip2 REQUIRED)
 if(BZIP2_INCLUDE_DIR AND BZIP2_LIBRARIES)
     get_filename_component(HADOOP_BZIP2_LIBRARY ${BZIP2_LIBRARIES} NAME)
     set(BZIP2_SOURCE_FILES
diff --git a/hadoop-common-project/hadoop-common/src/main/conf/core-site.xml b/hadoop-common-project/hadoop-common/src/main/conf/core-site.xml
index d2ddf893e49..90880c3a984 100644
--- a/hadoop-common-project/hadoop-common/src/main/conf/core-site.xml
+++ b/hadoop-common-project/hadoop-common/src/main/conf/core-site.xml
@@ -17,4 +17,8 @@
 <!-- Put site-specific property overrides in this file. -->

 <configuration>
+   <property>
+      <name>io.compression.codec.bzip2.library</name>
+      <value>libbz2.dylib</value>
+   </property>
 </configuration>
' > /tmp/bzip2.patch
    git apply /tmp/bzip2.patch
    rm /tmp/bzip2.patch
}

install_hadoop() {
    echo "Downloading Hadoop-${HADOOP_VERSION} ..."
    git clone https://github.com/apache/hadoop.git
    cd hadoop
    git checkout "branch-${HADOOP_VERSION}"

    echo "Building Hadoop-${HADOOP_VERSION} ..."
    patch_hadoop_bzip2
    mvn package --quiet \
                -Pdist,native \
                -DskipTests \
                -Dmaven.javadoc.skip=true

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
    echo "Deleting build folder: ${TMP_BUILD_DIR} ..."
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
