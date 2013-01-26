
/***************************************************************************
 * TargetGroup.h -- The "TargetGroup" class holds a group of IP addresses, *
 * such as those from a '/16' or '10.*.*.*' specification.  It also has a  *
 * trivial HostGroupState class which handles a bunch of expressions that  *
 * go into TargetGroup classes.                                            *
 *                                                                         *
 ***********************IMPORTANT NMAP LICENSE TERMS************************
 *                                                                         *
 * The Nmap Security Scanner is (C) 1996-2012 Insecure.Com LLC. Nmap is    *
 * also a registered trademark of Insecure.Com LLC.  This program is free  *
 * software; you may redistribute and/or modify it under the terms of the  *
 * GNU General Public License as published by the Free Software            *
 * Foundation; Version 2 with the clarifications and exceptions described  *
 * below.  This guarantees your right to use, modify, and redistribute     *
 * this software under certain conditions.  If you wish to embed Nmap      *
 * technology into proprietary software, we sell alternative licenses      *
 * (contact sales@insecure.com).  Dozens of software vendors already       *
 * license Nmap technology such as host discovery, port scanning, OS       *
 * detection, version detection, and the Nmap Scripting Engine.            *
 *                                                                         *
 * Note that the GPL places important restrictions on "derived works", yet *
 * it does not provide a detailed definition of that term.  To avoid       *
 * misunderstandings, we interpret that term as broadly as copyright law   *
 * allows.  For example, we consider an application to constitute a        *
 * "derivative work" for the purpose of this license if it does any of the *
 * following:                                                              *
 * o Integrates source code from Nmap                                      *
 * o Reads or includes Nmap copyrighted data files, such as                *
 *   nmap-os-db or nmap-service-probes.                                    *
 * o Executes Nmap and parses the results (as opposed to typical shell or  *
 *   execution-menu apps, which simply display raw Nmap output and so are  *
 *   not derivative works.)                                                *
 * o Integrates/includes/aggregates Nmap into a proprietary executable     *
 *   installer, such as those produced by InstallShield.                   *
 * o Links to a library or executes a program that does any of the above   *
 *                                                                         *
 * The term "Nmap" should be taken to also include any portions or derived *
 * works of Nmap, as well as other software we distribute under this       *
 * license such as Zenmap, Ncat, and Nping.  This list is not exclusive,   *
 * but is meant to clarify our interpretation of derived works with some   *
 * common examples.  Our interpretation applies only to Nmap--we don't     *
 * speak for other people's GPL works.                                     *
 *                                                                         *
 * If you have any questions about the GPL licensing restrictions on using *
 * Nmap in non-GPL works, we would be happy to help.  As mentioned above,  *
 * we also offer alternative license to integrate Nmap into proprietary    *
 * applications and appliances.  These contracts have been sold to dozens  *
 * of software vendors, and generally include a perpetual license as well  *
 * as providing for priority support and updates.  They also fund the      *
 * continued development of Nmap.  Please email sales@insecure.com for     *
 * further information.                                                    *
 *                                                                         *
 * As a special exception to the GPL terms, Insecure.Com LLC grants        *
 * permission to link the code of this program with any version of the     *
 * OpenSSL library which is distributed under a license identical to that  *
 * listed in the included docs/licenses/OpenSSL.txt file, and distribute   *
 * linked combinations including the two. You must obey the GNU GPL in all *
 * respects for all of the code used other than OpenSSL.  If you modify    *
 * this file, you may extend this exception to your version of the file,   *
 * but you are not obligated to do so.                                     *
 *                                                                         *
 * If you received these files with a written license agreement or         *
 * contract stating terms other than the terms above, then that            *
 * alternative license agreement takes precedence over these comments.     *
 *                                                                         *
 * Source is provided to this software because we believe users have a     *
 * right to know exactly what a program is going to do before they run it. *
 * This also allows you to audit the software for security holes (none     *
 * have been found so far).                                                *
 *                                                                         *
 * Source code also allows you to port Nmap to new platforms, fix bugs,    *
 * and add new features.  You are highly encouraged to send your changes   *
 * to the dev@nmap.org mailing list for possible incorporation into the    *
 * main distribution.  By sending these changes to Fyodor or one of the    *
 * Insecure.Org development mailing lists, or checking them into the Nmap  *
 * source code repository, it is understood (unless you specify otherwise) *
 * that you are offering the Nmap Project (Insecure.Com LLC) the           *
 * unlimited, non-exclusive right to reuse, modify, and relicense the      *
 * code.  Nmap will always be available Open Source, but this is important *
 * because the inability to relicense code has caused devastating problems *
 * for other Free Software projects (such as KDE and NASM).  We also       *
 * occasionally relicense the code to third parties as discussed above.    *
 * If you wish to specify special license conditions of your               *
 * contributions, just say so when you send them.                          *
 *                                                                         *
 * This program is distributed in the hope that it will be useful, but     *
 * WITHOUT ANY WARRANTY; without even the implied warranty of              *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the Nmap      *
 * license file for more details (it's in a COPYING file included with     *
 * Nmap, and also available from https://svn.nmap.org/nmap/COPYING         *
 *                                                                         *
 ***************************************************************************/

