INSTALL_PATH=/root/software
PROFILE=/etc/profile
SOFT_PATH=/root/software

setssh() {
ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'`
echo "$ip hadoop000" >> /etc/hosts
ssh -o StrictHostKeyChecking=no hadoop000
}

hdp(){
usage="Usage: hdp (format|start|stop)"

if [ $# -lt 1 ]; then
    echo $usage
    exit 1
fi
case $1 in
    start)
        ${HADOOP_HOME}/sbin/start-all.sh
        ;;
    stop)
        ${HADOOP_HOME}/sbin/stop-all.sh
        ;;
    format)
        hadoop namenode -format
        ;;
    leave)
        echo "hdfs dfsadmin -safemode enter/leave/get"
        hdfs dfsadmin -safemode leave
        ;;
    nocheck)
        echo 'export HADOOP_SSH_OPTS="-o StrictHostKeyChecking=no"' >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
        ;;
    *)
        echo $usage
        ;;
esac
}

sethive(){
usage="Usage: sethive (start|init|create)"

if [ $# -lt 1 ]; then
    echo $usage
    exit 1
fi
local type=$1
local table_name=${2:-"hive"}
case $type in
    start)
        mysql -uroot -p123456 -e "select version();" &>/dev/null
        if [ $? -ne 0 ];then
            systemctl start mysqld
        fi
        ;;
    init)
        schematool -dbType mysql -initSchema
        ;;
    create)
        hive -e "create database if not exists ${table_name};show databases;"
        ;;
    *)
        echo $usage
        ;;
esac
}

replace_keyword() {
local key=$1
local val=$2
local file=$3

# backup
[ ! -f ${file}_back ] && cp ${file} ${file}_back

echo -e "\033[31m------------------- ${file} key:value -------------------\033[0m"
echo "${key}=${val}"

if [ `cat ${file} |grep "^${key}" |wc -l` -ne 0 ];then
    sed -i "s@^${key}=.*@${key}=${val}@" ${file}
    echo "${key} replace success!"
else
    echo "${key}=${val}" >> ${file}
    echo "add ${key} success!"
fi
}

