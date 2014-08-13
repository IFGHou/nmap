#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ***********************IMPORTANT NMAP LICENSE TERMS************************
# *                                                                         *
# * The Nmap Security Scanner is (C) 1996-2013 Insecure.Com LLC. Nmap is    *
# * also a registered trademark of Insecure.Com LLC.  This program is free  *
# * software; you may redistribute and/or modify it under the terms of the  *
# * GNU General Public License as published by the Free Software            *
# * Foundation; Version 2 ("GPL"), BUT ONLY WITH ALL OF THE CLARIFICATIONS  *
# * AND EXCEPTIONS DESCRIBED HEREIN.  This guarantees your right to use,    *
# * modify, and redistribute this software under certain conditions.  If    *
# * you wish to embed Nmap technology into proprietary software, we sell    *
# * alternative licenses (contact sales@nmap.com).  Dozens of software      *
# * vendors already license Nmap technology such as host discovery, port    *
# * scanning, OS detection, version detection, and the Nmap Scripting       *
# * Engine.                                                                 *
# *                                                                         *
# * Note that the GPL places important restrictions on "derivative works",  *
# * yet it does not provide a detailed definition of that term.  To avoid   *
# * misunderstandings, we interpret that term as broadly as copyright law   *
# * allows.  For example, we consider an application to constitute a        *
# * derivative work for the purpose of this license if it does any of the   *
# * following with any software or content covered by this license          *
# * ("Covered Software"):                                                   *
# *                                                                         *
# * o Integrates source code from Covered Software.                         *
# *                                                                         *
# * o Reads or includes copyrighted data files, such as Nmap's nmap-os-db   *
# * or nmap-service-probes.                                                 *
# *                                                                         *
# * o Is designed specifically to execute Covered Software and parse the    *
# * results (as opposed to typical shell or execution-menu apps, which will *
# * execute anything you tell them to).                                     *
# *                                                                         *
# * o Includes Covered Software in a proprietary executable installer.  The *
# * installers produced by InstallShield are an example of this.  Including *
# * Nmap with other software in compressed or archival form does not        *
# * trigger this provision, provided appropriate open source decompression  *
# * or de-archiving software is widely available for no charge.  For the    *
# * purposes of this license, an installer is considered to include Covered *
# * Software even if it actually retrieves a copy of Covered Software from  *
# * another source during runtime (such as by downloading it from the       *
# * Internet).                                                              *
# *                                                                         *
# * o Links (statically or dynamically) to a library which does any of the  *
# * above.                                                                  *
# *                                                                         *
# * o Executes a helper program, module, or script to do any of the above.  *
# *                                                                         *
# * This list is not exclusive, but is meant to clarify our interpretation  *
# * of derived works with some common examples.  Other people may interpret *
# * the plain GPL differently, so we consider this a special exception to   *
# * the GPL that we apply to Covered Software.  Works which meet any of     *
# * these conditions must conform to all of the terms of this license,      *
# * particularly including the GPL Section 3 requirements of providing      *
# * source code and allowing free redistribution of the work as a whole.    *
# *                                                                         *
# * As another special exception to the GPL terms, Insecure.Com LLC grants  *
# * permission to link the code of this program with any version of the     *
# * OpenSSL library which is distributed under a license identical to that  *
# * listed in the included docs/licenses/OpenSSL.txt file, and distribute   *
# * linked combinations including the two.                                  *
# *                                                                         *
# * Any redistribution of Covered Software, including any derived works,    *
# * must obey and carry forward all of the terms of this license, including *
# * obeying all GPL rules and restrictions.  For example, source code of    *
# * the whole work must be provided and free redistribution must be         *
# * allowed.  All GPL references to "this License", are to be treated as    *
# * including the terms and conditions of this license text as well.        *
# *                                                                         *
# * Because this license imposes special exceptions to the GPL, Covered     *
# * Work may not be combined (even as part of a larger work) with plain GPL *
# * software.  The terms, conditions, and exceptions of this license must   *
# * be included as well.  This license is incompatible with some other open *
# * source licenses as well.  In some cases we can relicense portions of    *
# * Nmap or grant special permissions to use it in other open source        *
# * software.  Please contact fyodor@nmap.org with any such requests.       *
# * Similarly, we don't incorporate incompatible open source software into  *
# * Covered Software without special permission from the copyright holders. *
# *                                                                         *
# * If you have any questions about the licensing restrictions on using     *
# * Nmap in other works, are happy to help.  As mentioned above, we also    *
# * offer alternative license to integrate Nmap into proprietary            *
# * applications and appliances.  These contracts have been sold to dozens  *
# * of software vendors, and generally include a perpetual license as well  *
# * as providing for priority support and updates.  They also fund the      *
# * continued development of Nmap.  Please email sales@nmap.com for further *
# * information.                                                            *
# *                                                                         *
# * If you have received a written license agreement or contract for        *
# * Covered Software stating terms other than these, you may choose to use  *
# * and redistribute Covered Software under those terms instead of these.   *
# *                                                                         *
# * Source is provided to this software because we believe users have a     *
# * right to know exactly what a program is going to do before they run it. *
# * This also allows you to audit the software for security holes.          *
# *                                                                         *
# * Source code also allows you to port Nmap to new platforms, fix bugs,    *
# * and add new features.  You are highly encouraged to send your changes   *
# * to the dev@nmap.org mailing list for possible incorporation into the    *
# * main distribution.  By sending these changes to Fyodor or one of the    *
# * Insecure.Org development mailing lists, or checking them into the Nmap  *
# * source code repository, it is understood (unless you specify otherwise) *
# * that you are offering the Nmap Project (Insecure.Com LLC) the           *
# * unlimited, non-exclusive right to reuse, modify, and relicense the      *
# * code.  Nmap will always be available Open Source, but this is important *
# * because the inability to relicense code has caused devastating problems *
# * for other Free Software projects (such as KDE and NASM).  We also       *
# * occasionally relicense the code to third parties as discussed above.    *
# * If you wish to specify special license conditions of your               *
# * contributions, just say so when you send them.                          *
# *                                                                         *
# * This program is distributed in the hope that it will be useful, but     *
# * WITHOUT ANY WARRANTY; without even the implied warranty of              *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the Nmap      *
# * license file for more details (it's in a COPYING file included with     *
# * Nmap, and also available from https://svn.nmap.org/nmap/COPYING         *
# *                                                                         *
# ***************************************************************************/

