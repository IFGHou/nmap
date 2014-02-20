#!/usr/bin/env python

# Ndiff
#
# This programs reads two Nmap XML files and displays a list of their
# differences.
#
# Copyright 2008 Insecure.Com LLC
# Ndiff is distributed under the same license as Nmap. See the file COPYING or
# http://nmap.org/data/COPYING. See http://nmap.org/book/man-legal.html for
# more details.
#
# David Fifield
# based on a design by Michael Pattrick

import datetime
import difflib
import getopt
import sys
import time
import xml.sax
import xml.sax.saxutils
import xml.dom.minidom

verbose = False

NDIFF_XML_VERSION = u"1"


class Scan(object):
    """A single Nmap scan, corresponding to a single invocation of Nmap. It is
    a container for a list of hosts. It also has utility methods to load itself
    from an Nmap XML file."""
    def __init__(self):
        self.scanner = None
        self.version = None
        self.args = None
        self.start_date = None
        self.end_date = None
        self.hosts = []
        self.pre_script_results = []
        self.post_script_results = []

    def sort_hosts(self):
        self.hosts.sort(key=lambda h: h.get_id())

    def load(self, f):
        """Load a scan from the Nmap XML in the file-like object f."""
        parser = xml.sax.make_parser()
        handler = NmapContentHandler(self)
        parser.setContentHandler(handler)
        parser.parse(f)

    def load_from_file(self, filename):
        """Load a scan from the Nmap XML file with the given filename."""
        f = open(filename, "r")
        try:
            self.load(f)
        finally:
            f.close()

    def write_nmaprun_open(self, writer):
        attrs = {}
        if self.scanner is not None:
            attrs[u"scanner"] = self.scanner
        if self.args is not None:
            attrs[u"args"] = self.args
        if self.start_date is not None:
            attrs[u"start"] = "%d" % time.mktime(self.start_date.timetuple())
            attrs[u"startstr"] = self.start_date.strftime(
                    "%a %b %d %H:%M:%S %Y")
        if self.version is not None:
            attrs[u"version"] = self.version
        writer.startElement(u"nmaprun", attrs)

    def write_nmaprun_close(self, writer):
        writer.endElement(u"nmaprun")

    def nmaprun_to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"nmaprun")
        if self.scanner is not None:
            elem.setAttribute(u"scanner", self.scanner)
        if self.args is not None:
            elem.setAttribute(u"args", self.args)
        if self.start_date is not None:
            elem.setAttribute(
                    u"start", "%d" % time.mktime(self.start_date.timetuple()))
            elem.setAttribute(
                    u"startstr",
                    self.start_date.strftime("%a %b %d %H:%M:%S %Y"))
        if self.version is not None:
            elem.setAttribute(u"version", self.version)
        frag.appendChild(elem)
        return frag


class Host(object):
    """A single host, with a state, addresses, host names, a dict mapping port
    specs to Ports, and a list of OS matches. Host states are strings, or None
    for "unknown"."""
    def __init__(self):
        self.state = None
        self.addresses = []
        self.hostnames = []
        self.ports = {}
        self.extraports = {}
        self.os = []
        self.script_results = []

    def get_id(self):
        """Return an id that is used to determine if hosts are "the same"
        across scans."""
        if len(self.addresses) > 0:
            return str(sorted(self.addresses)[0])
        if len(self.hostnames) > 0:
            return str(sorted(self.hostnames)[0])
        return id(self)

    def format_name(self):
        """Return a human-readable identifier for this host."""
        address_s = u", ".join(a.s for a in sorted(self.addresses))
        hostname_s = u", ".join(sorted(self.hostnames))
        if len(hostname_s) > 0:
            if len(address_s) > 0:
                return u"%s (%s)" % (hostname_s, address_s)
            else:
                return hostname_s
        elif len(address_s) > 0:
            return address_s
        else:
            return u"<no name>"

    def add_port(self, port):
        self.ports[port.spec] = port

    def add_address(self, address):
        if address not in self.addresses:
            self.addresses.append(address)

    def add_hostname(self, hostname):
        if hostname not in self.hostnames:
            self.hostnames.append(hostname)

    def is_extraports(self, state):
        return state is None or state in self.extraports

    def extraports_string(self):
        list = [(count, state) for (state, count) in self.extraports.items()]
        # Reverse-sort by count.
        list.sort(reverse=True)
        return u", ".join(
                [u"%d %s ports" % (count, state) for (count, state) in list])

    def state_to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        if self.state is not None:
            elem = document.createElement(u"status")
            elem.setAttribute(u"state", self.state)
            frag.appendChild(elem)
        return frag

    def hostname_to_dom_fragment(self, document, hostname):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"hostname")
        elem.setAttribute(u"name", hostname)
        frag.appendChild(elem)
        return frag

    def extraports_to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        for state, count in self.extraports.items():
            elem = document.createElement(u"extraports")
            elem.setAttribute(u"state", state)
            elem.setAttribute(u"count", unicode(count))
            frag.appendChild(elem)
        return frag

    def os_to_dom_fragment(self, document, os):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"osmatch")
        elem.setAttribute(u"name", os)
        frag.appendChild(elem)
        return frag

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"host")

        if self.state is not None:
            elem.appendChild(self.state_to_dom_fragment(document))

        for addr in self.addresses:
            elem.appendChild(addr.to_dom_fragment(document))

        if len(self.hostnames) > 0:
            hostnames_elem = document.createElement(u"hostnames")
            for hostname in self.hostnames:
                hostnames_elem.appendChild(
                        self.hostname_to_dom_fragment(document, hostname))
            elem.appendChild(hostnames_elem)

        ports_elem = document.createElement(u"ports")
        ports_elem.appendChild(self.extraports_to_dom_fragment(document))
        for port in sorted(self.ports.values()):
            if not self.is_extraports(port.state):
                ports_elem.appendChild(port.to_dom_fragment(document))
        if ports_elem.hasChildNodes():
            elem.appendChild(ports_elem)

        if len(self.os) > 0:
            os_elem = document.createElement(u"os")
            for os in self.os:
                os_elem.appendChild(self.os_to_dom_fragment(document, os))
            elem.appendChild(os_elem)

        if len(self.script_results) > 0:
            hostscript_elem = document.createElement(u"hostscript")
            for sr in self.script_results:
                hostscript_elem.appendChild(sr.to_dom_fragment(document))
            elem.appendChild(hostscript_elem)

        frag.appendChild(elem)
        return frag


