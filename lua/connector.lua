local port = 7681

print(_VERSION)
print(os.getenv("PROCESSOR_ARCHITECTURE"))

local kh = require("keyhunter.core")
--[[
local allowedOperations = {
	["readbyterange"]=1,
	["hash_region"]=1,
	["read_s8"]=1,
	["read_u8"]=1,
	["read_s16_le"]=1,
	["read_s16_be"]=1,
	["read_u16_le"]=1,
	["read_u16_be"]=1,
	["read_s24_le"]=1,
	["read_s24_be"]=1,
	["read_u24_le"]=1,
	["read_u24_be"]=1,
	["read_s32_le"]=1,
	["read_s32_be"]=1,
	["read_u32_le"]=1,
	["read_u32_be"]=1
}

--primitive interpreter of the json subset we use
local strBuffer = "";
function primJSONparse(str)
	if(str:sub(1,1) ~= "{" and str:sub(#str,#str) == "}") then
		str = strBuffer..str
	end
	if(#strBuffer > 0) then
		strBuffer = ""
	end

	if(str:sub(1,1) == "{" and str:sub(#str,#str) ~= "}") then
		strBuffer = str
		return {["partialParse"]=true}
	end

	local msgObj = {}
	for k,v in string.gmatch(str,'"([%w%d_ ]+)":"([%w%d_ ]+)"[,}]') do
		msgObj[k] = v;
	end
	for k,v in string.gmatch(str,'"([%w%d_ ]+)":(%d+)[,}]') do
		msgObj[k] = tonumber(v)
	end
	return msgObj;
end

--local teststr = '{"o":"read_u8","a":8257696,"d":"System Bus"}'
--print(primJSONparse(teststr))

-- this function is called from keyhunter.core
-- msg: string that has been received from the ws
-- returns: response string on ws
function parseMessage(msg)
	--return '{"asd":"qwe"}'
	--print("got: ", msg)
	local msgObj = primJSONparse(msg)
	--print(msgObj)
	local ret = default_ret
	
	if (msgObj["o"] and msgObj["a"] and msgObj["d"] and allowedOperations[ msgObj["o"] ]) then
		local op = msgObj["o"]
		local address = msgObj["a"]
		local domain = msgObj["d"]

		if (op:sub(1, #"read_") == "read_") then
			--read
			--print("READ!")
			local val = -42;
			val = memory[op](address, domain);
			ret = '{"t":"d","v":'..val..',"a":'..address..',"d":"'..domain..'"}'
		elseif (op == "readbyterange" and msgObj["l"]) then
			local length = msgObj["l"]
			val = memory.readbyterange(address, length, domain);
			local arr = "["..val[0]..","..table.concat(val,",").."]"
			ret = '{"t":"d","v":'..arr..',"a":'..address..',"l":'..length..',"d":"'..domain..'"}'
		elseif (op:sub(1, #"write_") == "write_") then
			--write
			--print("WRITE!")
		end
	elseif(not msgObj["partialParse"]) then
		print("unknown format:")
		print(msg)
		print(msgObj)
	end


	return ret
end

if (emu.getsystemid() ~= "NULL") then
	kh.startServer(port)

	while (true) do
		kh.step()
		emu.yield()
	end
end
--]]