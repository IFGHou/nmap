#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ***********************IMPORTANT NMAP LICENSE TERMS************************
# *                                                                         *
# * The Nmap Security Scanner is (C) 1996-2012 Insecure.Com LLC. Nmap is    *
# * also a registered trademark of Insecure.Com LLC.  This program is free  *
# * software; you may redistribute and/or modify it under the terms of the  *
# * GNU General Public License as published by the Free Software            *
# * Foundation; Version 2 with the clarifications and exceptions described  *
# * below.  This guarantees your right to use, modify, and redistribute     *
# * this software under certain conditions.  If you wish to embed Nmap      *
# * technology into proprietary software, we sell alternative licenses      *
# * (contact sales@insecure.com).  Dozens of software vendors already       *
# * license Nmap technology such as host discovery, port scanning, OS       *
# * detection, version detection, and the Nmap Scripting Engine.            *
# *                                                                         *
# * Note that the GPL places important restrictions on "derived works", yet *
# * it does not provide a detailed definition of that term.  To avoid       *
# * misunderstandings, we interpret that term as broadly as copyright law   *
# * allows.  For example, we consider an application to constitute a        *
# * "derivative work" for the purpose of this license if it does any of the *
# * following:                                                              *
# * o Integrates source code from Nmap                                      *
# * o Reads or includes Nmap copyrighted data files, such as                *
# *   nmap-os-db or nmap-service-probes.                                    *
# * o Executes Nmap and parses the results (as opposed to typical shell or  *
# *   execution-menu apps, which simply display raw Nmap output and so are  *
# *   not derivative works.)                                                *
# * o Integrates/includes/aggregates Nmap into a proprietary executable     *
# *   installer, such as those produced by InstallShield.                   *
# * o Links to a library or executes a program that does any of the above   *
# *                                                                         *
# * The term "Nmap" should be taken to also include any portions or derived *
# * works of Nmap.  This list is not exclusive, but is meant to clarify our *
# * interpretation of derived works with some common examples.  Our         *
# * interpretation applies only to Nmap--we don't speak for other people's  *
# * GPL works.                                                              *
# *                                                                         *
# * If you have any questions about the GPL licensing restrictions on using *
# * Nmap in non-GPL works, we would be happy to help.  As mentioned above,  *
# * we also offer alternative license to integrate Nmap into proprietary    *
# * applications and appliances.  These contracts have been sold to dozens  *
# * of software vendors, and generally include a perpetual license as well  *
# * as providing for priority support and updates.  They also fund the      *
# * continued development of Nmap.  Please email sales@insecure.com for     *
# * further information.                                                    *
# *                                                                         *
# * As a special exception to the GPL terms, Insecure.Com LLC grants        *
# * permission to link the code of this program with any version of the     *
# * OpenSSL library which is distributed under a license identical to that  *
# * listed in the included docs/licenses/OpenSSL.txt file, and distribute   *
# * linked combinations including the two. You must obey the GNU GPL in all *
# * respects for all of the code used other than OpenSSL.  If you modify    *
# * this file, you may extend this exception to your version of the file,   *
# * but you are not obligated to do so.                                     *
# *                                                                         *
# * If you received these files with a written license agreement or         *
# * contract stating terms other than the terms above, then that            *
# * alternative license agreement takes precedence over these comments.     *
# *                                                                         *
# * Source is provided to this software because we believe users have a     *
# * right to know exactly what a program is going to do before they run it. *
# * This also allows you to audit the software for security holes (none     *
# * have been found so far).                                                *
# *                                                                         *
# * Source code also allows you to port Nmap to new platforms, fix bugs,    *
# * and add new features.  You are highly encouraged to send your changes   *
# * to nmap-dev@insecure.org for possible incorporation into the main       *
# * distribution.  By sending these changes to Fyodor or one of the         *
# * Insecure.Org development mailing lists, it is assumed that you are      *
# * offering the Nmap Project (Insecure.Com LLC) the unlimited,             *
# * non-exclusive right to reuse, modify, and relicense the code.  Nmap     *
# * will always be available Open Source, but this is important because the *
# * inability to relicense code has caused devastating problems for other   *
# * Free Software projects (such as KDE and NASM).  We also occasionally    *
# * relicense the code to third parties as discussed above.  If you wish to *
# * specify special license conditions of your contributions, just say so   *
# * when you send them.                                                     *
# *                                                                         *
# * This program is distributed in the hope that it will be useful, but     *
# * WITHOUT ANY WARRANTY; without even the implied warranty of              *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       *
# * General Public License v2.0 for more details at                         *
# * http://www.gnu.org/licenses/gpl-2.0.html , or in the COPYING file       *
# * included with Nmap.                                                     *
# *                                                                         *
# ***************************************************************************/

