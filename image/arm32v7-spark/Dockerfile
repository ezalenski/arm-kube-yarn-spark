FROM ezalenski/arm32v7-hadoop:2.8.2

ARG SPARK_VERSION=
ADD spark-${SPARK_VERSION}-bin-hadoop2.7.tgz /usr/local

ENV SPARK_HOME /usr/local/spark

RUN cd /usr/local && ln -s spark-${SPARK_VERSION}-bin-hadoop2.7 spark

RUN \
    $BOOTSTRAP && \
    $HADOOP_PREFIX/bin/hadoop dfsadmin -safemode leave && \
    $HADOOP_PREFIX/bin/hdfs dfs -put $SPARK_HOME-2.2.1-bin-hadoop2.7/lib /spark

ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV PATH $PATH:$SPARK_HOME/bin:$HADOOP_PREFIX/bin
# update boot script

WORKDIR $SPARK_HOME

# expose spark ports