local upload = require 'resty.upload'

local next = next
local type = type
local setmetatable = setmetatable

local string_find         = string.find
local string_lower        = string.lower
local table_concat        = table.concat
local get_headers         = ngx.req.get_headers
local ngx_req             = ngx.req
local ngx_req_init_body   = ngx_req.init_body
local ngx_req_append_body = ngx_req.append_body

local file_pattern =
    [[[; \t]filename\s*=\s*(?:"((?:\\.|[^\\"])*)"|'((?:\\'|[^\\'])*)'|([^; \t]+))]]
local name_pattern =
    [[[; \t]name\s*=\s*(?:"((?:\\.|[^\\"])*)"|'((?:\\'|[^\\'])*)'|([^; \t]+))]]

local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }

function _M.new(self, opt)
    if type(opt) ~= 'table' then
        return nil
    end

    return setmetatable({
        timeout = opt.timeout or 6000,
    }, mt)
end

function _M.is_formdata()
    local header = get_headers()['content-type']
    if not header then
        return false
    end

    if type(header) == 'table' then
        header = header[1]
    end

    if string_find(header, 'multipart/form-data', 1, true) == 1 then
        return true
    end
    return false
end


local function extract_match(str, pattern, tb)
    local iter, err = ngx.re.gmatch(str, pattern, 'ijo')
    while true do
        local m, err = iter()
        if err then
            ngx.log(ngx.ERR, err)
            return nil
        end
        if m then
            local key = m[1] or m[2] or m[3] or nil
            tb[#tb + 1] = key
        else
            break
        end
    end

end


function _M.get_args(self)
    local form, err = upload:new()
    if not form then
        return nil, err
    end

    ngx_req_init_body()

    form:set_timeout(self.timeout)

    ngx_req_append_body('--' .. form.boundary)

    local lasttyp
    local disposition, tb_filename = {}, {}

    while true do

        local typ, res, err = form:read()
        if not typ then
            return nil, err
        end

        if typ == 'header' then
            if type(res) == 'table' then
                ngx_req_append_body('\r\n' .. res[3])
                if string_lower(res[1]) == 'content-disposition' then
                    disposition[#disposition + 1] = res[3]
                end
            else
                ngx_req_append_body('\r\n' .. res)
                if next(disposition) then
                    disposition[#disposition + 1] = res
                end
            end
        elseif typ == 'body' then
            if lasttyp == 'header' then
                ngx_req_append_body('\r\n\r\n')
            end
            ngx_req_append_body(res)

            if next(disposition) then
                extract_match(table_concat(disposition, ''), 
                                           file_pattern, tb_filename)
                disposition = {}
            end

        elseif typ == 'part_end' then

            ngx_req_append_body("\r\n--" .. form.boundary)

        elseif typ == 'eof' then

            ngx_req_append_body("--\r\n")
            break
        end

        lasttyp = typ
    end

    return tb_filename
end

return _M
