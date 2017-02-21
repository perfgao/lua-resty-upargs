lua-resty-upargs
================
Description
----
Get the file name list when use 'multipart/form-data' upload file.

Synopsis
--------
```
local upargs = require 'resty.upargs'
local cjson  = require 'cjson'

local upa = upargs:new({timeout = 1000})
if not upa then
    ngx.log(ngx.ERR, 'new upargs failed')
    return
end

if upa:is_formdata() then
    local file_list = upa:get_args()
    if not file_list then
        return
    end
    ngx.say('filelist: ' .. cjson.encode(file_list))
end
```

TODO
----
* Method Interface Description
* upload args get
