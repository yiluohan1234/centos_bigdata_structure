setssh() {
ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'`
echo "$ip hadoop000" >> /etc/hosts
ssh -o StrictHostKeyChecking=no hadoop000
#ssh hadoop000
#cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
#ssh-copy-id hadoop000
}

sethadoop(){
usage="Usage: $0 (start|stop|format)"

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
    *)
        echo $usage
        ;;
esac
}

sethive(){
usage="Usage: sethive (start|stop|format)"

if [ $# -lt 1 ]; then
    echo $usage
    exit 1
fi
case $1 in
    start)
        systemctl start mysqld
        ;;
    init)
        schematool -dbType mysql -initSchema
        ;;
    create)
        hive -e "create database hive;"
        ;;
    *)
        echo $usage
        ;;
esac
}

setspark(){
${SPARK_HOME}/sbin/start-all.sh
}

replace_keyword() {
local key=$1
local val=$2
local file=$3
echo -e "\033[31m--------------------- Befor replace ---------------------\033[0m"
cat ${file} |grep "^${key}="
echo -e "\033[31m--------------------- After replace ---------------------\033[0m"
echo "${key}=${val}"
echo -n "is or not replace? (y/N) "
read is_replace
if [ "${is_replace}" == "y" ];then
    sed -i "s@^${key}=.*@${key}=${val}@" ${file}
    echo "${key} replace success!"
fi
}

replace_kafka_conf() {
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
echo -n "is or not start? (y/N) "
read is_start
if [ "${is_start}" == "y" ];then
    ${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_HOME}/config/server.properties
fi
}

replace_zk_conf() {
local host_external=$1
local file=${ZOOKEEPER_HOME}/conf/zoo.cfg
# backup
echo -n "is or not backup? (y/N) "
read is_backup
if [ "${is_backup}" == "y" ];then
    cp ${file} ${file}_back
fi
replace_keyword "server.1" "${host_external}:2888:3888" ${file}
echo -n "is or not start? (y/N) "
read is_start
if [ "${is_start}" == "y" ];then
   ${ZOOKEEPER_HOME}/bin/zkServer.sh start
fi
}

replace_hbase_conf(){
local host_external=$1
local file=${HBASE_HOME/conf/hbase-site.xml
# backup
echo -n "is or not backup? (y/N) "
read is_backup
if [ "${is_backup}" == "y" ];then
    cp ${file} ${file}_back
fi
sed -i "s/X.X.X.X/${host_external}/" ${file}
echo -n "is or not start? (y/N) "
read is_start
if [ "${is_start}" == "y" ];then
    ${HBASE_HOME}/bin/start-hbase.sh
fi
}