setazkaban() {
local azkaban_path=/root/software/azkaban
local azkaban_raw_path=/root/software/azkaban-3.90.0
local db_file=${azkaban_path}/azkaban-db-0.1.0-SNAPSHOT/create-all-sql-0.1.0-SNAPSHOT.sql
local web_server_file=${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/conf/azkaban.properties
local exec_server_file=${azkaban_path}/azkaban-exec-server-0.1.0-SNAPSHOT/conf/azkaban.properties
local web_user_file=${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/conf/azkaban-users.xml

mysql -uroot -p123456 -e "select version();" &>/dev/null
if [ $? -ne 0 ];then
    systemctl start mysqld
fi

mysql -uroot -p123456 -e "create database if not exists azkaban;grant all privileges ON azkaban.* to 'qingjiao'@'%' with grant option;flush privileges;"

[ ! -d ${azkaban_path} ] && mkdir -p ${azkaban_path}
tar -zxf ${azkaban_raw_path}/azkaban-db/build/distributions/azkaban-db-0.1.0-SNAPSHOT.tar.gz -C ${azkaban_path}

mysql -uroot -p123456 azkaban < ${db_file}

tar -zxf ${azkaban_raw_path}/azkaban-web-server/build/distributions/azkaban-web-server-0.1.0-SNAPSHOT.tar.gz -C ${azkaban_path}

# gen key
key_path=${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/keystore
keytool -keystore ${key_path} -alias jetty -genkey -keyalg RSA  << eof
123456
123456





CN
Y
123456
123456
eof

# modify web server configuration
echo "web server configuration"
replace_keyword "default.timezone.id" "Asia/Shanghai" ${web_server_file}
replace_keyword "mysql.user" "qingjiao" ${web_server_file}
replace_keyword "mysql.password" "123456" ${web_server_file}
# jetty configuration
replace_keyword "jetty.use.ssl" "true" ${web_server_file}
replace_keyword "jetty.ssl.port" "8443" ${web_server_file}
replace_keyword "jetty.keystore" "${key_path}" ${web_server_file}
replace_keyword "jetty.password" "123456" ${web_server_file}
replace_keyword "jetty.keypassword" "123456" ${web_server_file}
replace_keyword "jetty.truststore" "${key_path}" ${web_server_file}
replace_keyword "jetty.trustpassword" "123456" ${web_server_file}

# modify web server user configuration
sed -i '/user password/a\  <user password="admin" roles="metrics,admin" username="admin"/>' ${web_user_file}
# modify exec server configuration
tar -zxvf ${azkaban_raw_path}/azkaban-exec-server/build/distributions/azkaban-exec-server-0.1.0-SNAPSHOT.tar.gz -C ${azkaban_path}
replace_keyword "default.timezone.id" "Asia/Shanghai" ${exec_server_file}
replace_keyword "mysql.user" "qingjiao" ${exec_server_file}
replace_keyword "mysql.password" "123456" ${exec_server_file}
replace_keyword "executor.port" "12321" ${exec_server_file}

# derby auto import
cp ${HIVE_HOME}/lib/derby-10.10.2.0.jar ${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/lib/
cp ${HIVE_HOME}/lib/derby-10.10.2.0.jar ${azkaban_path}/azkaban-exec-server-0.1.0-SNAPSHOT/lib/

# log4j conflict
mv ${azkaban_path}/azkaban-exec-server-0.1.0-SNAPSHOT/lib/slf4j-log4j12-1.7.21.jar ${azkaban_path}/azkaban-exec-server-0.1.0-SNAPSHOT/lib/slf4j-log4j12-1.7.21.jar.bak
mv ${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/lib/slf4j-log4j12-1.7.18.jar ${azkaban_path}/azkaban-web-server-0.1.0-SNAPSHOT/lib/slf4j-log4j12-1.7.18.jar.bak
}

mr_azkaban() {
echo "type=command" >> /root/data/put.job
echo "command=hdfs dfs -put /root/data/word.txt /" >> /root/data/put.job

echo "type=command" >> /root/data/mapreduce.job
echo "dependencies=put" >> /root/data/mapreduce.job
echo "command=hadoop jar /root/software/hadoop-2.7.7/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.7.jar wordcount /word.txt /wordcount" >> /root/data/mapreduce.job
[ -f /root/mapreduce.zip ] && rm -rf /root/mapreduce.zip
zip /root/mapreduce.zip /root/data/put.job /root/data/mapreduce.job

}

hive_azkaban() {
cat > /root/data/hivef.sql << eof
use default;
create table if not exists student(id int, name string)
row format delimited fields terminated by ',';
load data local inpath '/root/data/student.txt' into table student;
insert into student values (1100,'qingjiao');
insert overwrite local directory '/root/data/student'
row format delimited fields terminated by '\t'
select * from student;
eof

echo "type=command" >> /root/data/hivef.job
echo "command=hive -f /root/data/hivef.sql" >> /root/data/hivef.job

[ -f /root/hivef.zip ] && rm -rf /root/hivef.zip
zip /root/hivef.zip /root/data/hivef.job

}


azkaban(){
    usage="Usage: azkaban (start|stop)"

    if [ $# -lt 1 ]; then
        echo $usage
        exit 1
    fi
    case $1 in
        start)
            echo "============ start azkaban-web-and-exec-server ============"
            cd /root/software/azkaban/azkaban-exec-server-0.1.0-SNAPSHOT && bin/start-exec.sh && cd
            sleep 3s
            cd /root/software/azkaban/azkaban-exec-server-0.1.0-SNAPSHOT && curl -G "localhost:$(<./executor.port)/executor?action=activate" && echo && cd
            cd /root/software/azkaban/azkaban-web-server-0.1.0-SNAPSHOT && bin/start-web.sh && cd
            ;;
        stop)
            echo "============ stop azkaban-web-and-exec-server ============"
            cd /root/software/azkaban/azkaban-web-server-0.1.0-SNAPSHOT && bin/shutdown-web.sh && cd
            cd /root/software/azkaban/azkaban-exec-server-0.1.0-SNAPSHOT && bin/shutdown-exec.sh && cd
            ;;
        *)
            echo $usage
            ;;
    esac
}

# set_property "fs.defaultFS=hdfs://master:9000" ${HADOOP_HOME}/etc/hadoop/core-site.xml true
setkv() {
    local key_value=$1
    local properties_file=$2
    local is_create=$3
    [ -z "${is_create}" ] && is_create=false

    if [ "${is_create}" == "false" ]
    then
        sed -i "/<\/configuration>/Q" ${properties_file}
    else
        [ ! -f ${properties_file} ] && touch ${properties_file}
        echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' >> ${properties_file}
        echo '<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>' >> ${properties_file}
        echo '<configuration>' >> ${properties_file}
    fi
    name=`echo $key_value|cut -d "=" -f 1`
    value=`echo $key_value|cut -d "=" -f 2-`
    echo "  <property>" >> ${properties_file}
    echo "    <name>$name</name>" >> ${properties_file}
    echo "    <value>$value</value>" >> ${properties_file}
    echo "  </property>" >> ${properties_file}
    echo "</configuration>" >> ${properties_file}
}

updatekafka() {
local host_external=$1
local host_internal=hadoop000
local file=${KAFKA_HOME}/config/server.properties
# backup
echo -n "is or not backup? (y/N) "
read is_backup
if [ "${is_backup}" == "y" ];then
    cp ${file} ${file}_bak
fi
replace_keyword "listeners" "PLAINTEXT://${host_internal}:9092" ${file}
replace_keyword "host.name" "${host_internal}" ${file}
replace_keyword "advertised.listeners" "PLAINTEXT://${host_external}:9092" ${file}
replace_keyword "advertised.host.name" "${host_external}" ${file}
replace_keyword "zookeeper.connect" "${host_external}:2181" ${file}
}

updatezk() {
local host_external=$1
local file=${ZOOKEEPER_HOME}/conf/zoo.cfg
# backup
echo -n "is or not backup? (y/N) "
read is_backup
if [ "${is_backup}" == "y" ];then
    cp ${file} ${file}_back
fi
replace_keyword "server.1" "${host_external}:2888:3888" ${file}
}

updatehbase(){
local host_external=$1
local file=${HBASE_HOME}/conf/hbase-site.xml
# backup
echo -n "is or not backup? (y/N) "
read is_backup
if [ "${is_backup}" == "y" ];then
    cp ${file} ${file}_back
fi
sed -i "s/X.X.X.X/${host_external}/" ${file}
}

kafka(){
    usage="Usage: kafka (start|stop)"

    local type=$1
    local table_name=${2:-"iotTopic"}
    if [ $# -lt 1 ]; then
        echo $usage
        exit 1
    fi
    case $type in
        start)
            ${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_HOME}/config/server.properties
            ;;
        stop)
            ps -ef | awk '/Kafka/ && !/awk/{print $2}' | xargs kill -9
            ;;
        create)
            echo "kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 3 --topic ${table_name}"
            ;;
        *)
            echo $usage
            ;;
    esac
}

