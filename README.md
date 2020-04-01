# Hadoop and Spark Mac OS Custom Build
## Description
Download, configure and install custom versions of Hadoop and Spark for Mac OS with native library support.
### Hadoop Build
#### Description
Use native Mac OS libraries including (hadoop, zlib, nsappy, lz4, bzip2, openssl)
This script will download, build, configure, and install a local install as follows:
- Using environment variables:
  * HADOOP_VERSION (default: 2.8.5)
  * HADOOP_INSTALL_DIR (default: $HOME/bin/hadoop-${HADOOP_VERSION})
- Download sources and checkout to specified version
- Patch for libbz2
- Build
- Install to ${HADOOP_INSTALL_DIR}
- Set environment variables in ~/.bash_profile
### Spark Build
#### Description
This script will download, build, configure, and install a local install as follows:
- Using environment variables:
  * SPARK_VERSION (default: v3.0.0-rc1)
  * HADOOP_VERSION (default: 2.8.5)
  * AWS_VERSION (default: 1.11.646)
  * SPARK_INSTALL_DIR (default: $HOME/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION})
- Download sources
- Build
- Download Hadoop-aws ${HADOOP_VERSION} and aws-java-sdk{,core,s3} ${AWS_VERSION}
- Set Spark log level to WARN
- Install to ${SPARK_INSTALL_DIR}
- Set SPARK_HOME and update PATH in ~/.bash_profile

#### Use Token Temporary AWS Credentials with the following configuration
```bash
spark-submit --master local[*] \
             --conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.TemporaryAWSCredentialsProvider \
             --conf spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID} \
             --conf spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY} \
             --conf spark.hadoop.fs.s3a.session.token=${AWS_SESSION_TOKEN} \
             ...
```