class Address(object):
    def __init__(self, s):
        self.s = s

    def __eq__(self, other):
        return self.__cmp__(other) == 0

    def __ne__(self, other):
        return not self.__eq__(other)

    def __hash__(self):
        return hash(self.sort_key())

    def __cmp__(self, other):
        return cmp(self.sort_key(), other.sort_key())

    def __str__(self):
        return str(self.s)

    def __unicode__(self):
        return self.s

    def new(type, s):
        if type == u"ipv4":
            return IPv4Address(s)
        elif type == u"ipv6":
            return IPv6Address(s)
        elif type == u"mac":
            return MACAddress(s)
        else:
            raise ValueError(u"Unknown address type %s." % type)
    new = staticmethod(new)

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"address")
        elem.setAttribute(u"addr", self.s)
        elem.setAttribute(u"addrtype", self.type)
        frag.appendChild(elem)
        return frag

# The sort_key method in the Address subclasses determines the order in which
# addresses are displayed. We do IPv4, then IPv6, then MAC.


class IPv4Address(Address):
    type = property(lambda self: u"ipv4")

    def sort_key(self):
        return (0, self.s)


class IPv6Address(Address):
    type = property(lambda self: u"ipv6")

    def sort_key(self):
        return (1, self.s)


class MACAddress(Address):
    type = property(lambda self: u"mac")

    def sort_key(self):
        return (2, self.s)


class Port(object):
    """A single port, consisting of a port specification, a state, and a
    service version. A specification, or "spec," is the 2-tuple (number,
    protocol). So (10, "tcp") corresponds to the port 10/tcp. Port states are
    strings, or None for "unknown"."""
    def __init__(self, spec, state=None):
        self.spec = spec
        self.state = state
        self.service = Service()
        self.script_results = []

    def state_string(self):
        if self.state is None:
            return u"unknown"
        else:
            return unicode(self.state)

    def spec_string(self):
        return u"%d/%s" % self.spec

    def __cmp__(self, other):
        d = cmp(self.spec, other.spec)
        if d != 0:
            return d
        return cmp((self.spec, self.service, self.script_results),
            (other.spec, other.service, other.script_results))

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"port")
        elem.setAttribute(u"portid", unicode(self.spec[0]))
        elem.setAttribute(u"protocol", self.spec[1])
        if self.state is not None:
            state_elem = document.createElement(u"state")
            state_elem.setAttribute(u"state", self.state)
            elem.appendChild(state_elem)
        elem.appendChild(self.service.to_dom_fragment(document))
        for sr in self.script_results:
            elem.appendChild(sr.to_dom_fragment(document))
        frag.appendChild(elem)
        return frag


class Service(object):
    """A service version as determined by -sV scan. Also contains the looked-up
    port name if -sV wasn't used."""
    def __init__(self):
        self.name = None
        self.product = None
        self.version = None
        self.extrainfo = None
        self.tunnel = None

        # self.hostname = None
        # self.ostype = None
        # self.devicetype = None

    __hash__ = None

    def __eq__(self, other):
        return self.name == other.name \
            and self.product == other.product \
            and self.version == other.version \
            and self.extrainfo == other.extrainfo

    def __ne__(self, other):
        return not self.__eq__(other)

    def name_string(self):
        parts = []
        if self.tunnel is not None:
            parts.append(self.tunnel)
        if self.name is not None:
            parts.append(self.name)

        if len(parts) == 0:
            return None
        else:
            return u"/".join(parts)

    def version_string(self):
        """Get a string like in the VERSION column of Nmap output."""
        parts = []
        if self.product is not None:
            parts.append(self.product)
        if self.version is not None:
            parts.append(self.version)
        if self.extrainfo is not None:
            parts.append(u"(%s)" % self.extrainfo)

        if len(parts) == 0:
            return None
        else:
            return u" ".join(parts)

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"service")
        for attr in (u"name", u"product", u"version", u"extrainfo", u"tunnel"):
            v = getattr(self, attr)
            if v is None:
                continue
            elem.setAttribute(attr, v)
        if len(elem.attributes) > 0:
            frag.appendChild(elem)
        return frag


class ScriptResult(object):
    def __init__(self):
        self.id = None
        self.output = None

    __hash__ = None

    def __eq__(self, other):
        return self.id == other.id and self.output == other.output

    def __ne__(self, other):
        return not self.__eq__(other)

    def __cmp__(self, other):
        return cmp((self.id, self.output), (other.id, other.output))

    def get_lines(self):
        result = []
        lines = self.output.splitlines()
        if len(lines) > 0:
            lines[0] = self.id + u": " + lines[0]
        for line in lines[:-1]:
            result.append(u"|  " + line)
        if len(lines) > 0:
            result.append(u"|_ " + lines[-1])
        return result

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        elem = document.createElement(u"script")
        elem.setAttribute(u"id", self.id)
        elem.setAttribute(u"output", self.output)
        frag.appendChild(elem)
        return frag


def format_banner(scan):
    """Format a startup banner more or less like Nmap does."""
    scanner = u"Nmap"
    if scan.scanner is not None and scan.scanner != u"nmap":
        scanner = scan.scanner
    parts = [scanner]
    if scan.version is not None:
        parts.append(scan.version)
    parts.append(u"scan")
    if scan.start_date is not None:
        parts.append(u"initiated %s" % scan.start_date.strftime(
            "%a %b %d %H:%M:%S %Y"))
    if scan.args is not None:
        parts.append(u"as: %s" % scan.args)
    return u" ".join(parts)


