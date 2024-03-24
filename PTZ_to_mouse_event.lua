--[[
      OBS Studio Lua script : Get USB Camera PTZ values with hotkeys
      Author: Jonathan Wood
      Version: 0.1
      Released: 2024-03-23
      references: https://obsproject.com/forum/resources/hotkeyrotate.723/, https://obsproject.com/forum/threads/command-runner.127662/
      https://github.com/jtfrey/uvc-util
--]]

local obs = obslua

local debug
source_name = ""
uvcUtil_Location = ""

output = ""
previous_output = ""

-- if you are extending the script, you can add more hotkeys here
-- then add actions in the 'onHotKey' function further below
-- OBS HotKey codes https://github.com/obsproject/obs-studio/blob/master/libobs/obs-hotkeys.h
local hotkeys = {
    {id = "START_uvcUtil", description = "Start getting Camera 1 USB PTZ values", HK = '{"START_uvcUtil": [ { "key": "OBS_KEY_F1", "control": false, "alt": false, "shift": false, "command": true } ]}'},
	{id = "STOP_uvcUtil", description = "Stop getting Camera 1 USB PTZ values", HK = '{"STOP_uvcUtil": [ { "key": "OBS_KEY_F1", "control": false, "alt": false, "shift": false, "command": false  } ]}'},
}

--Run the command and return its output
function os.capture(cmd)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return s
end

function run_command()
    --Get the Cammera Pan and Tile values Position with uvc-util command "{Path}/uvc-util -I 0 -o pan-tilt-abs"
    
    command = uvcUtil_Location .. "uvc-util -I 1 -o pan-tilt-abs"
    
    obs.script_log(obs.LOG_INFO, "Executing command: " .. command)
    output = os.capture(command)
    obs.script_log(obs.LOG_INFO, "Output: " .. output)
    
    --Tranform uvc-util results
    local pt = string.gsub(output,"{pan=", "")
    local pt = string.gsub(pt,"}", "")
    local pEnd = string.find(pt,",") 
    
    -- Insta360 min and max pan -500000 to +500000.  Scaled to 0-100
    -- OBSBOT Tiny 2 min and max pan -450000 to +450000.  Scaled to 0-100
    local p = math.floor(((tonumber(string.sub(pt,0,pEnd-1))+450000)/900000)*100)
    -- Insta360 min and max tilt -300000 to +300000.  Scaled to 0-100
    local t = math.floor(((tonumber(string.sub(pt,pEnd+6))+300000)/600000)*100)
    --output = p .." " .. t
    obs.script_log(obs.LOG_INFO,  p .." " ..t)

    --Get Zoom Value
    command = uvcUtil_Location .. "/uvc-util -I 1 -o zoom-abs"
    obs.script_log(obs.LOG_INFO, "Executing command: " .. command)
    zoomOutput = tonumber(os.capture(command))
    obs.script_log(obs.LOG_INFO, "Zoom Output: " .. zoomOutput)

    --prepare PTZ data to be sent as a mouse wheel event the the browser 
    local mouseevent = obs.obs_mouse_event()
    mouseevent.modifiers = 0
    mouseevent.x = p --tonumber(p)
    mouseevent.y = t --tonumber(t)
   -- obs.obs_source_send_mouse_move(obs.obs_get_source_by_name("PSV-js"), mouseevent, false)
    --obs.script_log(obs.LOG_INFO, "sent mouse event ")
    obs.obs_source_send_mouse_wheel(obs.obs_get_source_by_name("PSV-js"), mouseevent, zoomOutput ,10)
    obs.script_log(obs.LOG_INFO, "sent mouse wheel event ")
    output = string.gsub(output .. zoomOutput,"}", ",zoom=")
    output = string.gsub(output,"\n", "")
    output = string.gsub(output,"=", '":"')
    output = string.gsub(output,"{", '{"')
    output = string.gsub(output,",", '","')
    output = output .. '"}' 
    set_source_text()
end

function set_source_text()
    if output ~= previous_output then
        local source = obs.obs_get_source_by_name(source_name)
        if source ~= nil then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "text", output)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end
    previous_output = output
end

-- add any custom actions here
local function onHotKey(action)
	obs.timer_remove(run_command)
	if debug then obs.script_log(obs.LOG_INFO, string.format("Hotkey : %s", action)) end
	if action == "START_uvcUtil" then
		direction = 1
		obs.timer_add(run_command, interval)
	end
end
----------------------------------------------------------
function script_load(settings)
    obs.script_log(obs.LOG_INFO, OBS_KEY_2)
    --load hotkeys
	for _, v in pairs(hotkeys) do
        jsonHK = obs.obs_data_create_from_json(v.HK)
		hk = obs.obs_hotkey_register_frontend(v.id, v.description, function(pressed) if pressed then onHotKey(v.id) end end)
		local hotkeyArray = obs.obs_data_get_array(jsonHK, v.id)
		obs.obs_hotkey_load(hk, hotkeyArray)
		obs.obs_data_array_release(hotkeyArray)
        obs.obs_data_release(jsonHK)
	end
end

-- called when settings changed
function script_update(settings)
    uvcUtil_Location = obs.obs_data_get_string(settings, "uvcUtil_Location") 
    source_name = obs.obs_data_get_string(settings, "source_name")
	interval = obs.obs_data_get_int(settings, "interval")
end

-- return description shown to user
function script_description()
	return "Run the uvc-util command to send PTZ values to Browser Sources with hotkeys \nThe uvc-util camera utility is required.  It is recommended to save uvc-util to the /Applications/Utilities folder."
end

-- define properties that user can change
function script_properties()
	local props = obs.obs_properties_create()
    --uvc-util location
    obs.obs_properties_add_text(props, "uvcUtil_Location", "Path to the uvc-util \n(example /Applications/Utilities/)", obs.OBS_TEXT_DEFAULT)
    --list of text sources
    local property_list = obs.obs_properties_add_list(props, "source_name", "Select a Text Source to store PTZ values", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_ft2_source_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(property_list, name, name)
			end
		end
	end
	obs.source_list_release(sources)

    --refresh interval
	obs.obs_properties_add_int(props, "interval", "Refresh Interval (ms)", 2, 60000, 1)
	--debug option
    obs.obs_properties_add_bool(props, "debug", "Debug")
	return props
end

function script_defaults(settings)
    
    obs.obs_data_set_default_string(settings, "uvcUtil_Location", "/Applications/Utilities/")
    obs.obs_data_set_default_string(settings, "source", "")
	obs.obs_data_set_default_int(settings, "interval", 1000)
end
