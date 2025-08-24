-- 欢迎使用万象拼音方案
-- @amzxyz
-- https://github.com/amzxyz/rime_wanxiang
-- 本lua通过定义一个不直接上屏的引导符号;搭配[a-z0-1]实现快速符号输入，并在双击;;重复上屏上次提交的内容
-- 使用方式加入到函数 - lua_processor@*quick_symbol_text 下面
-- 方案文件配置：
-- recognizer/patterns/quick_text: "^;.*$"
-- 你可以在方案文件中如下去针对性的替换符号的设定，或者a-z0-1全部替换
-- quick_symbol_text:
--   q: "wwwwwwwww"
--   w: "？"
-- 读取 RIME 配置文件中的符号映射表

local wanxiang = require("wanxiang")

local function load_mapping_from_config(config)
    local symbol_map = {}
    local keys = "qwertyuiopasdfghjklzxcvbnm1234567890"

    for key in keys:gmatch(".") do
        local symbol = config:get_string("quick_symbol_text/" .. key)
        if symbol then
            symbol_map[key] = symbol
        end
    end
    return symbol_map
end

-- 默认符号映射表
local default_mapping = {
    q = "“",
    w = "？",
    e = "（",
    r = "）",
    t = "~",
    y = "·",
    u = "『",
    i = "』",
    o = "〖",
    p = "〗",
    a = "！",
    s = "……",
    d = "、",
    f = "“",
    g = "”",
    h = "‘",
    j = "’",
    k = "【",
    l = "】",
    z = "。",
    x = "？",
    c = "！",
    v = "——",
    b = "%",
    n = "《",
    m = "》",
    ["1"] = "①",
    ["2"] = "②",
    ["3"] = "③",
    ["4"] = "④",
    ["5"] = "⑤",
    ["6"] = "⑥",
    ["7"] = "⑦",
    ["8"] = "⑧",
    ["9"] = "⑨",
    ["0"] = "⓪"
}
-- 中英文符号对照表（用于双击时映射）
local full_width_punct_map = {
    [";"] = "；",
    [","] = "，",
    ["."] = "。",
    ["?"] = "？",
    ["!"] = "！",
    [":"] = "：",
    ["'"] = "’",
    ['"'] = "”",
    ["("] = "（",
    [")"] = "）",
    ["["] = "【",
    ["]"] = "】",
    ["\\"] = "、",
    ["/"] = "／"
}
-- 初始化符号输入的状态
local function init(env)
    local config = env.engine.schema.config
    -- 加载符号映射表，优先使用 RIME 配置，未找到的键使用默认值
    env.mapping = default_mapping
    local custom_mapping = load_mapping_from_config(config)
    for k, v in pairs(custom_mapping) do
        env.mapping[k] = v -- 仅替换配置中存在的键
    end

    local text_pattern = config:get_string("recognizer/patterns/quick_symbol") or "^;.*$"
    local lead_char = string.sub(text_pattern, 2, 2) or ";"

    env.single_symbol_pattern = "^" .. lead_char .. "([a-zA-Z0-9])$"
    env.double_symbol_pattern_text = "^" .. lead_char .. lead_char .. "$"
    env.repeat_pattern = "^" .. lead_char .. "'" .. "$"  -- 用于上屏上次提交内容

    -- 初始化最后提交内容
    env.last_commit_text = "欢迎使用万象拼音！"

    -- 连接提交通知器
    env.quick_symbol_text_commit_notifier = env.engine.context.commit_notifier:connect(
        function(ctx)
            local commit_text = ctx:get_commit_text()
            if commit_text ~= "" then
                env.last_commit_text = commit_text -- 更新最后提交内容到env
            end
        end
    )

    env.quick_symbol_text_update_notifier = env.engine.context.update_notifier:connect(
        function(context)
            local input = context.input
            -- 1. 检查是否是重复上屏（比如 ;'）
            if string.match(input, env.repeat_pattern) then
                env.engine:commit_text(env.last_commit_text)
                context:clear()
            -- 2. 检查是否是双分号 (;;)，直接上屏分号
            elseif string.match(input, env.double_symbol_pattern_text) then
                local mapped = full_width_punct_map[lead_char] or lead_char
                env.engine:commit_text(mapped)
                context:clear()
            -- 3. 检查是否是单个符号键
            else
                local match = string.match(input, env.single_symbol_pattern)
                if match then
                    local symbol = env.mapping[string.lower(match)] -- 大小写兼容
                    if symbol then
                        env.engine:commit_text(symbol)
                        context:clear()
                    end
                end
            end
        end
    )
end

local function fini(env)
    if env.quick_symbol_text_commit_notifier then
        env.quick_symbol_text_commit_notifier:disconnect()
    end
    if env.quick_symbol_text_update_notifier then
        env.quick_symbol_text_update_notifier:disconnect()
    end
end

-- 处理符号和文本的重复上屏逻辑
local function processor(key_event, env)
    local input = env.engine.context.input
    if string.match(input, env.double_symbol_pattern_text) 
        or string.match(input, env.single_symbol_pattern) then
        return wanxiang.RIME_PROCESS_RESULTS.kAccepted
    end

    return wanxiang.RIME_PROCESS_RESULTS.kNoop -- 继续后续处理
end
return { init = init, fini = fini, func = processor }
