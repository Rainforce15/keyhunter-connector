local ADDRESS = "127.0.0.1"
local PORT = 19273

print(_VERSION)
print(os.getenv("PROCESSOR_ARCHITECTURE"))

local socket = require("socket.core")
local tcp = nil
local clock = os.clock

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
	["read_u32_be"]=1,
	["write_u8"]=1
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

function parseMessage(msg)
	local msgObj = primJSONparse(msg)
	local ret = default_ret
	
	if (msgObj["o"] and msgObj["a"] and msgObj["d"] and allowedOperations[ msgObj["o"] ]) then
		local op = msgObj["o"]
		local address = msgObj["a"]
		local domain = msgObj["d"]
		local newVal = msgObj["v"]
		local newLen = msgObj["l"]
		local val = nil;

		if (op:sub(1, #"read_") == "read_") then
			--read
			val = memory[op](address, domain);
			ret = '{"v":'..val..',"a":'..address..',"d":"'..domain..'"}'
		elseif (op == "readbyterange" and msgObj["l"]) then
			local length = msgObj["l"]
			val = memory.readbyterange(address, length, domain);
			local arr;
			if (length > 1) then
				arr = "["..val[0]..","..table.concat(val,",").."]"
			else
				arr = "["..val[0].."]"
			end
			ret = '{"v":'..arr..',"a":'..address..',"l":'..length..',"d":"'..domain..'"}'
		elseif (op:sub(1, #"write_") == "write_" and newVal ~= nil) then
			--write
			memory[op](address, newVal, domain);
		end
	elseif(not msgObj["partialParse"]) then
		print("unknown format:")
		print(msg)
		print(msgObj)
	end

	return ret
end

function server_connect()
	tcp = socket.tcp();
	local last_try = 0
	while (true) do
		if (clock() - last_try >= 3) then
			local ret, err = tcp:connect(ADDRESS, PORT)
			if ret == 1 then
				print("Connection established")
				tcp:settimeout(0)
				break;
			elseif (err == "already connected") then
				break;
			else
				print("Failed to connect:", err)
				print("retrying in 3s...")
			end
			last_try = clock();
		end
		emu.yield()
	end
end

function receive()
	local data, err = tcp:receive()
	if data == nil then
		if err ~= "timeout" then
			print("Connection lost:", err)
			server_connect()
		end
		if err ~= nil then
		end
	else
		local answer = parseMessage(data)
		if (answer ~= nil) then tcp:send(answer.."\r\n") end
	end
	return data
end


--if (emu.getsystemid() ~= "NULL") then
	server_connect();
	while (true) do
		receive()
		emu.yield()
	end
--end
