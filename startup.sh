#!/bin/bash

# 获取GCP项目ID
project=$(gcloud config get-value project)

# 获取实例所在的区域和名称
location_zone=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)
instance_name=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")

group_name_code=$(curl -s -w "%{http_code}" -o /tmp/response.txt "http://metadata.google.internal/computeMetadata/v1/instance/attributes/group_name" -H "Metadata-Flavor: Google")

if [ "$group_name_code" -eq 200 ]; then
    group_name=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/group_name" -H "Metadata-Flavor: Google")
else
    group_name="null"
fi


comfyui_key="comfyui-version"

home_dir="/home/jupyter/ComfyUI"
comfyui_manager_dir="/home/jupyter/ComfyUI/custom_nodes/ComfyUI-Manager"

if [ ! -d ${home_dir} ]; then
    # 安装ComfyUI
    su - jupyter -c "git clone https://github.com/comfyanonymous/ComfyUI.git ${home_dir}"
    su - jupyter -c "mv ${home_dir}/custom_nodes/ ${home_dir}/custom_nodes_example/"
    su - jupyter -c "rm -rf ${HOME_DIR}/models/controlnet && rm -rf ${HOME_DIR}/custom_nodes && rm -rf ${HOME_DIR}/output"
    #su - jupyter -c "rm -rf ${HOME_DIR}/models/checkpoints && rm -rf ${HOME_DIR}/models/loras && rm -rf ${HOME_DIR}/models/controlnet && rm -rf ${HOME_DIR}/custom_nodes && rm -rf ${HOME_DIR}/output"
else
  echo "ComfyUI 已 clone,跳过此步骤."
fi



# 挂载 NFS 目录
NFS_ADDRESS="10.97.68.98:/vol1"
#NFS_ADDRESS="10.16.82.130:/vol1"
HOME_DIR="/home/jupyter/ComfyUI"
MNT_NFS_DIR="/mnt/nfs/"

sudo mkdir -p "${MNT_NFS_DIR}"

# 获取个人 NFS 目录的名称
HOSTNAME=$(hostname)
PERSONS_NFS_DIR=`echo ${HOSTNAME}| sed 's/-/\./g' | sed 's/^/accounts.google.com./g' | sed 's/$/\.com/'`

# 检查 NFS 共享目录是否已挂载
if mount | grep -q "${MNT_NFS_DIR}"; then
  echo "NFS 共享目录已挂载到 ${MNT_NFS_DIR},跳过挂载步骤."
else
  # 挂载 NFS 共享目录
  sudo apt-get install nfs-common -y
  sudo mount -o rw,intr ${NFS_ADDRESS} ${MNT_NFS_DIR}
fi

# 检查 /etc/fstab 中是否已有挂载条目
if grep -qs "${NFS_ADDRESS}" /etc/fstab; then
  echo "${NFS_ADDRESS} 的挂载点已存在于 fstab 中,跳过添加."
else
  # 将挂载点添加到 /etc/fstab
  echo "${NFS_ADDRESS} ${MNT_NFS_DIR} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# 检查个人目录是否存在
if [ ! -d "${MNT_NFS_DIR}${PERSONS_NFS_DIR}" ]; then
  # 创建个人目录
  echo "创建 ${PERSONS_NFS_DIR} 个人目录."
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/custom-model/persons"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/extensions"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/sd-config"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/sd-custom-model/persons"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-extensions/persons"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-outputs/persons"
  mkdir -p "${MNT_NFS_DIR}${PERSONS_NFS_DIR}/outputs"
else
  echo "${PERSONS_NFS_DIR} 个人目录已存在."
fi

  # 检查是否存在 组 
if [[ "$GROUP_NAME" == "null" ]]; then
  # 组 ${GROUP_NAME} 参数为空
  echo "创建 ${PERSONS_NFS_DIR} 全局和个人 软链接."

  ##挂载models/checkpoint
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/sd-custom-model ${HOME_DIR}/models/checkpoints/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/sd_models/Stable-diffusion ${HOME_DIR}/models/checkpoints/global"

  ##挂载models/loras
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/custom-model ${HOME_DIR}/models/loras/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/sd_models/lora ${HOME_DIR}/models/loras/global"

  ##挂载models/controlnet
  su - jupyter -c "ln -s ${MNT_NFS_DIR}extension_controlnet ${HOME_DIR}/models/controlnet"

  ##挂载 custom_nodes
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-extensions ${HOME_DIR}/custom_nodes/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}comfyui-extensions/global ${HOME_DIR}/custom_nodes/global"

  ##挂载 output
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-outputs ${HOME_DIR}/output/persons"

  # 添加权限
  chmod -R 777 "${MNT_NFS_DIR}${PERSONS_NFS_DIR}"

