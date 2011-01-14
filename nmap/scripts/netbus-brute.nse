description = [[
Performs brute force password auditing about the Netbus backdoor ("remote administration") service.
]]

---
-- @output
-- 12345/tcp open  netbus
-- |_netbus-brute: password123

author = "Toni Ruottu"
license = "Same as Nmap--See http://nmap.org/book/man-legal.html"
categories = {"auth", "intrusive"}

require("nmap")
require("stdnse")
require("shortport")
require("unpwdb")

dependencies = {"netbus-version"}

portrule = shortport.port_or_service (12345, "netbus", {"tcp"})

action = function( host, port )
	local try = nmap.new_try()
	local passwords = try(unpwdb.passwords())
	local socket = nmap.new_socket()
	local status, err = socket:connect(host.ip, port.number)
	if not status then
		return
	end
	local buffer, err = stdnse.make_buffer(socket, "\r")
	local _ = buffer() --skip the banner
	for password in passwords do
		local foo = string.format("Password;0;%s\r", password)
		socket:send(foo)
		local login = buffer()
		if login == "Access;1" then
			-- Store the password for other netbus scripts
			nmap.registry.netbuspassword=password

			return string.format("%s", password)
		end
	end
	socket:close()

end