def print_script_result_diffs_text(title, script_results_a, script_results_b,
    script_result_diffs, f=sys.stdout):
    table = Table(u"*")
    for sr_diff in script_result_diffs:
        sr_diff.append_to_port_table(table)
    if len(table) > 0:
        print >> f
        if len(script_results_b) == 0:
            print >> f, u"-%s:" % title
        elif len(script_results_a) == 0:
            print >> f, u"+%s:" % title
        else:
            print >> f, u" %s:" % title
        print >> f, table


def script_result_diffs_to_dom_fragment(elem, script_results_a,
    script_results_b, script_result_diffs, document):
    if len(script_results_a) == 0 and len(script_results_b) == 0:
        return document.createDocumentFragment()
    elif len(script_results_b) == 0:
        a_elem = document.createElement(u"a")
        for sr in script_results_a:
            elem.appendChild(sr.to_dom_fragment(document))
        a_elem.appendChild(elem)
        return a_elem
    elif len(script_results_a) == 0:
        b_elem = document.createElement(u"b")
        for sr in script_results_b:
            elem.appendChild(sr.to_dom_fragment(document))
        b_elem.appendChild(elem)
        return b_elem
    else:
        for sr_diff in script_result_diffs:
            elem.appendChild(sr_diff.to_dom_fragment(document))
        return elem


def host_pairs(a, b):
    """Take hosts lists a and b, which must be sorted by id, and return pairs.
    When the heads of both lists have the same ids, they are returned together.
    Otherwise the one with the smaller id is returned, with an empty host as
    its counterpart, and the one with the higher id will remain in its list for
    a later iteration."""
    i = 0
    j = 0
    while i < len(a) and j < len(b):
        if a[i].get_id() < b[j].get_id():
            yield a[i], Host()
            i += 1
        elif a[i].get_id() > b[j].get_id():
            yield Host(), b[j]
            j += 1
        else:
            yield a[i], b[j]
            i += 1
            j += 1
    while i < len(a):
        yield a[i], Host()
        i += 1
    while j < len(b):
        yield Host(), b[j]
        j += 1


class ScanDiff(object):
    """An abstract class for different diff output types. Subclasses must
    define various output methods."""
    def __init__(self, scan_a, scan_b, f=sys.stdout):
        """Create a ScanDiff from the "before" scan_a and the "after"
        scan_b."""
        self.scan_a = scan_a
        self.scan_b = scan_b
        self.f = f

    def output(self):
        self.scan_a.sort_hosts()
        self.scan_b.sort_hosts()

        self.output_beginning()

        pre_script_result_diffs = ScriptResultDiff.diff_lists(
                self.scan_a.pre_script_results, self.scan_b.pre_script_results)
        self.output_pre_scripts(pre_script_result_diffs)

        cost = 0
        # Currently we never consider diffing hosts with a different id
        # (address or host name), which could lead to better diffs.
        for host_a, host_b in host_pairs(self.scan_a.hosts, self.scan_b.hosts):
            h_diff = HostDiff(host_a, host_b)
            cost += h_diff.cost
            if h_diff.cost > 0 or verbose:
                host = host_a or host_b
                self.output_host_diff(h_diff)

        post_script_result_diffs = ScriptResultDiff.diff_lists(
                self.scan_a.post_script_results,
                self.scan_b.post_script_results)
        self.output_post_scripts(post_script_result_diffs)

        self.output_ending()

        return cost


class ScanDiffText(ScanDiff):
    def __init__(self, scan_a, scan_b, f=sys.stdout):
        ScanDiff.__init__(self, scan_a, scan_b, f)

    def output_beginning(self):
        banner_a = format_banner(self.scan_a)
        banner_b = format_banner(self.scan_b)
        if banner_a != banner_b:
            print >> self.f, u"-%s" % banner_a
            print >> self.f, u"+%s" % banner_b
        elif verbose:
            print >> self.f, u" %s" % banner_a

    def output_pre_scripts(self, pre_script_result_diffs):
        print_script_result_diffs_text("Pre-scan script results",
            self.scan_a.pre_script_results, self.scan_b.pre_script_results,
            pre_script_result_diffs, self.f)

    def output_post_scripts(self, post_script_result_diffs):
        print_script_result_diffs_text("Post-scan script results",
            self.scan_a.post_script_results, self.scan_b.post_script_results,
            post_script_result_diffs, self.f)

    def output_host_diff(self, h_diff):
        print >> self.f
        h_diff.print_text(self.f)

    def output_ending(self):
        pass


class ScanDiffXML(ScanDiff):
    def __init__(self, scan_a, scan_b, f=sys.stdout):
        ScanDiff.__init__(self, scan_a, scan_b, f)

        impl = xml.dom.minidom.getDOMImplementation()
        self.document = impl.createDocument(None, None, None)

        self.writer = XMLWriter(f)

    def nmaprun_differs(self):
        for attr in ("scanner", "version", "args", "start_date", "end_date"):
            if getattr(self.scan_a, attr, None) !=\
                    getattr(self.scan_b, attr, None):
                return True
        return False

    def output_beginning(self):
        self.writer.startDocument()
        self.writer.startElement(u"nmapdiff", {u"version": NDIFF_XML_VERSION})
        self.writer.startElement(u"scandiff", {})

        if self.nmaprun_differs():
            self.writer.frag_a(
                    self.scan_a.nmaprun_to_dom_fragment(self.document))
            self.writer.frag_b(
                    self.scan_b.nmaprun_to_dom_fragment(self.document))
        elif verbose:
            self.writer.frag(
                    self.scan_a.nmaprun_to_dom_fragment(self.document))

    def output_pre_scripts(self, pre_script_result_diffs):
        if len(pre_script_result_diffs) > 0 or verbose:
            prescript_elem = self.document.createElement(u"prescript")
            frag = script_result_diffs_to_dom_fragment(
                prescript_elem, self.scan_a.pre_script_results,
                self.scan_b.pre_script_results, pre_script_result_diffs,
                self.document)
            self.writer.frag(frag)
            frag.unlink()

    def output_post_scripts(self, post_script_result_diffs):
        if len(post_script_result_diffs) > 0 or verbose:
            postscript_elem = self.document.createElement(u"postscript")
            frag = script_result_diffs_to_dom_fragment(
                postscript_elem, self.scan_a.post_script_results,
                self.scan_b.post_script_results, post_script_result_diffs,
                self.document)
            self.writer.frag(frag)
            frag.unlink()

    def output_host_diff(self, h_diff):
        frag = h_diff.to_dom_fragment(self.document)
        self.writer.frag(frag)
        frag.unlink()

    def output_ending(self):
        self.writer.endElement(u"scandiff")
        self.writer.endElement(u"nmapdiff")
        self.writer.endDocument()


