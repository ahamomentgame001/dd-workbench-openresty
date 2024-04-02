#!/bin/bash

# 获取GCP项目ID
project=$(gcloud config get-value project)

# 获取实例所在的区域和名称
location_zone=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)
instance_name=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")

comfyui_key="comfyui-version"

home_dir="/home/jupyter/ComfyUI"


if [ ! -d ${home_dir} ]; then
    # 安装ComfyUI
    su - jupyter -c "git clone https://github.com/comfyanonymous/ComfyUI.git ${home_dir}"

    su - jupyter -c "pip install --user --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121"
    su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"

    su - jupyter -c "cd /home/jupyter/ComfyUI && git config --global --add safe.directory /home/jupyter/ComfyUI"
    current_hash=$(su - jupyter -c "cd /home/jupyter/ComfyUI && git rev-parse HEAD")
    su - jupyter -c "sudo gcloud workbench instances update ${instance_name} --metadata=${comfyui_key}=${current_hash} --project=${project} --location=${location_zone}"

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
User=jupyter
WorkingDirectory=/home/jupyter/ComfyUI
ExecStart=/opt/conda/bin/python3 /home/jupyter/ComfyUI/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

  # 重新加载Systemd，使新服务生效
  sudo systemctl daemon-reload
  sudo systemctl enable comfyui.service
  sudo systemctl start comfyui.service
fi



# 升级ComfyUI
comfyui_ver=`curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/attributes/${comfyui_key}"`
cd ${home_dir} || exit
git config --global --add safe.directory ${home_dir}
current_hash=$(git rev-parse HEAD)

if [[ "$comfyui_ver" == "null" ]]; then
    echo "未指定ComfyUI版本，正在拉取master分支..."
    git fetch origin
    git checkout master
    su - jupyter -c "git pull origin master"
    su - jupyter -c "pip install --user --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121"
    su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"
    # 重启服务
    sudo systemctl restart comfyui.service
elif [[ "$current_hash" != "$comfyui_ver" ]]; then
    echo "检测到ComfyUI新版本，正在升级..."
    git fetch origin
    git checkout "${comfyui_ver}"
    su - jupyter -c "pip install --user --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121"
    su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"
    # 重启服务
    sudo systemctl restart comfyui.service
else
    echo "ComfyUI无需更新。"
fi



# 挂载NFS
NFS_address="10.97.68.98:/vol1"
mountdir=`curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/attributes/proxy-user-mail" | cut -d'@' -f1`
check_point_dir="/home/jupyter/ComfyUI/models/checkpoints"

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
