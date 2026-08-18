local BaseHandler = require("api_handlers.base")
local json = require("json")
local koutil = require("util")
local logger = require("logger")

local HKUSTHandler = BaseHandler:new()

function HKUSTHandler:query(message_history, hkust_settings)

    if not hkust_settings or not hkust_settings.api_key then
        return nil, "Error: Missing API key in configuration"
    end

    local requestBodyTable = {
        model = hkust_settings.model,
        messages = message_history,
        max_tokens = hkust_settings.max_tokens,
        temperature = koutil.tableGetValue(hkust_settings, "additional_parameters", "temperature"),
        stream = koutil.tableGetValue(hkust_settings, "additional_parameters", "stream") or false,
    }

    local requestBody = json.encode(requestBodyTable)
    local headers = {
        ["Content-Type"] = "application/json",
        ["api-key"] = hkust_settings.api_key,
    }

    if requestBodyTable.stream then
        -- For streaming responses, we need to handle the response differently
        headers["Accept"] = "text/event-stream"
        return self:backgroundRequest(hkust_settings.base_url, headers, requestBody)
    end


    local status, code, response = self:makeRequest(hkust_settings.base_url, headers, requestBody)

    if status then
        local success, responseData = pcall(json.decode, response)
        if success then
            local content = koutil.tableGetValue(responseData, "choices", 1, "message", "content")
            if content then return content end
        end

        -- server response error message
        logger.warn("API Error", code, response)
        if success then
            local err_msg = koutil.tableGetValue(responseData, "error", "message")
            if err_msg then return nil, err_msg end
        end
    end

    if code == BaseHandler.CODE_CANCELLED then
        return nil, response
    end
    return nil, "Error: " .. (code or "unknown") .. " - " .. response
end

return HKUSTHandler
