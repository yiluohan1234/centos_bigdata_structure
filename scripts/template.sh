#!/bin/bash
#set -x

if [ "$IS_VAGRANT" == "true" ];then
    source "/vagrant/scripts/common.sh"
else
    source "/home/vagrant/scripts/common.sh"
fi


setup_#@() {
    local app_name=$1
    local app_name_upper=`get_string_upper ${app_name}`
    local res_dir=$(eval echo \$${app_name_upper}_RES_DIR)
    local conf_dir=$(eval echo \$${app_name_upper}_CONF_DIR)

    log info "create ${app_name} configuration directories"
    mkdir -p ${INSTALL_PATH}/elasticsearch/datas
    mkdir -p ${INSTALL_PATH}/elasticsearch/logs

    log info "copying over ${app_name} configuration files"
    # 将resources配置文件拷贝到插件的配置目录
    cp -f $res_dir/* $conf_dir
    
    # 配置环境中不同节点配置不同的情况
    if [ "${IS_VAGRANT}" == "true" ];then
        hostname=`cat /etc/hostname`
        node_host=`cat /etc/hosts |grep ${hostname}|awk '{print $1}'`
        file_path=${INSTALL_PATH}/${app_name}/config/elasticsearch.yml
        
        echo "------modify $i server.properties-------"
        #sed -i 's/^node.name: .*/node.name: '$hostname'/' $file_path
        sed -i 's@^network.host: .*@network.host: '${node_host}'@' ${file_path}
    fi
}

download_#@() {
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

dispatch_#@() {
    local app_name=$1
    dispatch_app ${app_name}
    for i in {"hdp102","hdp103"};
    do
        node_name=$i
        node_host=`cat /etc/hosts |grep $i|awk '{print $1}'`
        file_path=${INSTALL_PATH}/${app_name}/config/elasticsearch.yml

        echo "------modify $i server.properties-------"
        #ssh $i "sed -i 's/^node.name: .*/node.name: '$node_name'/' $file_path"
        ssh $i "sed -i 's@^network.host: .*@network.host: '${node_host}'@' ${file_path}"
    done
}

install_#@() {
    local app_name="#@"
    log info "setup ${app_name}"

    download_#@ ${app_name}
    setup_#@ ${app_name}
    #setupEnv_app $app_name
    #dispatch_app $app_name
    # if [ "${IS_VAGRANT}" != "true" ];then
    #     dispatch_es ${app_name}
    # fi
    source ${PROFILE}
}


if [ "${IS_VAGRANT}" == "true" ];then
    install_#@
fi
install_#@