class HostDiff(object):
    """A diff of two Hosts. It contains the two hosts, variables describing
    what changed, and a list of PortDiffs and OS differences."""
    def __init__(self, host_a, host_b):
        self.host_a = host_a
        self.host_b = host_b
        self.state_changed = False
        self.id_changed = False
        self.os_changed = False
        self.extraports_changed = False
        self.ports = []
        self.port_diffs = {}
        self.os_diffs = []
        self.script_result_diffs = []
        self.cost = 0

        self.diff()

    def diff(self):
        if self.host_a.state != self.host_b.state:
            self.state_changed = True
            self.cost += 1

        if set(self.host_a.addresses) != set(self.host_b.addresses) \
           or set(self.host_a.hostnames) != set(self.host_b.hostnames):
            self.id_changed = True
            self.cost += 1

        all_specs = list(
                set(self.host_a.ports.keys()).union(
                    set(self.host_b.ports.keys())))
        all_specs.sort()
        for spec in all_specs:
            # Currently we only compare ports with the same spec. This ignores
            # the possibility that a service is moved lock, stock, and barrel
            # to another port.
            port_a = self.host_a.ports.get(spec)
            port_b = self.host_b.ports.get(spec)
            diff = PortDiff(port_a or Port(spec), port_b or Port(spec))
            if self.include_diff(diff):
                port = port_a or port_b
                self.ports.append(port)
                self.port_diffs[port] = diff
                self.cost += diff.cost

        os_diffs = difflib.SequenceMatcher(
                None, self.host_a.os, self.host_b.os)
        self.os_diffs = os_diffs.get_opcodes()
        os_cost = len([x for x in self.os_diffs if x[0] != "equal"])
        if os_cost > 0:
            self.os_changed = True
        self.cost += os_cost

        extraports_a = tuple((count, state)
                for (state, count) in self.host_a.extraports.items())
        extraports_b = tuple((count, state)
                for (state, count) in self.host_b.extraports.items())
        if extraports_a != extraports_b:
            self.extraports_changed = True
            self.cost += 1

        self.script_result_diffs = ScriptResultDiff.diff_lists(
                self.host_a.script_results, self.host_b.script_results)
        self.cost += len(self.script_result_diffs)

    def include_diff(self, diff):
        # Don't include the diff if the states are only extraports. Include all
        # diffs, even those with cost == 0, in verbose mode.
        if self.host_a.is_extraports(diff.port_a.state) and \
           self.host_b.is_extraports(diff.port_b.state):
            return False
        elif verbose:
            return True
        return diff.cost > 0

    def print_text(self, f=sys.stdout):
        host_a = self.host_a
        host_b = self.host_b

        # Names and addresses.
        if self.id_changed:
            if host_a.state is not None:
                print >> f, u"-%s:" % host_a.format_name()
            if self.host_b.state is not None:
                print >> f, u"+%s:" % host_b.format_name()
        else:
            print >> f, u" %s:" % host_a.format_name()

        # State.
        if self.state_changed:
            if host_a.state is not None:
                print >> f, u"-Host is %s." % host_a.state
            if host_b.state is not None:
                print >> f, u"+Host is %s." % host_b.state
        elif verbose:
            print >> f, u" Host is %s." % host_b.state

        # Extraports.
        if self.extraports_changed:
            if len(host_a.extraports) > 0:
                print >> f, u"-Not shown: %s" % host_a.extraports_string()
            if len(host_b.extraports) > 0:
                print >> f, u"+Not shown: %s" % host_b.extraports_string()
        elif verbose:
            if len(host_a.extraports) > 0:
                print >> f, u" Not shown: %s" % host_a.extraports_string()

        # Port table.
        port_table = Table(u"** * * *")
        if host_a.state is None:
            mark = u"+"
        elif host_b.state is None:
            mark = u"-"
        else:
            mark = u" "
        port_table.append((mark, u"PORT", u"STATE", u"SERVICE", u"VERSION"))

        for port in self.ports:
            port_diff = self.port_diffs[port]
            port_diff.append_to_port_table(port_table, host_a, host_b)

        if len(port_table) > 1:
            print >> f, port_table

        # OS changes.
        if self.os_changed or verbose:
            if len(host_a.os) > 0:
                if len(host_b.os) > 0:
                    print >> f, u" OS details:"
                else:
                    print >> f, u"-OS details:"
            elif len(host_b.os) > 0:
                print >> f, u"+OS details:"
            # os_diffs is a list of 5-tuples returned by
            # difflib.SequenceMatcher.
            for op, i1, i2, j1, j2 in self.os_diffs:
                if op == "replace" or op == "delete":
                    for i in range(i1, i2):
                        print >> f, "-  %s" % host_a.os[i]
                if op == "replace" or op == "insert":
                    for i in range(j1, j2):
                        print >> f, "+  %s" % host_b.os[i]
                if op == "equal":
                    for i in range(i1, i2):
                        print >> f, "   %s" % host_a.os[i]

        print_script_result_diffs_text("Host script results",
            host_a.script_results, host_b.script_results,
            self.script_result_diffs)

    def to_dom_fragment(self, document):
        host_a = self.host_a
        host_b = self.host_b

        frag = document.createDocumentFragment()
        hostdiff_elem = document.createElement(u"hostdiff")
        frag.appendChild(hostdiff_elem)

        if host_a.state is None or host_b.state is None:
            # The host is missing in one scan. Output the whole thing.
            if host_a.state is not None:
                a_elem = document.createElement(u"a")
                a_elem.appendChild(host_a.to_dom_fragment(document))
                hostdiff_elem.appendChild(a_elem)
            elif host_b.state is not None:
                b_elem = document.createElement(u"b")
                b_elem.appendChild(host_b.to_dom_fragment(document))
                hostdiff_elem.appendChild(b_elem)
            return frag

        host_elem = document.createElement(u"host")

        # State.
        if host_a.state == host_b.state:
            if verbose:
                host_elem.appendChild(host_a.state_to_dom_fragment(document))
        else:
            a_elem = document.createElement(u"a")
            a_elem.appendChild(host_a.state_to_dom_fragment(document))
            host_elem.appendChild(a_elem)
            b_elem = document.createElement(u"b")
            b_elem.appendChild(host_b.state_to_dom_fragment(document))
            host_elem.appendChild(b_elem)

        # Addresses.
        addrset_a = set(host_a.addresses)
        addrset_b = set(host_b.addresses)
        for addr in sorted(addrset_a.intersection(addrset_b)):
            host_elem.appendChild(addr.to_dom_fragment(document))
        a_elem = document.createElement(u"a")
        for addr in sorted(addrset_a - addrset_b):
            a_elem.appendChild(addr.to_dom_fragment(document))
        if a_elem.hasChildNodes():
            host_elem.appendChild(a_elem)
        b_elem = document.createElement(u"b")
        for addr in sorted(addrset_b - addrset_a):
            b_elem.appendChild(addr.to_dom_fragment(document))
        if b_elem.hasChildNodes():
            host_elem.appendChild(b_elem)

        # Host names.
        hostnames_elem = document.createElement(u"hostnames")
        hostnameset_a = set(host_a.hostnames)
        hostnameset_b = set(host_b.hostnames)
        for hostname in sorted(hostnameset_a.intersection(hostnameset_b)):
            hostnames_elem.appendChild(
                    host_a.hostname_to_dom_fragment(document, hostname))
        a_elem = document.createElement(u"a")
        for hostname in sorted(hostnameset_a - hostnameset_b):
            a_elem.appendChild(
                    host_a.hostname_to_dom_fragment(document, hostname))
        if a_elem.hasChildNodes():
            hostnames_elem.appendChild(a_elem)
        b_elem = document.createElement(u"b")
        for hostname in sorted(hostnameset_b - hostnameset_a):
            b_elem.appendChild(
                    host_b.hostname_to_dom_fragment(document, hostname))
        if b_elem.hasChildNodes():
            hostnames_elem.appendChild(b_elem)
        if hostnames_elem.hasChildNodes():
            host_elem.appendChild(hostnames_elem)

        ports_elem = document.createElement(u"ports")
        # Extraports.
        if host_a.extraports == host_b.extraports:
            ports_elem.appendChild(host_a.extraports_to_dom_fragment(document))
        else:
            a_elem = document.createElement(u"a")
            a_elem.appendChild(host_a.extraports_to_dom_fragment(document))
            ports_elem.appendChild(a_elem)
            b_elem = document.createElement(u"b")
            b_elem.appendChild(host_b.extraports_to_dom_fragment(document))
            ports_elem.appendChild(b_elem)
        # Port list.
        for port in self.ports:
            p_diff = self.port_diffs[port]
            if p_diff.cost == 0:
                if verbose:
                    ports_elem.appendChild(port.to_dom_fragment(document))
            else:
                ports_elem.appendChild(p_diff.to_dom_fragment(document))
        if ports_elem.hasChildNodes():
            host_elem.appendChild(ports_elem)

        # OS changes.
        if self.os_changed or verbose:
            os_elem = document.createElement(u"os")
            # os_diffs is a list of 5-tuples returned by
            # difflib.SequenceMatcher.
            for op, i1, i2, j1, j2 in self.os_diffs:
                if op == "replace" or op == "delete":
                    a_elem = document.createElement(u"a")
                    for i in range(i1, i2):
                        a_elem.appendChild(host_a.os_to_dom_fragment(
                            document, host_a.os[i]))
                    os_elem.appendChild(a_elem)
                if op == "replace" or op == "insert":
                    b_elem = document.createElement(u"b")
                    for i in range(j1, j2):
                        b_elem.appendChild(host_b.os_to_dom_fragment(
                            document, host_b.os[i]))
                    os_elem.appendChild(b_elem)
                if op == "equal":
                    for i in range(i1, i2):
                        os_elem.appendChild(host_a.os_to_dom_fragment(
                            document, host_a.os[i]))
            if os_elem.hasChildNodes():
                host_elem.appendChild(os_elem)

        # Host script changes.
        if len(self.script_result_diffs) > 0 or verbose:
            hostscript_elem = document.createElement(u"hostscript")
            host_elem.appendChild(script_result_diffs_to_dom_fragment(
                hostscript_elem, host_a.script_results,
                host_b.script_results, self.script_result_diffs,
                document))

        hostdiff_elem.appendChild(host_elem)

        return frag


