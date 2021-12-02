#!/bin/bash
#set -x
if [ "${IS_VAGRANT}" == "true" ];then
    source "/vagrant/scripts/common.sh"
else
    source "/home/vagrant/scripts/common.sh"
fi

setup_hadoop() {
    local app_name=$1
    local app_name_upper=`get_string_upper ${app_name}`
    local res_dir=$(eval echo \$${app_name_upper}_RES_DIR)
    local conf_dir=$(eval echo \$${app_name_upper}_CONF_DIR)

    log info "creating ${app_name} directories"
    mkdir -p ${INSTALL_PATH}/hadoop/tmp
	
    log info "copying over ${app_name} configuration files"
    cp -f ${res_dir}/* ${conf_dir}

    if [ ${INSTALL_PATH} != /home/vagrant/apps ];then
        sed -i "s@/home/vagrant/apps@${INSTALL_PATH}@g" `grep '/home/vagrant/apps' -rl ${conf_dir}/`
    fi
}

download_hadoop() {
    local app_name=$1
    local app_name_upper=`get_string_upper ${app_name}`
    local app_version=$(eval echo \$${app_name_upper}_VERSION)
    local archive=$(eval echo \$${app_name_upper}_ARCHIVE)
    local download_url=$(eval echo \$${app_name_upper}_MIRROR_DOWNLOAD)

    log info "install ${app_name}"
    if resourceExists ${archive}; then
        installFromLocal ${archive}
    else
        installFromRemote ${archive} ${download_url}
    fi
    mv ${INSTALL_PATH}/"${app_version}" ${INSTALL_PATH}/${app_name}
    sudo chown -R vagrant:vagrant ${INSTALL_PATH}/${app_name}
    rm ${DOWNLOAD_PATH}/${archive}
}

format_hdfs() {
    log info "formatting HDFS"
    hdfs namenode -format
}

start_daemons() {
    log info "starting Hadoop daemons"
    $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
    $HADOOP_PREFIX/sbin/hadoop-daemons.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
    $HADOOP_PREFIX/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
    $HADOOP_PREFIX/sbin/yarn-daemons.sh --config $HADOOP_CONF_DIR start nodemanager
    $HADOOP_PREFIX/sbin/yarn-daemon.sh start proxyserver --config $HADOOP_CONF_DIR
    $HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh start historyserver --config $HADOOP_CONF_DIR

    log info "waiting for HDFS to come up"
    # loop until at least HDFS is up
    cmd="hdfs dfs -ls /"
    NEXT_WAIT_TIME=0
    up=0
    while [  $NEXT_WAIT_TIME -ne 4 ] ; do
        $cmd
        rc=$?
        if [[ $rc == 0 ]]; then
            up=1
            break
        fi
       sleep $(( NEXT_WAIT_TIME++ ))
    done

    if [[ $up != 1 ]]; then
        log info "HDFS doesn't seem to be up; exiting"
        exit $rc
    fi

    log info "listing all Java processes"
    jps
}

setup_hdfs() {
    log info "creating user home directory in hdfs"
    hdfs dfs -mkdir -p /user/root
    hdfs dfs -mkdir -p /user/vagrant
    hdfs dfs -chown vagrant /user/vagrant

    log info "creating temp directories in hdfs"
    hdfs dfs -mkdir -p /tmp
    hdfs dfs -chmod -R 777 /tmp

    hdfs dfs -mkdir -p /var
    hdfs dfs -chmod -R 777 /var
}
install_hadoop() {
    local app_name="hadoop"
    log info "setup ${app_name}"

    download_hadoop ${app_name}
    setup_hadoop ${app_name}
    setupEnv_app ${app_name} sbin
    # 解决Unable to load native-hadoop library for your platform
    #echo 'export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native/:$LD_LIBRARY_PATH' >> ${PROFILE}

    if [ "${IS_VAGRANT}" != "true" ];then
        dispatch_app ${app_name}
    fi

    source ${PROFILE}
    #format_hdfs
    #start_daemons
}

if [ "${IS_VAGRANT}" == "true" ];then
    install_hadoop
fi
