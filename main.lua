local ffi			= require("ffi")
local socket		= require("socket")
-- local Matrix		= require("lib.librgbmatrix")
local MatrixWS2811	= require("lib.libws2811")

local lpack = require("pack")
local pack = string.pack
local upack = string.unpack

udp = socket.udp()
udp:setsockname("*", 1234)
udp:settimeout(1)

local LED_RGB_888        = 0
local LED_RGB_888_UPDATE = 1

local LED_RGB_565        = 2
local LED_RGB_565_UPDATE = 3

local LED_RLE_888        = 11
local LED_RLE_888_UPDATE = 12
local LED_BRO_888        = 13
local LED_BRO_888_UPDATE = 14
local LED_Z_888          = 15
local LED_Z_888_UPDATE   = 16

local LED_UPDATE         = 4
local GET_INFO           = 5
local LED_TEST           = 6
local LED_RGB_SET        = 7
local LED_LERP           = 8
local SET_MODE           = 9
local REBOOT             = 10


local mode, nb, rgb = ...

nb = tonumber(nb)

print("mode:", mode)
print("led_nb:", tonumber(nb))
print("rgbw:", rgbw == "1")

if not(mode and (mode == "PCM" or mode == "PWM" or mode == "PWMx2")) then
	error("Error mode should be PCM or PWM or PWMx2")
end

if not nb or nb == 0 then
	error("Error LEDs number invalide")
end


local matrix = MatrixWS2811:new{
	mode = mode,
	num = nb,
	rgbw = rgbw
}

while true do
	local data, ip, port = udp:receivefrom()
	if data then
		local _, cmd = upack(data, "b")

		-- print("Received: ",ip,port, cmd, #data)

		if cmd == LED_RGB_888_UPDATE or  cmd == LED_RGB_888 then
			local _, cmd, ctn, off, len = upack(data, "bbHH")
			local prev = 1
			local r,g,b = 0,0,0
			local data = data:sub(7)
			-- print("Pixel ",_, cmd, px, py, ox, oy)
			for i=1, len do
				prev,r,g,b = upack(data, "bbb", prev)
				if r then
				--	print(i,r,g,b)
					matrix:setRGB(i-1,r,g,b)
				end
			end
		end

		if cmd == LED_RGB_888_UPDATE or cmd == LED_UPDATE then
			matrix:send()
		end
	end
	socket.sleep(0.0001)
end
