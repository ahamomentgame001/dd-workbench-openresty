#!/bin/bash

# 获取GCP项目ID
project=$(gcloud config get-value project)

# 获取实例所在的区域和名称
location_zone=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)
instance_name=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")

comfyui_key="comfyui-version"

if [ ! -d "/opt/ComfyUI" ]; then
	# 安装ComfyUI
	sudo git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI
	cd /opt/ComfyUI || exit
	sudo pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121
 	sudo pip install -r requirements.txt
	cd /opt/ComfyUI || exit
	git config --global --add safe.directory /opt/ComfyUI
	current_hash=$(git rev-parse HEAD)
	
	# 写入元数据
	gcloud workbench instances update ${instance_name} --metadata=${comfyui_key}=${current_hash} --project=${project} --location=${location_zone}
	
else
  echo "ComfyUI已安装，跳过安装步骤。"
fi



# 检查ComfyUI服务是否已存在
if systemctl --all --type service | grep -q "comfyui.service"; then
  echo "ComfyUI服务已存在，跳过创建步骤。"
else
  echo "创建ComfyUI服务..."
  # 创建Systemd服务单元
  sudo bash -c 'cat > /etc/systemd/system/comfyui.service <<EOF
[Unit]
Description=ComfyUI Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/ComfyUI
ExecStart=/usr/bin/python3 /opt/ComfyUI/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

  # 重新加载Systemd，使新服务生效
  sudo systemctl daemon-reload
  sudo systemctl enable comfyui.service
  sudo systemctl start comfyui.service
fi


# 挂载NFS
NFS_address="10.250.132.58:/models"
mountdir=`curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/attributes/proxy-user-mail" | cut -d'@' -f1`
check_point_dir="/opt/ComfyUI/models/checkpoints"

# 检查/etc/fstab中是否已有挂载条目
if grep -qs "${check_point_dir} " /etc/fstab; then
  echo "${check_point_dir} 的挂载点已存在于fstab中，跳过添加。"
else
  echo "将 ${check_point_dir} 挂载点添加到/etc/fstab..."
  echo "${NFS_address}/${mountdir} ${check_point_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# 检查挂载点是否已挂载
if mount | grep -q "${check_point_dir}"; then
  echo "${check_point_dir} 已挂载，跳过挂载步骤。"
else
  echo "挂载 ${check_point_dir}..."
  sudo apt-get install nfs-common -y
  sudo mount -o rw,intr ${NFS_address}/${mountdir} ${check_point_dir}
fi



# 升级ComfyUI
comfyui_ver=`curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/attributes/${comfyui_key}"`
cd /opt/ComfyUI || exit
git config --global --add safe.directory /opt/ComfyUI
current_hash=$(git rev-parse HEAD)

if [[ "$comfyui_ver" == "null" ]]; then
    echo "未指定ComfyUI版本，正在拉取master分支..."
    sudo git fetch origin
    sudo git checkout master
    sudo git pull origin master
    sudo pip install --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121
    sudo pip install -r requirements.txt
    # 重启服务
    sudo systemctl restart comfyui.service
elif [[ "$current_hash" != "$comfyui_ver" ]]; then
    echo "检测到ComfyUI新版本，正在升级..."
    sudo git fetch origin
    sudo git checkout "${comfyui_ver}"
    sudo pip install --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121
    sudo pip install -r requirements.txt
    # 重启服务
    sudo systemctl restart comfyui.service
else
    echo "ComfyUI无需更新。"
fi


# install openresty
if [ ! -d "/usr/local/openresty" ]; then
  sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates
  wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
  codename=`grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release`
  echo "deb http://openresty.org/package/debian $codename openresty" | sudo tee /etc/apt/sources.list.d/openresty.list
  sudo apt-get update --allow-releaseinfo-change
  sudo apt-get -y install openresty
  sudo opm get ledgetech/lua-resty-http

# configure nginx lua
  sudo wget -O /usr/local/openresty/nginx/conf/nginx.conf https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/nginx.conf
  sudo wget -O /usr/local/openresty/lualib/last_activity.lua https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/last_activity.lua
  sudo systemctl reload openresty

else
  echo "openresty已安装,跳过安装步骤."
fi
