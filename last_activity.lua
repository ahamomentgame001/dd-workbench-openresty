local http = require "resty.http"
local comfyuis = ngx.shared.comfyuis
local function get_metadata_value(key)
    local httpc = http.new()
    local res, err = httpc:request_uri("http://metadata.google.internal/computeMetadata/v1/" .. key, {
        method = "GET",
        headers = {
            ["Metadata-Flavor"] = "Google",
        }
    })
    if not res then
        ngx.log(ngx.ERR, "Failed to fetch metadata value: ", err)
        return nil
    else
        return res.body
    end
end
local function set_guest_attributes(key, value)
    local httpc = http.new()
    local res, err = httpc:request_uri("http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/" .. key, {
        method = "PUT",
        body = tostring(value),
        headers = {
            ["Metadata-Flavor"] = "Google",
        }
    })
    if not res then
        ngx.log(ngx.ERR, "Failed to set guest attribute: ", err)
    end
end
local ok, err = pcall(require, "resty.http")
if not ok then
    ngx.log(ngx.ERR, "failed to load 'resty.http': ", err)
    return
end
local now_time = os.time()
local value,flags = comfyuis:get("activity_time")
if value == nil then
    local succ, err, forcible = comfyuis:set("activity_time", now_time)
    ngx.log(ngx.INFO, "更新值为：", succ)
    local value,flags = comfyuis:get("activity_time")
    ngx.log(ngx.INFO, "值为：", value)
    return
else
    local activity_time = tonumber(value)
    if activity_time and now_time - activity_time < 60 then
        return
    else
        local NAMESPACE = "notebooks"
        set_guest_attributes(NAMESPACE .. "/last_activity", now_time)
        comfyuis:set("activity_time", now_time)
        ngx.log(ngx.INFO, "成功更新 last_activity 值为: ", now_time)
    end
end