class PortDiff(object):
    """A diff of two Ports. It contains the two ports and the cost of changing
    one into the other. If the cost is 0 then the two ports are the same."""
    def __init__(self, port_a, port_b):
        self.port_a = port_a
        self.port_b = port_b
        self.script_result_diffs = []
        self.cost = 0

        self.diff()

    def diff(self):
        if self.port_a.spec != self.port_b.spec:
            self.cost += 1

        if self.port_a.state != self.port_b.state:
            self.cost += 1

        if self.port_a.service != self.port_b.service:
            self.cost += 1

        self.script_result_diffs = ScriptResultDiff.diff_lists(
                self.port_a.script_results, self.port_b.script_results)
        self.cost += len(self.script_result_diffs)

    # PortDiffs are inserted into a Table and then printed, not printed out
    # directly. That's why this class has append_to_port_table instead of
    # print_text.
    def append_to_port_table(self, table, host_a, host_b):
        """Append this port diff to a Table containing five columns:
            +- PORT STATE SERVICE VERSION
        The "+-" stands for the diff indicator column."""
        a_columns = [self.port_a.spec_string(),
            self.port_a.state_string(),
            self.port_a.service.name_string(),
            self.port_a.service.version_string()]
        b_columns = [self.port_b.spec_string(),
            self.port_b.state_string(),
            self.port_b.service.name_string(),
            self.port_b.service.version_string()]
        if a_columns == b_columns:
            if verbose or self.script_result_diffs > 0:
                table.append([u" "] + a_columns)
        else:
            if not host_a.is_extraports(self.port_a.state):
                table.append([u"-"] + a_columns)
            if not host_b.is_extraports(self.port_b.state):
                table.append([u"+"] + b_columns)

        for sr_diff in self.script_result_diffs:
            sr_diff.append_to_port_table(table)

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        portdiff_elem = document.createElement(u"portdiff")
        frag.appendChild(portdiff_elem)
        if (self.port_a.spec == self.port_b.spec and
                self.port_a.state == self.port_b.state):
            port_elem = document.createElement(u"port")
            port_elem.setAttribute(u"portid", unicode(self.port_a.spec[0]))
            port_elem.setAttribute(u"protocol", self.port_a.spec[1])
            if self.port_a.state is not None:
                state_elem = document.createElement(u"state")
                state_elem.setAttribute(u"state", self.port_a.state)
                port_elem.appendChild(state_elem)
            if self.port_a.service == self.port_b.service:
                port_elem.appendChild(
                        self.port_a.service.to_dom_fragment(document))
            else:
                a_elem = document.createElement(u"a")
                a_elem.appendChild(
                        self.port_a.service.to_dom_fragment(document))
                port_elem.appendChild(a_elem)
                b_elem = document.createElement(u"b")
                b_elem.appendChild(
                        self.port_b.service.to_dom_fragment(document))
                port_elem.appendChild(b_elem)
            for sr_diff in self.script_result_diffs:
                port_elem.appendChild(sr_diff.to_dom_fragment(document))
            portdiff_elem.appendChild(port_elem)
        else:
            a_elem = document.createElement(u"a")
            a_elem.appendChild(self.port_a.to_dom_fragment(document))
            portdiff_elem.appendChild(a_elem)
            b_elem = document.createElement(u"b")
            b_elem.appendChild(self.port_b.to_dom_fragment(document))
            portdiff_elem.appendChild(b_elem)

        return frag


