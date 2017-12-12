FROM ezalenski/arm32v7-hadoop:2.8.2

ARG SPARK_VERSION=
ADD spark-${SPARK_VERSION}-bin-hadoop2.7.tgz /usr/local

ENV SPARK_HOME /usr/local/spark

RUN cd /usr/local && ln -s spark-${SPARK_VERSION}-bin-hadoop2.7 spark

ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV PATH $PATH:$SPARK_HOME/bin:$HADOOP_PREFIX/bin
# update boot script

WORKDIR $SPARK_HOME

# expose spark ports
EXPOSE 8080 7077