zk(){
    usage="Usage: zk (start|stop|status)"

    if [ $# -lt 1 ]; then
        echo $usage
        exit 1
    fi
    case $1 in
        start)
            ${ZOOKEEPER_HOME}/bin/zkServer.sh start
            ;;
        stop)
            ${ZOOKEEPER_HOME}/bin/zkServer.sh stop
            ;;
        status)
            ${ZOOKEEPER_HOME}/bin/zkServer.sh status
            ;;
        *)
            echo $usage
            ;;
    esac
}

hb(){
    usage="Usage(hbase): hbase (start|stop)"

    if [ $# -lt 1 ]; then
        echo $usage
        exit 1
    fi
    case $1 in
        start)
            ${HBASE_HOME}/bin/start-hbase.sh
            ;;
        stop)
            ${HBASE_HOME}/bin/stop-hbase.sh
            ;;
        create)
            echo "echo \"create 'default:spark_iot','info'\" |hbase shell"
            echo "kafka-console-consumer.sh --bootstrap-server qingjiao:9092 --topic iotTopic --from-beginning"
            ;;
        *)
            echo $usage
            ;;
    esac
}

spark(){
    usage="Usage(spark): spark (start|stop)"

    if [ $# -lt 1 ]; then
        echo $usage
        exit 1
    fi
    case $1 in
        start)
            ${SPARK_HOME}/sbin/start-all.sh
            ;;
        stop)
            ${SPARK_HOME}/sbin/stop-all.sh
            ;;
        *)
            echo $usage
            ;;
    esac
}

