description = [[
Attempts to find an SNMP community string by brute force guessing.

This script opens a sending socket and a sniffing pcap socket in parallel 
threads. The sending socket sends the SNMP probes with the community strings,
while the pcap socket sniffs the network for an answer to the probes. If 
valid community strings are found, they are added to the creds database and
reported in the output.

The default wordlists used to bruteforce the SNMP community strings are 
<code>nselib/data/snmpcommunities.lst</code> and 
<code>nselib/data/passwords.lst</code>. If the <code>passdb</code> or 
<code>snmplist</code> argument is specified, that one is used as the wordlist.
The <code>passdb</code> argument has precedence over <code>snmplist</code>.

No output is reported if no valid account is found.
]]
-- 2008-07-03 Philip Pickering, basic verstion
-- 2011-07-17 Gorjan Petrovski, Patrik Karlsson, optimization and creds 
--            accounts, rejected use of the brute library because of 
--            implementation using unconnected sockets.

---
-- @usage
-- nmap -sU --script snmp-brute <target> [--script-args [ passdb=<wordlist> | snmplist=<wordlist> ]]
--
-- @args snmpcommunity The SNMP community string to use. If it's supplied, this
-- script will not run.
-- @args snmplist The filename of a list of community strings to try.
--
-- @output
-- PORT    STATE SERVICE
-- 161/udp open  snmp
-- | snmp-brute: 
-- |   dragon - Valid credentials
-- |_  jordan - Valid credentials

author = "Philip Pickering, Gorjan Petrovski, Patrik Karlsson"

license = "Same as Nmap--See http://nmap.org/book/man-legal.html"

categories = {"intrusive", "auth"}

require "shortport"
require "snmp"
require "creds"
require "unpwdb"
require "nmap"
require "packet"

portrule = shortport.portnumber(161, "udp", {"open", "open|filtered"})

local filltable = function(filename, table)
	local file = io.open(filename, "r")

	if not file then
		return false
	end

	for l in file:lines() do
		-- Comments takes up a whole line
		if not l:match("#!comment:") then
			table[#table + 1] = l
		end
	end

	file:close()

	return true
end

local communities_iterator = function()
	local function next_community()
		local snmplist = stdnse.get_script_args("snmplist")
		local passdb = stdnse.get_script_args("passdb")
		if passdb then
			local communities = {}
			local filename = nmap.fetchfile(passdb)
			
			if not filltable(filename, communities) then
				stdnse.print_debug("Cannot open snmplist file")
				return
			end
			
			for _, c in ipairs(communities) do
				coroutine.yield(c)
			end		
		elseif snmplist then
			local communities = {}
			local filename = nmap.fetchfile(snmplist)
			
			if not filltable(filename, communities) then
				stdnse.print_debug("Cannot open snmplist file")
				return
			end
			
			for _, c in ipairs(communities) do
				coroutine.yield(c)
			end	
		else
			local communities = {}
			local filename = nmap.fetchfile("nselib/data/snmpcommunities.lst")	
			if not filltable(filename, communities) then
				stdnse.print_debug("Cannot open snmp communities file.")
				return
			end

			for _, c in ipairs(communities) do
				coroutine.yield(c)
			end

			local try = nmap.new_try()
			passwords = try(unpwdb.passwords())
			for p in passwords do
				coroutine.yield(p)
			end
		end
		
		while(true) do coroutine.yield(nil, nil) end
	end
	return coroutine.wrap(next_community)
end

local communities = function()
	local time_limit = unpwdb.timelimit() 
	local count_limit = 0 
	if stdnse.get_script_args("unpwdb.passlimit") then
		count_limit = tonumber(stdnse.get_script_args("unpwdb.passlimit"))
	end
	return unpwdb.limited_iterator(communities_iterator, time_limit, count_limit)
end

local send_snmp_queries = function(host, port, result)
	local condvar = nmap.condvar(result)

	local socket = nmap.new_socket("udp")
	--socket:set_timeout(host.times.timeout*1000)

	local request = snmp.buildGetRequest({}, "1.3.6.1.2.1.1.3.0")

	local payload, status, response
	local comm_iter = communities()
	for community_string in comm_iter() do	
		
		if result.status == false then
			--in case the sniff_snmp_responses thread was shut down
			condvar("signal")
			return
		end
		payload = snmp.encode(snmp.buildPacket(request, 0, community_string))
		status, err = socket:sendto(host, port, payload)
		if not status then
			result.status = false
			result.msg = "Could not send SNMP probe"
			condvar "signal"
			return
		end
	end

	socket:close()
	result.sent = true
	condvar("signal")
end

local sniff_snmp_responses = function(host, port, result)
	local condvar = nmap.condvar(result)
	
	local pcap = nmap.new_socket()
	pcap:set_timeout(host.times.timeout * 1000 * 3)
	local ip = host.bin_ip_src
	ip = string.format("%d.%d.%d.%d",ip:byte(1),ip:byte(2),ip:byte(3),ip:byte(4))
	pcap:pcap_open(host.interface, 104, false,"dst host " .. ip .. " and udp and port 161")
	
	-- last_run indicated whether there will be only one more receive
	local last_run = false

	-- receive even when status=false untill all the probes are sent
	while true do
		local status, plen, l2, l3, _ = pcap:pcap_receive()
		
		if status then
			local p = packet.Packet:new(l3,#l3)
			if not p:udp_parse() then
				--shouldn't happen
				result.status = false
				result.msg = "Wrong type of packet received"  
				condvar "signal"
				return
			end

			local response = p:raw(28, #p.buf)
			local res
			_, res = snmp.decode(response)

			if type(res) == "table" then
				result.communities[ #(result.communities) + 1 ] = res[2]
			else
				result.status = false 
				result.msg = "Wrong type of SNMP response received"
				condvar "signal"
				return
			end
		else
			if last_run then
				condvar "signal"
				return
			else
				if result.sent then
					last_run = true
				end
			end
		end
	end
	pcap:close()
	condvar "signal"
	return
end

action = function(host, port)
	if nmap.registry.snmpcommunity or nmap.registry.args.snmpcommunity then return end

	local result = {}
	local threads = {}

	local condvar = nmap.condvar(result)
	
	result.sent = false --whether the probes are sent
	result.communities = {} -- list of valid community strings
	result.msg = "" -- Error/Status msg
	result.status = true -- Status (is everything ok) 


	local recv_co = stdnse.new_thread(sniff_snmp_responses, host, port, result)
	local send_co = stdnse.new_thread(send_snmp_queries, host, port, result)
	
	local recv_dead, send_dead
	while true do 
		condvar "wait"
		recv_dead = (coroutine.status(recv_co) == "dead") 
		send_dead = (coroutine.status(send_co) == "dead")
		if recv_dead then break end
	end

	if result.status then
		-- add the community strings to the creds database
		local c = creds.Credentials:new(SCRIPT_NAME, host, port)
		for _, community_string in ipairs(result.communities) do
			c:add("",community_string, creds.State.VALID)
		end

		-- insert the first community string as a snmpcommunity registry field
		local creds_iter = c:getCredentials()
		if creds_iter then
			local account = creds_iter()
			if account then
				nmap.registry.snmpcommunity = account.pass
			end
		end

		-- return output
		return tostring(c)
	else
		stdnse.print_debug("An error occured: "..result.msg)
	end
end

