#!/bin/bash

# 检查并安装依赖工具
check_dependencies() {
    for cmd in curl wget tar; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd 未安装，正在安装..."
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y $cmd
            elif command -v yum &> /dev/null; then
                yum install -y $cmd
            else
                echo "无法自动安装 $cmd，请手动安装它。"
                exit 1
            fi
        fi
    done
}

# 获取最新版本的sing-box并下载到/tmp目录
download_sing_box() {
    latest_version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep "tag_name" | cut -d '"' -f 4 | sed 's/^v//')
    if wget -P /tmp https://github.com/SagerNet/sing-box/releases/download/v$latest_version/sing-box-$latest_version-linux-amd64.tar.gz; then
        mkdir -p /root/sing-box
        tar --strip-components=1 -xzf /tmp/sing-box-$latest_version-linux-amd64.tar.gz -C /root/sing-box
        rm /tmp/sing-box-$latest_version-linux-amd64.tar.gz
    else
        echo "下载 sing-box 失败。"
        exit 1
    fi
}

# 下载配置文件并替换UUID、private_key和short_id
configure_sing_box() {
    if wget -O /root/sing-box/c.json https://github.com/az4399/sing-box-config/raw/main/reality; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
        private_key=$( /root/sing-box/sing-box generate reality-keypair | grep "PrivateKey" | cut -d ' ' -f 2)
        short_id=$( /root/sing-box/sing-box generate rand 8 --hex | tr -d '\n')

        sed -i "s/\"uuid\": \"\"/\"uuid\": \"$uuid\"/" /root/sing-box/c.json
        sed -i "s/\"private_key\": \"\"/\"private_key\": \"$private_key\"/" /root/sing-box/c.json
        sed -i "s/\"short_id\": \[\"\"\]/\"short_id\": [\"$short_id\"]/" /root/sing-box/c.json
    else
        echo "下载配置文件失败。"
        exit 1
    fi
}

# 赋予权限并运行sing-box
run_sing_box() {
    chmod 777 /root/sing-box/sing-box
    /root/sing-box/sing-box run -c /root/sing-box/c.json > /root/sing-box/sing-box.log 2>&1 &
}

# 将sing-box添加到crontab以开机启动
setup_crontab() {
    (crontab -l 2>/dev/null; echo "@reboot /root/sing-box/sing-box run -c /root/sing-box/c.json > /root/sing-box/sing-box.log 2>&1 &") | crontab -
}

# 主函数
main() {
    check_dependencies
    download_sing_box
    configure_sing_box
    run_sing_box
    setup_crontab
}

# 执行主函数
main