setenv() {
    local app_name=$1
    local app_path=$2
    local type_name=$3

    local app_name_uppercase=$(echo $app_name | tr '[a-z]' '[A-Z]')
    echo "# $app_name environment" >> $PROFILE
    echo "export ${app_name_uppercase}_HOME=$app_path" >> $PROFILE
    if [ ! -n "$type_name" ];then
        echo 'export PATH=$PATH:${'$app_name_uppercase'_HOME}/bin' >> $PROFILE
    else
        echo 'export PATH=$PATH:${'$app_name_uppercase'_HOME}/bin:${'$app_name_uppercase'_HOME}/sbin' >> $PROFILE
    fi

    if [ "$app_name" == "hadoop" ];then
        echo 'CLASSPATH=$CLASSPATH:$HADOOP_HOME/lib' >> $PROFILE
    fi
    echo -e "\n" >> $PROFILE
}

setsqoop() {
local sqoop_dir=${INSTALL_PATH}/sqoop-1.4.7.bin__hadoop-2.6.0
tar -zxf ${SOFT_PATH}/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz -C ${INSTALL_PATH}
# setup
cp ${sqoop_dir}/conf/sqoop-env-template.sh ${sqoop_dir}/conf/sqoop-env.sh
echo "export HADOOP_COMMON_HOME=${HADOOP_HOME}" >> ${sqoop_dir}/conf/sqoop-env.sh
echo "export HADOOP_MAPRED_HOME=${HADOOP_HOME}" >> ${sqoop_dir}/conf/sqoop-env.sh

cp ${SOFT_PATH}/mysql-connector-java-*.jar ${sqoop_dir}/lib/

# set environment
setenv sqoop ${sqoop_dir}
source $PROFILE

# sqoop import --connect "jdbc:mysql://localhost:3306/major?useSSL=false&serverTimezone=UTC" --username root --password 123456 --table school --target-dir '/major/school' --fields-terminated-by ',' -m 1
# sqoop import --connect "jdbc:mysql://localhost:3306/major?useSSL=false&serverTimezone=UTC" --username root --password 123456 --table professional --target-dir '/major/professional' --fields-terminated-by ',' -m 1

}

setflume() {
local flume_dir=${INSTALL_PATH}/apache-flume-1.9.0-bin
tar -zxf ${SOFT_PATH}/apache-flume-1.9.0-bin.tar.gz -C ${INSTALL_PATH}
# setup
cp ${flume_dir}/conf/flume-env.sh.template ${flume_dir}/conf/flume-env.sh
sed -i "s@^# export JAVA_HOME=.*@export JAVA_HOME=${JAVA_HOME}@" ${flume_dir}/conf/flume-env.sh
#sed -i 's@^# export JAVA_OPTS=".-*@export JAVA_OPTS="-Xms100m -Xmx2000m -Dcom.sun.management.jmxremote"@' ${flume_dir}/conf/flume-env.sh

mv ${flume_dir}/lib/guava-11.0.2.jar ${flume_dir}/lib/guava-11.0.2.jar.bak

log4j_path=${flume_dir}/conf/log4j.properties
log_path=${flume_dir}/logs
sed -i 's@^flume.log.dir=.*@flume.log.dir='${log_path}'@' ${log4j_path}

# set environment
setenv flume ${flume_dir}
source $PROFILE
#nohup /opt/module/flume/bin/flume-ng agent -n a1 -c /opt/module/flume/conf -f /opt/module/flume/job/kafka_to_hdfs_log.conf >/dev/null 2>&1 &

}
