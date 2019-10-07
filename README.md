# spark-custom-build
## Description
This script will build spark, configure, and install as follows:
- Using the env variables 
  * SPARK_VERSION (default: 2.4.4)
  * HADOOP_VERSION (default: 2.8.5)
  * AWS_VERSION (default: 1.11.646)
  * SPARK_INSTALL_DIR (default: $HOME/spark-${SPARK_VERSION}-with-hadoop-${HADOOP_VERSION})
- Download sources
- Build
- Download Hadoop-aws ${HADOOP_VERSION} and aws-java-sdk{,core,s3} ${AWS_VERSION}
- Set Spark log level to WARN
- Install to ${SPARK_INSTALL_DIR}
- Set SPARK_HOME and update PATH in ~/.bash_profile

## Use Token Temporary AWS Credentials with the following configuration
```bash
spark-submit --master local[4] \
             --conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.TemporaryAWSCredentialsProvider \
             --conf spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID} \
             --conf spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY} \
             --conf spark.hadoop.fs.s3a.session.token=${AWS_SESSION_TOKEN} \
             ...
```