else
  echo "创建 ${PERSONS_NFS_DIR} 全局、组和个人 软链接."
  ##挂载models/checkpoint
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/sd-custom-model ${HOME_DIR}/models/checkpoints/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/group_sd_models/${GROUP_NAME}/sd_models/Stable-diffusion ${HOME_DIR}/models/checkpoints/groups"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/sd_models/Stable-diffusion ${HOME_DIR}/models/checkpoints/global"

  ##挂载models/loras
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/custom-model ${HOME_DIR}/models/loras/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/group_sd_models/${GROUP_NAME}/sd_models/Lora ${HOME_DIR}/models/loras/groups"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}sd-bigmodel/sd_models/lora ${HOME_DIR}/models/loras/global"

  ##挂载models/controlnet
  su - jupyter -c "ln -s ${MNT_NFS_DIR}extension_controlnet ${HOME_DIR}/models/controlnet"

  ##挂载 custom_nodes
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-extensions/ ${HOME_DIR}/custom_nodes/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}comfyui-extensions/group/${GROUP_NAME}/ ${HOME_DIR}/custom_nodes/groups"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}comfyui-extensions/global ${HOME_DIR}/custom_nodes/global"

  ##挂载 output
  su - jupyter -c "ln -s ${MNT_NFS_DIR}${PERSONS_NFS_DIR}/comfyui-outputs ${HOME_DIR}/output/persons"
  su - jupyter -c "ln -s ${MNT_NFS_DIR}comfyui-outputs/global ${HOME_DIR}/output/groups"

  # 添加权限
  chmod -R 777 "${MNT_NFS_DIR}${PERSONS_NFS_DIR}"
fi




if [ ! -d ${comfyui_manager_dir} ]; then
    echo "安装ComfyUI & ComfyUI-Manager中"
    su - jupyter -c "git clone https://github.com/ltdrdata/ComfyUI-Manager.git ${comfyui_manager_dir}"
    su - jupyter -c "cd ${home_dir} && /opt/conda/bin/python3 -m venv venv && source venv/bin/activate && pip install  torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121 && pip install  -r ${home_dir}/requirements.txt && pip install  -r ${home_dir}/custom_nodes/ComfyUI-Manager/requirements.txt"
    #su - jupyter -c "pip install --user torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121"
    #su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"
    #su - jupyter -c "pip install --user -r ${home_dir}/custom_nodes/ComfyUI-Manager/requirements.txt"

    su - jupyter -c "cd ${home_dir} && git config --global --add safe.directory ${home_dir}"
    current_hash=$(su - jupyter -c "cd ${home_dir} && git rev-parse HEAD")
    su - jupyter -c "sudo gcloud workbench instances update ${instance_name} --metadata=${comfyui_key}=${current_hash} --project=${project} --location=${location_zone}"

else
  echo "ComfyUI & ComfyUI-Manager已安装,跳过安装步骤."
fi




# 检查ComfyUI服务是否已存在
if systemctl --all --type service | grep -q "comfyui.service"; then
  echo "ComfyUI服务已存在,跳过创建步骤."
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
ExecStart=/bin/bash -c 'cd /home/jupyter/ComfyUI/ && source venv/bin/activate && /home/jupyter/ComfyUI/venv/bin/python3 /home/jupyter/ComfyUI/main.py'
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

  # 重新加载Systemd,使新服务生效
  sudo systemctl daemon-reload
  sudo systemctl enable comfyui.service
  sudo systemctl start comfyui.service
fi



# 升级ComfyUI
comfyui_ver=`curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/attributes/${comfyui_key}"`
cd ${home_dir} || exit
git config --global --add safe.directory ${home_dir}
current_hash=$(git rev-parse HEAD)

echo $comfyui_ver

if [[ "$comfyui_ver" == "null" ]]; then
    echo "未指定ComfyUI版本,正在拉取master分支."
    git fetch origin
    git checkout master
    su - jupyter -c "git pull origin master"
    su - jupyter -c "pip install --user --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121"
    su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"
    # 重启服务
    sudo systemctl restart comfyui.service
elif [[ "$current_hash" != "$comfyui_ver" ]]; then
    echo "检测到ComfyUI新版本,正在升级."
    git fetch origin
    git checkout "${comfyui_ver}"
    su - jupyter -c "pip install --user --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121"
    su - jupyter -c "pip install --user -r ${home_dir}/requirements.txt"
    # 重启服务
    sudo systemctl restart comfyui.service
else
    echo "ComfyUI无需更新."
fi



# install openresty
if [ ! -d "/usr/local/openresty" ]; then
  echo "安装openresty中."
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
