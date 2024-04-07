
# 全局
NFS_address="10.16.82.130:/vol1"
home_dir="/home/jupyter/ComfyUI"
sudo mkdir -p "${home_dir}/custom_nodes/comfyui-extensions/"

# NFS目录
glocal_sd_models_nfs_dir="/sd-bigmodel/sd_models/Stable-diffusion/"
glocal_lora_model_nfs_dir="/sd-bigmodel/sd_models/lora/"
glocal_controlnet_nfs_dir="/extension_controlnet/"
glocal_comfyui_extensions_nfs_dir="/comfyui-extensions/global/"

# 本机目录
global_sd_models_local_dir="/models/checkpoints/"
global_lora_model_local_dir="/models/loras/"
global_contronet_local_dir="/models/controlnet/"
global_comfyui_extensions_local_dir="/custom_nodes/comfyui-extensions/"

# 检查/etc/fstab中是否已有挂载条目
if grep -qs "${glocal_sd_models_nfs_dir} " /etc/fstab; then
  echo "${glocal_sd_models_nfs_dir} 的挂载点已存在于fstab中，跳过添加。"
else
  echo "将 ${glocal_sd_models_nfs_dir} 挂载点添加到/etc/fstab..."
  echo "${NFS_address}${glocal_sd_models_nfs_dir} ${home_dir}${global_sd_models_local_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
  echo "${NFS_address}${glocal_lora_model_nfs_dir} ${home_dir}${global_lora_model_local_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
  echo "${NFS_address}${glocal_controlnet_nfs_dir} ${home_dir}${global_contronet_local_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
  echo "${NFS_address}${glocal_comfyui_extensions_nfs_dir} ${home_dir}${global_comfyui_extensions_local_dir} nfs rw,intr 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# 检查挂载点是否已挂载
if mount | grep -q "${glocal_sd_models_nfs_dir}"; then
  echo "${glocal_sd_models_nfs_dir} 已挂载，跳过挂载步骤。"
else
  echo "挂载 ${glocal_sd_models_nfs_dir}..."
  sudo apt-get install nfs-common -y
  sudo mount -a
  #sudo mount -o rw,intr ${NFS_address}${glocal_sd_models_nfs_dir} ${home_dir}${global_sd_models_local_dir}
  #sudo mount -o rw,intr ${NFS_address}${glocal_lora_model_nfs_dir} ${home_dir}${global_lora_model_local_dir}
  #sudo mount -o rw,intr ${NFS_address}${glocal_controlnet_nfs_dir} ${home_dir}${global_contronet_local_dir}
  #sudo mount -o rw,intr ${NFS_address}${glocal_comfyui_extensions_nfs_dir} ${home_dir}${global_comfyui_extensions_local_dir}
fi
