description = [[
Does a GET request for the root folder ("/"), and displays the HTTP headers returned. 
]]

---
--@output
-- Interesting ports on scanme.nmap.org (64.13.134.52):
-- PORT   STATE SERVICE
-- 80/tcp open  http
-- |  http-headers:  
-- |   connection: close
-- |   content-type: text/html; charset=UTF-8
-- |   content-length: 739
-- |   accept-ranges: bytes
-- |   date: Sun, 23 Aug 2009 01:14:30 GMT
-- |   etag: "fc8c91-2e3-44d8e17edd540"
-- |   last-modified: Mon, 19 May 2008 04:49:49 GMT
-- |_  server: Apache/2.2.2 (Fedora)
-- 
--@arg path The path to request, such as '/index.php'. Default: '/'. 
--@arg useget Set to force GET requests instead of HEAD. 


author = "Ron Bowes <ron@skullsecurity.org>"

license = "Same as Nmap--See http://nmap.org/book/man-legal.html"

categories = {"discovery"}

require "shortport"
require "http"

portrule = function(host, port)
	local svc = { std = { ["http"] = 1, ["http-alt"] = 1 },
				ssl = { ["https"] = 1, ["https-alt"] = 1 } }
	if port.protocol ~= 'tcp'
	or not ( svc.std[port.service] or svc.ssl[port.service] ) then
		return false
	end
	-- Don't bother running on SSL ports if we don't have SSL.
	if (svc.ssl[port.service] or port.version.service_tunnel == 'ssl')
	and not nmap.have_ssl() then
		return false
	end
	return true
end

action = function(host, port)
	local path = nmap.registry.args.path
	local request_type = "HEAD"
	if(path == nil) then
		path = '/'
	end

	local status = false
	local result

	-- Check if the user didn't want HEAD to be used
	if(nmap.registry.args.useget == nil) then
		-- Try using HEAD first
		status, result = http.can_use_head(host, port, path)
	end

	-- If head failed, try using GET
	if(status == false) then
		stdnse.print_debug(1, "http-headers.nse: HEAD request failed, falling back to GET")
		result = http.get(host, port, path)
		request_type = "GET"
	end

	if(result == nil) then
		if(nmap.debugging() > 0) then
			return "ERROR: Header request failed"
		else
			return nil
		end
	end

	if(result.rawheader == nil) then
		if(nmap.debugging() > 0) then
			return "ERROR: Header request didn't return a proper header"
		else
			return nil
		end
	end

	local response = "(" .. request_type .. " used)\n"
	for _, header in pairs(result.rawheader) do
		response = response .. header .. "\n"
	end
		
	return response
end

