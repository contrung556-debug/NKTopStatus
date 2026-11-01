-- ============================================================
-- NK TOP STATUS - AUTOTOUCH LUA CLIENT
-- Dùng sau khi cài tweak NK Top Status và respring.
-- ============================================================

local STATUS_FILE =
    "/var/mobile/Library/Preferences/com.nk.topstatus.status"

local function trimMessage(s)
    s = tostring(s or "")
    s = s:gsub("[\r\n|]+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function writeStatus(payload)
    local tmp = STATUS_FILE .. ".tmp"

    local f, err = io.open(tmp, "wb")
    if not f then
        return false, "Không mở được file status: " .. tostring(err)
    end

    f:write(tostring(payload or ""))
    f:flush()
    f:close()

    local ok, renameErr = os.rename(tmp, STATUS_FILE)

    if not ok then
        os.remove(tmp)
        return false, "Không ghi được status: " .. tostring(renameErr)
    end

    return true
end

function setTopStatus(percent, message)
    percent = tonumber(percent) or 0

    if percent < 0 then percent = 0 end
    if percent > 100 then percent = 100 end

    percent = math.floor(percent + 0.5)
    message = trimMessage(message)

    return writeStatus(
        tostring(percent) .. "|" .. message
    )
end

function hideTopStatus()
    return writeStatus("HIDE")
end

-- ============================================================
-- TEST
-- ============================================================

local function sleepMs(ms)
    usleep(math.floor((tonumber(ms) or 0) * 1000))
end

local function mustStatus(percent, message)
    local ok, err = setTopStatus(percent, message)

    if not ok then
        alert("TOP STATUS ERROR\n\n" .. tostring(err))
        error(err)
    end
end

mustStatus(10, "Khởi động")
sleepMs(900)

mustStatus(30, "Đang lấy dữ liệu")
sleepMs(900)

mustStatus(55, "Đang nhập Họ")
sleepMs(900)

mustStatus(80, "Đang nhập Tên")
sleepMs(900)

mustStatus(100, "Hoàn tất")
sleepMs(1800)

hideTopStatus()