class ScriptResultDiff(object):
    def __init__(self, sr_a, sr_b):
        """One of sr_a and sr_b may be None."""
        self.sr_a = sr_a
        self.sr_b = sr_b

    def diff_lists(a, b):
        """Return a list of ScriptResultDiffs from two sorted lists of
        ScriptResults."""
        diffs = []
        i = 0
        j = 0
        # This algorithm is like a merge of sorted lists.
        while i < len(a) and j < len(b):
            if a[i].id < b[j].id:
                diffs.append(ScriptResultDiff(a[i], None))
                i += 1
            elif a[i].id > b[j].id:
                diffs.append(ScriptResultDiff(None, b[j]))
                j += 1
            else:
                if a[i].output != b[j].output or verbose:
                    diffs.append(ScriptResultDiff(a[i], b[j]))
                i += 1
                j += 1
        while i < len(a):
            diffs.append(ScriptResultDiff(a[i], None))
            i += 1
        while j < len(b):
            diffs.append(ScriptResultDiff(None, b[j]))
            j += 1
        return diffs
    diff_lists = staticmethod(diff_lists)

    # Script result diffs are appended to a port table rather than being
    # printed directly, so append_to_port_table exists instead of print_text.
    def append_to_port_table(self, table):
        a_lines = []
        b_lines = []
        if self.sr_a is not None:
            a_lines = self.sr_a.get_lines()
        if self.sr_b is not None:
            b_lines = self.sr_b.get_lines()
        if a_lines != b_lines or verbose:
            diffs = difflib.SequenceMatcher(None, a_lines, b_lines)
            for op, i1, i2, j1, j2 in diffs.get_opcodes():
                if op == "replace" or op == "delete":
                    for k in range(i1, i2):
                        table.append_raw(u"-" + a_lines[k])
                if op == "replace" or op == "insert":
                    for k in range(j1, j2):
                        table.append_raw(u"+" + b_lines[k])
                if op == "equal":
                    for k in range(i1, i2):
                        table.append_raw(u" " + a_lines[k])

    def to_dom_fragment(self, document):
        frag = document.createDocumentFragment()
        if (self.sr_a is not None and
                self.sr_b is not None and
                self.sr_a == self.sr_b):
            frag.appendChild(self.sr_a.to_dom_fragment(document))
        else:
            if self.sr_a is not None:
                a_elem = document.createElement(u"a")
                a_elem.appendChild(self.sr_a.to_dom_fragment(document))
                frag.appendChild(a_elem)
            if self.sr_b is not None:
                b_elem = document.createElement(u"b")
                b_elem.appendChild(self.sr_b.to_dom_fragment(document))
                frag.appendChild(b_elem)
        return frag