import gtk
import pango

from zenmapGUI.higwidgets.higboxes import HIGHBox, HIGVBox
from zenmapGUI.higwidgets.higbuttons import HIGButton
from zenmapGUI.higwidgets.higscrollers import HIGScrolledWindow
import zenmapCore.I18N


def status_data_func(widget, cell_renderer, model, iter):
    entry = model.get_value(iter, 0)
    if entry.running:
        status = _("Running")
    elif entry.finished:
        if entry.parsed is not None and entry.parsed.unsaved:
            status = _("Unsaved")
        else:
            status = ""
    elif entry.failed:
        status = _("Failed")
    elif entry.canceled:
        status = _("Canceled")
    cell_renderer.set_property("text", status)


def command_data_func(widget, cell_renderer, model, iter):
    entry = model.get_value(iter, 0)
    cell_renderer.set_property("ellipsize", pango.ELLIPSIZE_END)
    cell_renderer.set_property("text", entry.get_command_string())


class ScanScanListPage(HIGVBox):
    """This is the "Scans" scan results tab. It the list of running and
    finished scans contained in the ScansListStore passed to the
    constructor."""
    def __init__(self, scans_store):
        HIGVBox.__init__(self)

        self.set_spacing(4)

        scans_store.connect("row-changed", self._row_changed)

        self.scans_list = gtk.TreeView(scans_store)
        self.scans_list.get_selection().connect(
                "changed", self._selection_changed)

        status_col = gtk.TreeViewColumn(_("Status"))
        cell = gtk.CellRendererText()
        status_col.pack_start(cell)
        status_col.set_cell_data_func(cell, status_data_func)
        self.scans_list.append_column(status_col)

        command_col = gtk.TreeViewColumn(_("Command"))
        cell = gtk.CellRendererText()
        command_col.pack_start(cell)
        command_col.set_cell_data_func(cell, command_data_func)
        self.scans_list.append_column(command_col)

        scrolled_window = HIGScrolledWindow()
        scrolled_window.set_border_width(0)
        scrolled_window.add(self.scans_list)

        self.pack_start(scrolled_window, True, True)

        hbox = HIGHBox()
        buttonbox = gtk.HButtonBox()
        buttonbox.set_layout(gtk.BUTTONBOX_START)
        buttonbox.set_spacing(4)

        self.append_button = HIGButton(_("Append Scan"), gtk.STOCK_ADD)
        buttonbox.pack_start(self.append_button, False)

        self.remove_button = HIGButton(_("Remove Scan"), gtk.STOCK_REMOVE)
        buttonbox.pack_start(self.remove_button, False)

        self.cancel_button = HIGButton(_("Cancel Scan"), gtk.STOCK_CANCEL)
        buttonbox.pack_start(self.cancel_button, False)

        hbox.pack_start(buttonbox, padding=4)

        self.pack_start(hbox, False, padding=4)

        self._update()

    def _row_changed(self, model, path, i):
        self._update()

    def _selection_changed(self, selection):
        self._update()

    def _update(self):
        # Make the Cancel button sensitive or not depending on whether a
        # running scan is selected.
        tree_selection = self.scans_list.get_selection()
        if tree_selection is None:
            # I can't find anything in the PyGTK documentation that suggests
            # this is possible, but we received many crash reports that
            # indicate it is.
            model, selection = None, []
        else:
            model, selection = tree_selection.get_selected_rows()

        for path in selection:
            entry = model.get_value(model.get_iter(path), 0)
            if entry.running:
                self.cancel_button.set_sensitive(True)
                break
        else:
            self.cancel_button.set_sensitive(False)

        if len(selection) == 0:
            self.remove_button.set_sensitive(False)
        else:
            self.remove_button.set_sensitive(True)