"""
higwidgets/higspinner.py

   a pygtk spinner, based on the epiphany/nautilus implementation
"""

__all__ = ['HIGSpinner']

import os
import gtk
import gobject

from gtkutils import gobject_register

class HIGSpinnerImages:
    def __init__(self):
        """This class holds list of GDK Pixbuffers.

        - static_pixbufs is used for multiple static pixbuffers
        - self.animated_pixbufs is used for the pixbuffers that make up the animation
        """

        dprint('HIGSpinnerImages::__init__')

        # The Nautilus/Epiphany implementation uses a single "rest/quiescent"
        # static pixbuffer. We'd rather allow the developer to choose from
        # multiple static states, such as "done" or "failed".
        # Index it by a name like that.
        self.static_pixbufs = {}

        # We should have a default rest pixbuf, set it with set_rest_pixbuf()
        self.rest_pixbuf = None

        # This is a list of pixbufs to be used on the animation
        # For now, we're only implementing a single animation. Inconsistent!
        self.animated_pixbufs = []

    def add_static_pixbuf(self, name, pixbuf, default_on_rest=False):
        """Add a static pixbuf.

        If this is the first one, make it the default pixbuffer on rest.
        The user can make some other pixbuf the new default on rest, by setting
        default_on_rest to True.
        """

        dprint('HIGSpinnerImages::add_static_pixbuf')

        self.static_pixbufs[name] = pixbuf
        if (len(self.static_pixbufs) == 1) or default_on_rest:
            self.set_rest_pixbuf(name)

    def add_animated_pixbuf(self, pixbuf):

        dprint('HIGSpinnerImages::add_animated_pixbuf')

        self.animated_pixbufs.append(pixbuf)

    def set_rest_pixbuf(self, name):
        """Sets the pixbuf that will be used on the default, 'rest' state. """

        dprint('HIGSpinnerImages::set_rest_pixbuf')

        if not self.static_pixbufs.has_key(name):
            raise StaticPixbufNotFound

        # self.rest_pixbuf holds the *real* pixbuf, not it's name
        self.rest_pixbuf = self.static_pixbufs[name]

    def set_size(self, width, height):
        """Sets the size of eache pixbuf (static and animated)"""
        new_animated = []
        for p in self.animated_pixbufs:
            new_animated.append(p.scale_simple(width, height,
                                               gtk.gdk.INTERP_BILINEAR))
        self.animated_pixbufs = new_animated

        for k in self.static_pixbufs:
            self.static_pixbufs[k] = self.static_pixbufs[k].\
                                     scale_simple(width,
                                                  height,
                                                  gtk.gdk.INTERP_BILINEAR)

        self.rest_pixbuf = self.rest_pixbuf.\
                           scale_simple(width,
                                        height,
                                        gtk.gdk.INTERP_BILINEAR)

        self.images_width = width
        self.images_height = height


