local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local socket_proxy = require "socket_proxy"
require "app.codec.init"
local config = require "app.config.user"
local handshake = require "app.client.handshake"

local tcp = {}
local mt = {__index = tcp}

function tcp.new()
	local codecobj = codec.new(config.proto)
	local self = {
		linkid = nil,
		linktype = "tcp",
		codec = codecobj,
		message_id = 0,
		session = 0,
		sessions = {},
		verbose = true,  -- default: print recv message
		last_recv = "",
		wait_proto = {},
		secret = nil	-- 密钥
	}
	if config.no_handshake then
		self.handshake_result = "OK"
	end
	return setmetatable(self,mt)
end

function tcp:connect(host,port)
	local linkid = socket.open(host,port)
	self.linkid = linkid
	socket_proxy.subscribe(linkid,0)
	self:say("connect")
end

function tcp:send_request(protoname,request,callback)
	local session
	if callback then
		self.session = self.session + 1
		session = self.session
		self.sessions[session] = callback
	end
	local ud = self:message_ud()
	local message = {
		type = "REQUEST",
		proto = protoname,
		session = session,
		ud = ud,
		request = request,
	}
	local bin = self.codec:pack_message(message)
	if self.secret then
		bin = crypt.xor_str(bin,self.secret)
	end
	return self:send(bin)
end

function tcp:send_response(protoname,response,session)
	local ud = self:message_ud()
	local message = {
		type = "RESPONSE",
		proto = protoname,
		session = session,
		ud = ud,
		response = response,
	}
	local bin = self.codec:pack_message(message)
	if self.secret then
		bin = crypt.xor_str(bin,self.secret)
	end
	return self:send(bin)
end

function tcp:send(bin)
	local size = #bin
	assert(size <= 65535,"package too long")
	socket_proxy.write(self.linkid,bin)
end

function tcp:recv_message(msg)
	self:onmessage(msg)
end

function tcp:close()
	print(self.linkid,"close")
	socket_proxy.close(self.linkid)
end

function tcp:quite()
	self.verbose = not self.verbose
end

function tcp:say(...)
	print(string.format("[linktype=%s]",self.linktype),...)
end

function tcp:onmessage(msg)
	if not self.handshake_result then
		local ok,errmsg = handshake.do_handshake(self,msg)
		if not ok then
			self:close()
			self:say("handshake fail:",errmsg)
		end
		if self.handshake_result == "OK" then
			self:say("handshake success,secret:",self.secret)
		end
		return
	end
	if self.secret then
		msg = crypt.xor_str(msg,self.secret)
	end
	local message = self.codec:unpack_message(msg)
	if self.verbose then
		print(string.format("[linkid=%s]\n%s",self.linkid,table.dump(message)))
	end
	local protoname = message.proto
	local callback = self:wakeup(protoname)
	if callback then
		callback(self,message)
	end
end

function tcp:wait(protoname,callback)
	if not self.wait_proto[protoname] then
		self.wait_proto[protoname] = {}
	end
	table.insert(self.wait_proto[protoname],callback)
end

function tcp:wakeup(protoname)
	if not self.wait_proto[protoname] then
		return nil
	end
	return table.remove(self.wait_proto[protoname],1)
end

tcp.ignore_one = tcp.wakeup

function tcp:message_ud()
	-- 消息自定义数据,如生成包序号
	self.message_id = self.message_id + 1
	return self.message_id
end

return tcp