/* $Id$ */

#ifndef TARGETGROUP_H
#define TARGETGROUP_H

#include <limits.h>

#include <list>
#include <queue>
#include <set>
#include <string>

#include "nmap.h"

/* We use bit vectors to represent what values are allowed in an IPv4 octet.
   Each vector is built up of an array of bitvector_t (any convenient integer
   type). */
typedef unsigned long bitvector_t;
/* A 256-element bit vector, representing legal values for one octet. */
typedef bitvector_t octet_bitvector[(256 - 1) / (sizeof(unsigned long) * CHAR_BIT) + 1];

class NetBlock {
public:
  virtual ~NetBlock() {}
  std::string hostname;
  std::list<struct sockaddr_storage> resolvedaddrs;

  /* Parses an expression such as 192.168.0.0/16, 10.1.0-5.1-254, or
     fe80::202:e3ff:fe14:1102/112 and returns a newly allocated NetBlock. The af
     parameter is AF_INET or AF_INET6. Returns NULL in case of error. */
  static NetBlock *parse_expr(const char *target_expr, int af);

  bool is_resolved_address(const struct sockaddr_storage *ss) const;

  virtual bool next(struct sockaddr_storage *ss) = 0;
  virtual void apply_netmask(int bits) = 0;
  virtual std::string str() const = 0;
};

class NetBlockIPv4Ranges : public NetBlock {
public:
  octet_bitvector octets[4];

  NetBlockIPv4Ranges();

  bool next(struct sockaddr_storage *ss);
  void apply_netmask(int bits);
  std::string str() const;

private:
  unsigned int counter[4];
};

class NetBlockIPv6Netmask : public NetBlock {
public:
  void set_addr(const struct sockaddr_in6 *addr);

  bool next(struct sockaddr_storage *ss);
  void apply_netmask(int bits);
  std::string str() const;

private:
  bool exhausted;
  struct sockaddr_in6 addr;
  struct in6_addr start;
  struct in6_addr cur;
  struct in6_addr end;
};

class NetBlockHostname : public NetBlock {
public:
  NetBlockHostname(const char *hostname, int af);
  int af;
  int bits;

  NetBlock *resolve() const;

  bool next(struct sockaddr_storage *ss);
  void apply_netmask(int bits);
  std::string str() const;
};

/* Adding new targets is for NSE scripts */
class NewTargets {
public:
  NewTargets();

  /* return a previous inserted target */
  static std::string read (void);

  /* clear the scanned_targets_cache */
  static void clear (void);

  /* get the number of all new added targets */
  static unsigned long get_number (void);

  /* get the number that have been scanned */
  static unsigned long get_scanned (void);

  /* get the number of queued targets left to scan */
  static unsigned long get_queued (void);

  /* get the new_targets object */
  static NewTargets *get (void);

  /* insert targets to the new_targets_queue */
  static unsigned long insert (const char *target);
private:
  /* unsigned long mex_new_targets; */

  /* A queue to push new targets that were discovered by NSE scripts.
   * Nmap will pop future targets from this queue. */
  std::queue<std::string> queue;

  /* A cache to save scanned targets specifiactions.
   * (These are targets that were pushed to Nmap scan queue) */
  std::set<std::string> history;

  void Initialize();

  /* Save new targets onto the queue */
  unsigned long push (const char *target);
protected:
  static NewTargets *new_targets;
};

#endif /* TARGETGROUP_H */