class Table(object):
    """A table of character data, like NmapOutputTable."""
    def __init__(self, template):
        """template is a string consisting of "*" and other characters. Each
        "*" is a left-justified space-padded field. All other characters are
        copied to the output."""
        self.widths = []
        self.rows = []
        self.prefix = u""
        self.padding = []
        j = 0
        while j < len(template) and template[j] != "*":
            j += 1
        self.prefix = template[:j]
        j += 1
        i = j
        while j < len(template):
            while j < len(template) and template[j] != "*":
                j += 1
            self.padding.append(template[i:j])
            j += 1
            i = j

    def append(self, row):
        strings = []

        row = list(row)
        # Remove trailing Nones.
        while len(row) > 0 and row[-1] is None:
            row.pop()

        for i in range(len(row)):
            if row[i] is None:
                s = u""
            else:
                s = str(row[i])
            if i == len(self.widths):
                self.widths.append(len(s))
            elif len(s) > self.widths[i]:
                self.widths[i] = len(s)
            strings.append(s)
        self.rows.append(strings)

    def append_raw(self, s):
        """Append a raw string for a row that is not formatted into columns."""
        self.rows.append(s)

    def __len__(self):
        return len(self.rows)

    def __str__(self):
        lines = []
        for row in self.rows:
            parts = [self.prefix]
            i = 0
            if isinstance(row, basestring):
                # A raw string.
                lines.append(row)
            else:
                while i < len(row):
                    parts.append(row[i].ljust(self.widths[i]))
                    if i < len(self.padding):
                        parts.append(self.padding[i])
                    i += 1
                lines.append(u"".join(parts).rstrip())
        return u"\n".join(lines)


def warn(str):
    """Print a warning to stderr."""
    print >> sys.stderr, str


class NmapContentHandler(xml.sax.handler.ContentHandler):
    """The xml.sax ContentHandler for the XML parser. It contains a Scan object
    that is filled in and can be read back again once the parse method is
    finished."""
    def __init__(self, scan):
        self.scan = scan

        # We keep a stack of the elements we've seen, pushing on start and
        # popping on end.
        self.element_stack = []

        self.current_host = None
        self.current_port = None

        self._start_elem_handlers = {
            u"nmaprun":    self._start_nmaprun,
            u"host":       self._start_host,
            u"status":     self._start_status,
            u"address":    self._start_address,
            u"hostname":   self._start_hostname,
            u"extraports": self._start_extraports,
            u"port":       self._start_port,
            u"state":      self._start_state,
            u"service":    self._start_service,
            u"script":     self._start_script,
            u"osmatch":    self._start_osmatch,
            u"finished":   self._start_finished,
        }
        self._end_elem_handlers = {
            u'host': self._end_host,
            u'port': self._end_port,
        }

    def parent_element(self):
        """Return the name of the element containing the current one, or None
        if this is the root element."""
        if len(self.element_stack) == 0:
            return None
        return self.element_stack[-1]

    def startElement(self, name, attrs):
        """This method keeps track of element_stack. The real parsing work is
        done in the _start_*() handlers. This is to make it easy for them to
        bail out on error."""
        handler = self._start_elem_handlers.get(name)
        if handler is not None:
            handler(name, attrs)
        self.element_stack.append(name)

    def endElement(self, name):
        """This method keeps track of element_stack. The real parsing work is
        done in _end_*() handlers."""
        self.element_stack.pop()
        handler = self._end_elem_handlers.get(name)
        if handler is not None:
            handler(name)

    def _start_nmaprun(self, name, attrs):
        assert self.parent_element() == None
        if "start" in attrs:
            start_timestamp = int(attrs.get(u"start"))
            self.scan.start_date = datetime.datetime.fromtimestamp(
                    start_timestamp)
        self.scan.scanner = attrs.get(u"scanner")
        self.scan.args = attrs.get(u"args")
        self.scan.version = attrs.get(u"version")

    def _start_host(self, name, attrs):
        assert self.parent_element() == u"nmaprun"
        self.current_host = Host()
        self.scan.hosts.append(self.current_host)

    def _start_status(self, name, attrs):
        assert self.parent_element() == u"host"
        assert self.current_host is not None
        state = attrs.get(u"state")
        if state is None:
            warn(u'%s element of host %s is missing the "state" attribute; '
                    'assuming \unknown\.' % (
                        name, self.current_host.format_name()))
            return
        self.current_host.state = state

    def _start_address(self, name, attrs):
        assert self.parent_element() == u"host"
        assert self.current_host is not None
        addr = attrs.get(u"addr")
        if addr is None:
            warn(u'%s element of host %s is missing the "addr" '
                    'attribute; skipping.' % (
                        name, self.current_host.format_name()))
            return
        addrtype = attrs.get(u"addrtype", u"ipv4")
        self.current_host.add_address(Address.new(addrtype, addr))

    def _start_hostname(self, name, attrs):
        assert self.parent_element() == u"hostnames"
        assert self.current_host is not None
        hostname = attrs.get(u"name")
        if hostname is None:
            warn(u'%s element of host %s is missing the "name" '
                    'attribute; skipping.' % (
                        name, self.current_host.format_name()))
            return
        self.current_host.add_hostname(hostname)

    def _start_extraports(self, name, attrs):
        assert self.parent_element() == u"ports"
        assert self.current_host is not None
        state = attrs.get(u"state")
        if state is None:
            warn(u'%s element of host %s is missing the "state" '
                    'attribute; assuming "unknown".' % (
                        name, self.current_host.format_name()))
            state = None
        if state in self.current_host.extraports:
            warn(u'Duplicate extraports state "%s" in host %s.' % (
                state, self.current_host.format_name()))

        count = attrs.get(u"count")
        if count is None:
            warn(u'%s element of host %s is missing the "count" '
                    'attribute; assuming 0.' % (
                        name, self.current_host.format_name()))
            count = 0
        else:
            try:
                count = int(count)
            except ValueError:
                warn(u"Can't convert extraports count \"%s\" "
                        "to an integer in host %s; assuming 0." % (
                            attrs[u"count"], self.current_host.format_name()))
                count = 0
        self.current_host.extraports[state] = count

    def _start_port(self, name, attrs):
        assert self.parent_element() == u"ports"
        assert self.current_host is not None
        portid_str = attrs.get(u"portid")
        if portid_str is None:
            warn(u'%s element of host %s missing the "portid" '
                    'attribute; skipping.' % (
                        name, self.current_host.format_name()))
            return
        try:
            portid = int(portid_str)
        except ValueError:
            warn(u"Can't convert portid \"%s\" to an integer "
                    "in host %s; skipping port." % (
                        portid_str, self.current_host.format_name()))
            return
        protocol = attrs.get(u"protocol")
        if protocol is None:
            warn(u'%s element of host %s missing the "protocol" '
                    'attribute; skipping.' % (
                        name, self.current_host.format_name()))
            return
        self.current_port = Port((portid, protocol))

    def _start_state(self, name, attrs):
        assert self.parent_element() == u"port"
        assert self.current_host is not None
        if self.current_port is None:
            return
        if "state" not in attrs:
            warn(u'%s element of port %s is missing the "state" '
                    'attribute; assuming "unknown".' % (
                        name, self.current_port.spec_string()))
            return
        self.current_port.state = attrs[u"state"]
        self.current_host.add_port(self.current_port)

    def _start_service(self, name, attrs):
        assert self.parent_element() == u"port"
        assert self.current_host is not None
        if self.current_port is None:
            return
        self.current_port.service.name = attrs.get(u"name")
        self.current_port.service.product = attrs.get(u"product")
        self.current_port.service.version = attrs.get(u"version")
        self.current_port.service.extrainfo = attrs.get(u"extrainfo")
        self.current_port.service.tunnel = attrs.get(u"tunnel")

    def _start_script(self, name, attrs):
        result = ScriptResult()
        result.id = attrs.get(u"id")
        if result.id is None:
            warn(u'%s element missing the "id" attribute; skipping.' % name)
            return

        result.output = attrs.get(u"output")
        if result.output is None:
            warn(u'%s element missing the "output" attribute; skipping.'
                    % name)
            return
        if self.parent_element() == u"prescript":
            self.scan.pre_script_results.append(result)
        elif self.parent_element() == u"postscript":
            self.scan.post_script_results.append(result)
        elif self.parent_element() == u"hostscript":
            self.current_host.script_results.append(result)
        elif self.parent_element() == u"port":
            self.current_port.script_results.append(result)
        else:
            warn(u"%s element not inside prescript, postscript, hostscript, "
                    "or port element; ignoring." % name)
            return

    def _start_osmatch(self, name, attrs):
        assert self.parent_element() == u"os"
        assert self.current_host is not None
        if "name" not in attrs:
            warn(u'%s element of host %s is missing the "name" '
                    'attribute; skipping.' % (
                        name, self.current_host.format_name()))
            return
        self.current_host.os.append(attrs[u"name"])

    def _start_finished(self, name, attrs):
        assert self.parent_element() == u"runstats"
        if "time" in attrs:
            end_timestamp = int(attrs.get(u"time"))
            self.scan.end_date = datetime.datetime.fromtimestamp(end_timestamp)

    def _end_host(self, name):
        self.current_host.script_results.sort()
        self.current_host = None

    def _end_port(self, name):
        self.current_port.script_results.sort()
        self.current_port = None


