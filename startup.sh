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
    su - jupyter -c "cd ${home_dir}/models && find . -maxdepth 1 -type d ! -name checkpoints ! -name loras  -exec rm -rf {} +"
    su - jupyter -c "rm -rf ${home_dir}/output"
    #su - jupyter -c "rm -rf ${home_dir}/models/controlnet"
    #su - jupyter -c "mv ${home_dir}/custom_nodes/ ${home_dir}/custom_nodes_example/"
    #su - jupyter -c "rm -rf ${home_dir}/models/checkpoints && rm -rf ${home_dir}/models/loras && rm -rf ${home_dir}/models/controlnet && rm -rf ${home_dir}/custom_nodes && rm -rf ${home_dir}/output"
else
  echo "ComfyUI 已 clone,跳过此步骤."
fi



# 挂载 NFS 目录
nfs_address="10.97.68.98:/vol1"

mnt_nfs_dir="/mnt/sd-nfs-x"

if [ ! -d "${mnt_nfs_dir}" ]; then
sudo mkdir -p "${mnt_nfs_dir}"
fi

# 获取个人 NFS 目录的名称
hostname=$(hostname)
persons_nfs_dir=`echo ${hostname}| sed 's/-/\./g' | sed 's/^/accounts.google.com./g' | sed 's/$/\.com/'`

# 检查 NFS 共享目录是否已挂载
if mount | grep -q "${mnt_nfs_dir}"; then
  echo "NFS 共享目录已挂载到 ${mnt_nfs_dir},跳过挂载步骤."
else
  # 挂载 NFS 共享目录
  sudo apt-get install nfs-common -y
  sudo mount -o rw,intr ${nfs_address} ${mnt_nfs_dir}
fi

# 检查 /etc/fstab 中是否已有挂载条目
if grep -qs "${nfs_address}" /etc/fstab; then
  echo "${nfs_address} 的挂载点已存在于 fstab 中,跳过添加."
else
  # 将挂载点添加到 /etc/fstab
  echo "${nfs_address} ${mnt_nfs_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# 检查个人目录是否存在
if [ ! -d "${mnt_nfs_dir}/${persons_nfs_dir}" ]; then
  # 创建个人目录
  echo "创建 ${persons_nfs_dir} 个人目录."
  mkdir -p "${mnt_nfs_dir}/${persons_nfs_dir}/"{custom-model,extensions,sd-config,sd-custom-model,comfyui-extensions,comfyui-outputs,outputs}
  # 添加权限
  chmod -R 777 "${mnt_nfs_dir}/${persons_nfs_dir}"
else
  echo "${persons_nfs_dir} 个人目录已存在."
fi

# 判断已有用户 comfyui-extensions 和 comfyui-outputs 文件夹
if [ ! -d "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-extensions" ]; then
  mkdir -p "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-extensions"
  # 添加权限
  chmod -R 777 "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-extensions"
fi
if [ ! -d "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-outputs" ]; then
  mkdir -p "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-outputs"
  # 添加权限
  chmod -R 777 "${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-outputs"
fi

  
 # 检查是否存在 组 
if [[ "$group_name" == "null" ]]; then
  # 组 ${group_name} 参数为空
  echo "创建 ${PERSONS_NFS_DIR} 全局和个人 软链接."

  # 检查隐藏标识文件是否存在
  if [[ ! -f /home/jupyter/.sd_link_created ]]; then
    ##挂载models/checkpoint
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/checkpoints ${home_dir}/models/checkpoints/global"

    ##挂载models/loras
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/loras ${home_dir}/models/loras/global"

    ##挂载models/controlnet
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/controlnet ${home_dir}/models/controlnet"
    
    ##挂载其他模型
    for model_dir in `ls ${mnt_nfs_dir}/comfyui-models/ |grep -v checkpoints|grep -v loras|grep -v controlnet`; do
      su - jupyter -c "sudo ln -s ${mnt_nfs_dir}/comfyui-models/${model_dir} ${home_dir}/models/${model_dir}"
    done

    ##挂载output目录
    su - jupyter -c "ln -s ${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-outputs ${home_dir}/output"

    # 创建隐藏标识文件
    touch /home/jupyter/.sd_link_created
  fi
  
