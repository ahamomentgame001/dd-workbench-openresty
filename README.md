# NFS配置
## NFS地址对应
```sh
NFS_address="10.97.68.98:/vol1"
```

## NFS目录Mount关系
### SD大模型

|        | 全局 | 组 | 个人 | ComfyUI目录 |
|--------|----------|----------|----------|----------|
|通用Models总目录|**/comfyui-models**|*|*|/{comfyui根}/models|
| SD大模型                | /sd-bigmodel/sd_models/Stable-diffusion  | /sd-bigmodel/group_sd_models/{组名大写}/sd_models/Stable-diffusion  | /{个人目录}/sd-custom-model   |/{comfyui根}/models/checkpoints|
| Lora                   | /sd-bigmodel/sd_models/lora   | /sd-bigmodel/group_sd_models/{组名大写}/sd_models/Lora  | /{个人目录}/custom-model   |/{comfyui根}/models/loras|
| ControlNet                   | **/comfyui-controlnet**   | *  | *   |/{comfyui根}/models/controlnet|
| comfy插件（需创建）  | **\*改为提供repos,动态 git clone**   | /comfyui-extensions/group/{组名}   | /{个人目录}/comfyui-extensions  |/{comfyui根}/custom_nodes|
| comfy出图结果（需创建）  | *   | /comfyui-outputs/global   | /{个人目录}/comfyui-outputs   |/{comfyui根}/output|


## 实例自定义metadata说明
### 自定义metadata

| key        |type| value   |  说明  |
| :--------  |---:| :-----  | :----:  |
| comfyui-status |string| "running" or "failed"|comfyui运行状态|
| group_name |string|"MCC" or null |用户是否在某个组内, 组名为全大写英文|
| comfyui-version |string| "4201181b35402e0a992b861f8d2f0e0b267f52fa" |comfyui github master commit id|