class HIGSpinnerCache:
    """This hols a copy of the images used on the HIGSpinners instances."""
    def __init__(self):

        dprint('HIGSpinnerCache::__init__')

        # Our own instance of a HIGSpinnerImages
        self.spinner_images = HIGSpinnerImages()

        # These are on Private member in the C implementation
        self.icon_theme = gtk.IconTheme()
        self.originals = None
        self.images = None

        # We might have access to a "default" animated icon.
        # For example, if we're on a GNOME desktop, and have the (default)
        # "gnome-icon-theme" package installed, we might have access
        # to "gnome-spinner". Check it before using, though
        if (self.icon_theme.lookup_icon("gnome-spinner", -1, 0)):
            self.default_animated_icon_name = "gnome-spinner"
        else:
            self.default_animated_icon_name = None

    def load_animated_from_lookup(self, icon_name=None):
        """Loads an animated icon by doing a lookup on the icon theme."""

        # If user do not choose a icon_name, use the default one
        if icon_name == None:
            icon_name = self.default_animated_icon_name

        # Even the default one (now on icon_name) might not be available
        if icon_name == None:
            raise AnimatedIconNotFound

        # Try to lookup the icon
        icon_info = self.icon_theme.lookup_icon(icon_name, -1, 0)
        # Even if icon_name exists, it might not be found by lookup
        if icon_info == None:
            raise AnimatedIconNotFound

        # Base size is, according to PyGTK docs:
        # "a size for the icon that was specified by the icon theme creator,
        #  This may be different than the actual size of image."
        # Ouch! We are acting on blind faith here...
        size = icon_info.get_base_size()

        # NOTE: If the icon is a builtin, it will not have a filename, see:
        # http://www.pygtk.org/pygtk2reference/class-gtkicontheme.html
        # But, we are not using the gtk.ICON_LOOKUP_USE_BUILTIN flag, nor does
        # GTK+ has a builtin animation, so we are safe ;-)
        filename = icon_info.get_filename()

        # Now that we have a filename, call load_animated_from_filename()
        self.load_animated_from_filename(filename, size)

    def load_animated_from_filename(self, filename, size):
        # grid_pixbuf is a pixbuf that holds the entire
        grid_pixbuf = gtk.gdk.pixbuf_new_from_file(filename)
        grid_width = grid_pixbuf.get_width()
        grid_height = grid_pixbuf.get_height()

        for x in range(0, grid_width, size):
            for y in range(0, grid_height, size):
                self.spinner_images.add_animated_pixbuf(\
                    self.__extract_frame(grid_pixbuf, x, y, size, size))

    def load_static_from_lookup(self, icon_name="gnome-spinner-rest",
                                key_name=None):
        icon_info = self.icon_theme.lookup_icon(icon_name, -1, 0)
        size = icon_info.get_base_size()
        filename = icon_info.get_filename()

        # Now that we have a filename, call load_static_from_filename()
        self.load_static_from_filename(filename)

    def load_static_from_filename(self, filename, key_name=None):
        icon_pixbuf = gtk.gdk.pixbuf_new_from_file(filename)

        if key_name == None:
            key_name = filename.split(".")[0]

        self.spinner_images.add_static_pixbuf(key_name, icon_pixbuf)

    def __extract_frame(self, pixbuf, x, y, w, h):
        """Cuts a sub pixbuffer, usually a frame of an animation.

        - pixbuf is the complete pixbuf, from which a frame will be cut off
        - x/y are the position
        - w (width) is the is the number of pixels to move right
        - h (height) is the is the number of pixels to move down
        """
        if (x + w > pixbuf.get_width()) or (y + h > pixbuf.get_height()):
            raise PixbufSmallerThanRequiredError
        return pixbuf.subpixbuf(x, y, w, h)

    def _write_animated_pixbuf_to_files(self, path_format, image_format):
        """Writes image files from self.spinner_images.animated_pixbufs

        - path_format should be a format string with one occurrence of a
          string substitution, such as '/tmp/animation_%s.png'
        - image_format can be either 'png' or 'jpeg'
        """
        counter = 0
        for i in self.spinner_images.animated_pixbufs:
            i.save(path_format % counter, "png")
            counter += 1

    def _write_static_pixbuf_to_file(self, key_name, path_name, image_format):
        self.spinner_images.static_pixbufs[key_name].save(path_name,
                                                          image_format)

