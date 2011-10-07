description = [[
Sends an ICMPv6 echo request packet to the all-nodes link-local
multicast address (<code>ff02::1</code>) to discover responsive hosts
on a LAN without needing to individually ping each IPv6 address.
]]

---
-- @usage
-- ./nmap -6 --script=targets-ipv6-multicast-echo.nse --script-args 'newtargets,interface=eth0' -sL
-- @args newtargets  If true, add discovered targets to the scan queue.
-- @args targets-ipv6-multicast-echo.interface  The interface to use for host discovery.

author = "David Fifield, Xu Weilin"

license = "Same as Nmap--See http://nmap.org/book/man-legal.html"

categories = {"discovery","broadcast"}

require 'nmap'
require 'tab'
require 'target'
require 'packet'
local bit = require 'bit'

prerule = function()
	return nmap.is_privileged()
end

catch = function()
	dnet:ethernet_close()
	pcap:pcap_close()
end
try = nmap.new_try(catch)

local function get_interfaces()
	local interface_name = stdnse.get_script_args(SCRIPT_NAME .. ".interface")
		or nmap.get_interface()

	-- interfaces list (decide which interfaces to broadcast on)
	local interfaces = {}
	if interface_name then
		-- single interface defined
		local if_table = nmap.get_interface_info(interface_name)
		if if_table and packet.ip6tobin(if_table.address) and if_table.link == "ethernet" then
			interfaces[#interfaces + 1] = if_table
		else
			stdnse.print_debug("Interface not supported or not properly configured.")
		end
	else
		for _, if_table in ipairs(nmap.list_interfaces()) do
			if packet.ip6tobin(if_table.address) and if_table.link == "ethernet" then
				table.insert(interfaces, if_table)
			end
		end
	end

	return interfaces
end

local function format_mac(mac)
	local octets

	octets = {}
	for _, v in ipairs({ string.byte(mac, 1, #mac) }) do
		octets[#octets + 1] = string.format("%02x", v)
	end

	return stdnse.strjoin(":", octets)
end

local function single_interface_broadcast(if_nfo, results)
	stdnse.print_debug("Starting " .. SCRIPT_NAME .. " on " .. if_nfo.device)

	local condvar = nmap.condvar(results)
	local src_mac = if_nfo.mac
	local src_ip6 = packet.ip6tobin(if_nfo.address)
	local dst_mac = packet.mactobin("33:33:00:00:00:01")
	local dst_ip6 = packet.ip6tobin("ff02::1")

----------------------------------------------------------------------------
--Multicast echo ping probe

	local dnet = nmap.new_dnet()
	local pcap = nmap.new_socket()

	try(dnet:ethernet_open(if_nfo.device))
	pcap:pcap_open(if_nfo.device, 128, false, "icmp6 and ip6[6:1] = 58 and ip6[40:1] = 129")

	local probe = packet.Frame:new()
	probe.mac_src = src_mac
	probe.mac_dst = dst_mac
	probe.ip6_src = src_ip6
	probe.ip6_dst = dst_ip6
	probe.echo_id = 5
	probe.echo_seq = 6
	probe.echo_data = "Nmap host discovery."
	probe:build_icmpv6_echo_request()
	probe:build_icmpv6_header()
	probe:build_ipv6_packet()
	probe:build_ether_frame()

	try(dnet:ethernet_send(probe.frame_buf))

	pcap:set_timeout(1000)
	local pcap_timeout_count = 0
	local nse_timeout = 5
	local start_time = nmap:clock()
	local cur_time = nmap:clock()

	repeat
		local status, length, layer2, layer3 = pcap:pcap_receive()
		cur_time = nmap:clock()
		if not status then
			pcap_timeout_count = pcap_timeout_count + 1
		else
			local reply = packet.Frame:new(layer2..layer3)
			if reply.mac_dst == src_mac then
				local target_str = packet.toipv6(reply.ip6_src)
				if not results[target_str] then
					target.add(target_str)
					results[#results + 1] = { address = target_str, mac = format_mac(reply.mac_src), iface = if_nfo.device }
					results[target_str] = true
				end
			end
		end
	until pcap_timeout_count >= 2 or cur_time - start_time >= nse_timeout

	dnet:ethernet_close()
	pcap:pcap_close()

	condvar("signal")
end

local function format_output(results)
	local output = tab.new()

	for _, record in ipairs(results) do
		tab.addrow(output, "IP: " .. record.address, "MAC: " .. record.mac, "IFACE: " .. record.iface)
	end
	if #results > 0 then
		output = { tab.dump(output) }
		if not target.ALLOW_NEW_TARGETS then
			output[#output + 1] = "Use --script-args=newtargets to add the results as targets"
		end
		return stdnse.format_output(true, output)
	end
end

action = function()
	local threads = {}
	local results = {}
	local condvar = nmap.condvar(results)

	for _, if_nfo in ipairs(get_interfaces()) do
		-- create a thread for each interface
		local co = stdnse.new_thread(single_interface_broadcast, if_nfo, results)
		threads[co] = true
	end

	repeat
		condvar "wait"
		for thread in pairs(threads) do
			if coroutine.status(thread) == "dead" then threads[thread] = nil end
		end
	until next(threads) == nil

	return format_output(results)
end