else
  # 检查隐藏标识文件是否存在
  if [[ ! -f /home/jupyter/.sd_link_created ]]; then
    ##挂载models/checkpoint
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/checkpoints ${home_dir}/models/checkpoints/global"
    su - jupyter -c "ln -s ${mnt_nfs_dir}/sd-bigmodel/group_sd_models/${group_name}/sd_models/Stable-diffusion ${home_dir}/models/checkpoints/groups"

    ##挂载models/loras
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/loras ${home_dir}/models/loras/global"
    su - jupyter -c "ln -s ${mnt_nfs_dir}/sd-bigmodel/group_sd_models/${group_name}/sd_models/Lora ${home_dir}/models/loras/groups"

    ##挂载models/controlnet
    su - jupyter -c "ln -s ${mnt_nfs_dir}/comfyui-models/controlnet ${home_dir}/models/controlnet"
    
    ##挂载其他模型
    for model_dir in `ls ${mnt_nfs_dir}/comfyui-models/ |grep -v checkpoints|grep -v loras|grep -v controlnet`; do
      su - jupyter -c "sudo ln -s ${mnt_nfs_dir}/comfyui-models/${model_dir} ${home_dir}/models/${model_dir}"
    done

    ##挂载output目录
    su - jupyter -c "ln -s ${mnt_nfs_dir}/${persons_nfs_dir}/comfyui-outputs ${home_dir}/output"

    # 创建隐藏标识文件
    touch /home/jupyter/.sd_link_created
  fi
  
fi




if [ ! -d ${comfyui_manager_dir} ]; then
    echo "安装ComfyUI"
    su - jupyter -c "wget -O ${home_dir}/requirements-custom.txt https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/requirements-custom.txt"
    su - jupyter -c "cd ${home_dir} && /opt/conda/bin/python3 -m venv venv && source venv/bin/activate && pip install  torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121 && pip install  -r ${home_dir}/requirements.txt && pip install  -r ${home_dir}/requirements-custom.txt"

    su - jupyter -c "cd ${home_dir} && git config --global --add safe.directory ${home_dir}"
    current_hash=$(su - jupyter -c "cd ${home_dir} && git rev-parse HEAD")
    su - jupyter -c "sudo gcloud workbench instances update ${instance_name} --metadata=${comfyui_key}=${current_hash} --project=${project} --location=${location_zone}"

else
  echo "ComfyUI已安装,跳过安装步骤."
  echo "每次重启安装requirements-custom.txt依赖包"
  su - jupyter -c "wget -O ${home_dir}/requirements-custom.txt https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/requirements-custom.txt"
  su - jupyter -c "cd ${home_dir} && /opt/conda/bin/python3 -m venv venv && source venv/bin/activate  && pip install  -r ${home_dir}/requirements-custom.txt"
fi


# 定义隐藏标记文件路径
hidden_flag_file="/home/jupyter/.comfyui_installed"

# 检查隐藏标记文件是否存在
if [ ! -f "${hidden_flag_file}" ]; then
  echo "首次运行，开始安装依赖..."
  sudo wget -O /tmp/repos.txt https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/repos.txt
  
  while read -r repo_url; do
    repo_name=$(echo $repo_url | awk -F'/' '{print $NF}' | sed 's/.git//')
    comfyui_dir="${home_dir}/custom_nodes/${repo_name}"

    # 检查目录是否存在
    if [ ! -d "${comfyui_dir}" ]; then
      echo "安装 ${repo_name} 中"
      echo "当前 ${comfyui_dir} 目录"

      # 判断 requirements.txt 是否存在
      if [[ "${repo_name}" == "ComfyUI_UltimateSDUpscale" ]]; then
        su - jupyter -c "git clone ${repo_url} ${comfyui_dir} --recursive"
      else
        su - jupyter -c "git clone ${repo_url} ${comfyui_dir}"
      fi
      
      if [ -f "${comfyui_dir}/requirements.txt" ]; then
        su - jupyter -c "cd ${home_dir} && /opt/conda/bin/python3 -m venv venv && source venv/bin/activate && pip install -r ${comfyui_dir}/requirements.txt"
      else
        echo "警告: ${comfyui_dir}/requirements.txt 不存在,跳过依赖安装."
      fi
    else
      echo "${repo_name} 已安装, 跳过安装步骤."
    fi
  done < "/tmp/repos.txt"

  # 创建隐藏标记文件
  touch "${hidden_flag_file}"