class HIGSpinner(gtk.EventBox):
    """Simple spinner, such as the one found in webbrowsers and file managers.

    You can construct it with the optional parameters:
    * images, a list of images that will make up the animation
    * width, the width that will be set for the images
    * height, the height that will be set for the images
    """

    __gsignals__ = { 'expose-event' : 'override',
                     'size-request' : 'override' }

    def __init__(self):
        gtk.EventBox.__init__(self)

        #self.set_events(self.get_events())

        # This holds a GDK Graphic Context
        self.gc = None

        # These are sane defaults, but should really come from the images
        self.images_width = 32
        self.images_height = 32

        # Timeout set to 100 miliseconds per frame, just as the
        # Nautilus/Epiphany implementation
        self.timeout = 120

        # Initialize a cache for ouselves
        self.cache = HIGSpinnerCache()
        self.cache.load_static_from_lookup()
        self.cache.load_animated_from_lookup()

        # timer_task it the gobject.timeout_add identifier (when the animation
        # is in progress, and __bump_frame is being continually called). If the
        # spinner is static, timer_task is 0
        self.timer_task = 0
        # animated_pixbuf_index is a index on
        self.animated_pixbuf_index = 0
        # current_pixbuf is initially the default rest_pixbuf
        self.current_pixbuf = self.cache.spinner_images.rest_pixbuf

    def __bump_frame(self):
        """This function moves the animated frame to the next one, or, if it's
        currently the last one, back to the first one"""
        animated_list = self.cache.spinner_images.animated_pixbufs
        if self.animated_pixbuf_index == (len(animated_list) - 1):
            # back to the first one
            self.animated_pixbuf_index = 0
        else:
            # go the next one
            self.animated_pixbuf_index += 1

        self.queue_draw()
        return True

    def __select_pixbuf(self):
        """This selects either a rest pixbuf or a animation frame based on the
        status of timer_task."""
        if self.timer_task == 0:
            self.current_pixbuf = self.cache.spinner_images.rest_pixbuf
        else:
            self.current_pixbuf = self.cache.spinner_images.animated_pixbufs\
                                  [self.animated_pixbuf_index]

    def start(self):
        """Starts the animation"""
        if self.timer_task == 0:
            self.timer_task = gobject.timeout_add(self.timeout,
                                                  self.__bump_frame)

    def pause(self):
        """Pauses the animation"""
        if self.timer_task != 0:
            gobject.source_remove(self.timer_task)

        self.timer_task = 0
        self.queue_draw()


    def stop(self):
        """Stops the animation

        Do the same stuff as pause, but returns the animation to the beggining."""
        self.pause()
        self.animated_pixbuf_index = 0

    def set_speed(speed_in_milliseconds):
        self.timeout = speed_in_milliseconds
        self.pause()
        self.start()

    def do_expose_event(self, event):
        #self.chain(event)

        if self.cache.spinner_images.rest_pixbuf == None:
            raise RestPixbufNotFound

        self.__select_pixbuf()

        width = self.current_pixbuf.get_width()
        height = self.current_pixbuf.get_height()
        x_offset = (self.allocation.width - width) / 2
        y_offset = (self.allocation.height - height) / 2

        pix_area = gtk.gdk.Rectangle(x_offset + self.allocation.x,
                                     y_offset + self.allocation.y,
                                     width, height)

        dest = event.area.intersect(pix_area)

        # If a graphic context doesn't not exist yet, create one
        if self.gc == None:
            self.gc = gtk.gdk.GC(self.window)
        #gc = self.gc

        self.window.draw_pixbuf(self.gc,
                                self.current_pixbuf,
                                dest.x - x_offset - self.allocation.x,
                                dest.y - y_offset - self.allocation.y,
                                dest.x, dest.y,
                                dest.width, dest.height)

    def do_size_request(self, requisition):
        # http://www.pygtk.org/pygtk2reference/class-gtkrequisition.html

        # FIXME, this should really come from the pixbuf size + margins
        requisition.width = self.cache.spinner_images.images_width
        requisition.height = self.cache.spinner_images.images_height

gobject_register(HIGSpinner)