class XMLWriter (xml.sax.saxutils.XMLGenerator):
    def __init__(self, f):
        xml.sax.saxutils.XMLGenerator.__init__(self, f, "utf-8")
        self.f = f

    def frag(self, frag):
        for node in frag.childNodes:
            node.writexml(self.f, newl=u"\n")

    def frag_a(self, frag):
        self.startElement(u"a", {})
        for node in frag.childNodes:
            node.writexml(self.f, newl=u"\n")
        self.endElement(u"a")

    def frag_b(self, frag):
        self.startElement(u"b", {})
        for node in frag.childNodes:
            node.writexml(self.f, newl=u"\n")
        self.endElement(u"b")


def usage():
    print u"""\
Usage: %s [option] FILE1 FILE2
Compare two Nmap XML files and display a list of their differences.
Differences include host state changes, port state changes, and changes to
service and OS detection.

  -h, --help     display this help
  -v, --verbose  also show hosts and ports that haven't changed.
  --text         display output in text format (default)
  --xml          display output in XML format\
""" % sys.argv[0]

EXIT_EQUAL = 0
EXIT_DIFFERENT = 1
EXIT_ERROR = 2


def usage_error(msg):
    print >> sys.stderr, u"%s: %s" % (sys.argv[0], msg)
    print >> sys.stderr, u"Try '%s -h' for help." % sys.argv[0]
    sys.exit(EXIT_ERROR)


def main():
    global verbose
    output_format = None

    try:
        opts, input_filenames = getopt.gnu_getopt(
                sys.argv[1:], "hv", ["help", "text", "verbose", "xml"])
    except getopt.GetoptError, e:
        usage_error(e.msg)
    for o, a in opts:
        if o == "-h" or o == "--help":
            usage()
            sys.exit(0)
        elif o == "-v" or o == "--verbose":
            verbose = True
        elif o == "--text":
            if output_format is not None and output_format != "text":
                usage_error(u"contradictory output format options.")
            output_format = "text"
        elif o == "--xml":
            if output_format is not None and output_format != "xml":
                usage_error(u"contradictory output format options.")
            output_format = "xml"

    if len(input_filenames) != 2:
        usage_error(u"need exactly two input filenames.")

    if output_format is None:
        output_format = "text"

    filename_a = input_filenames[0]
    filename_b = input_filenames[1]

    try:
        scan_a = Scan()
        scan_a.load_from_file(filename_a)
        scan_b = Scan()
        scan_b.load_from_file(filename_b)
    except IOError, e:
        print >> sys.stderr, u"Can't open file: %s" % str(e)
        sys.exit(EXIT_ERROR)

    if output_format == "text":
        diff = ScanDiffText(scan_a, scan_b)
    elif output_format == "xml":
        diff = ScanDiffXML(scan_a, scan_b)
    cost = diff.output()

    if cost == 0:
        return EXIT_EQUAL
    else:
        return EXIT_DIFFERENT


# Catch uncaught exceptions so they can produce an exit code of 2 (EXIT_ERROR),
# not 1 like they would by default.
def excepthook(type, value, tb):
    sys.__excepthook__(type, value, tb)
    sys.exit(EXIT_ERROR)

if __name__ == "__main__":
    sys.excepthook = excepthook
    sys.exit(main())