else
  echo "检测到已安装标记，跳过依赖安装过程..."
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
ExecStart=/bin/bash -c "cd /home/jupyter/ComfyUI/ && source venv/bin/activate && /home/jupyter/ComfyUI/venv/bin/python3 /home/jupyter/ComfyUI/main.py"
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
su - jupyter -c "cd ${home_dir} && git config --global --add safe.directory ${home_dir}"
current_hash=$(su - jupyter -c "cd ${home_dir} && git rev-parse HEAD")

echo "comfyui_ver is ${comfyui_ver}"
echo "current_ver is ${current_hash}"


if [[ "$comfyui_ver" == "null" ]]; then
    echo "未指定ComfyUI版本,正在拉取master分支."
    su - jupyter -c "cd ${home_dir} && source venv/bin/activate && git fetch origi && git checkout master &&  git pull origin master"
    su - jupyter -c "cd ${home_dir} && source venv/bin/activate && pip install  -r ${home_dir}/requirements.txt"
    # 重启服务
    sudo systemctl restart comfyui.service
elif [[ "$current_hash" != "$comfyui_ver" ]]; then
    echo "检测到ComfyUI新版本,正在升级."
    su - jupyter -c "cd ${home_dir} && source venv/bin/activate && git fetch origin && git checkout ${comfyui_ver} "
    su - jupyter -c "cd ${home_dir} && source venv/bin/activate && pip install  -r ${home_dir}/requirements.txt"
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

# 拉取最新 nginx.conf & last_activity.lua 文件
echo "拉取最新 nginx.conf & last_activity.lua 文件"
sudo wget -O /usr/local/openresty/nginx/conf/nginx.conf https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/nginx.conf
sudo wget -O /usr/local/openresty/lualib/last_activity.lua https://raw.githubusercontent.com/ahamomentgame001/dd-workbench-openresty/main/last_activity.lua
echo "nginx.conf & last_activity.lua 文件更新完成."

# 重启 openresty 服务
echo "重启 openresty 服务..."
sudo systemctl reload openresty

# 检查 openresty服务状态
if [[ `systemctl is-active openresty` = "active" ]]; then
    echo "openresty服务正常."
else
    echo "openresty服务异常,请检查服务."
fi



# 检查comfyui服务是否正常,添加metadata
max_retries=10
retry_count=0

while [[ $retry_count -lt $max_retries ]]; do
  if [[ `curl -m 5 -s -o /dev/null -w %{http_code} http://localhost/` == "200" ]]; then
    echo "ComfyUI 服务正常, 添加 metadata key:comfyui-status=running"
    su - jupyter -c "sudo gcloud workbench instances update ${instance_name} --metadata=comfyui-status=running --project=${project} --location=${location_zone}"
    break  # 状态码为 200，退出循环
  else
    echo "ComfyUI 服务异常 (重试次数: $retry_count), 添加 metadata key:comfyui-status=failed, 请检查服务"
    su - jupyter -c "sudo gcloud workbench instances update ${instance_name} --metadata=comfyui-status=failed --project=${project} --location=${location_zone}"
    retry_count=$((retry_count + 1))
    
    # 添加条件判断，如果达到最大重试次数，则跳出循环
    if [[ $retry_count -eq $max_retries ]]; then
      echo "ComfyUI 服务启动失败，请检查服务并手动启动。"
      break  # 跳出循环
    fi
    
    sleep 5  # 等待 5 秒后重试
  fi
done

