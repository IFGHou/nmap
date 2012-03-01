
/***************************************************************************
 * FingerPrintResults.cc -- The FingerPrintResults class the results of OS *
 * fingerprint matching against a certain host.                            *
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
 * to nmap-dev@insecure.org for possible incorporation into the main       *
 * distribution.  By sending these changes to Fyodor or one of the         *
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       *
 * General Public License v2.0 for more details at                         *
 * http://www.gnu.org/licenses/gpl-2.0.html , or in the COPYING file       *
 * included with Nmap.                                                     *
 *                                                                         *
 ***************************************************************************/

/* $Id$ */

#include "FingerPrintResults.h"
#include "osscan.h"
#include "NmapOps.h"

extern NmapOps o;

FingerPrintResults::FingerPrintResults() {
  num_perfect_matches = num_matches = 0;
  overall_results = OSSCAN_NOMATCHES;
  memset(accuracy, 0, sizeof(accuracy));
  isClassified = false;
  osscan_opentcpport = osscan_closedtcpport = osscan_closedudpport = -1;
  distance = -1;
  distance_guess = -1;
  maxTimingRatio = 0;
}

FingerPrintResults::~FingerPrintResults() {
}

FingerPrintResultsIPv4::FingerPrintResultsIPv4() {
  FPs = (FingerPrint **) safe_zalloc(o.maxOSTries() * sizeof(FingerPrint *));
  numFPs = 0;
}

FingerPrintResultsIPv4::~FingerPrintResultsIPv4() {
  int i;

  /* Free OS fingerprints of OS scanning was done */
  for(i=0; i < numFPs; i++) {
    delete(FPs[i]);
    FPs[i] = NULL;
  }
  numFPs = 0;
  free(FPs);
}

FingerPrintResultsIPv6::FingerPrintResultsIPv6() {
  unsigned int i;

  begin_time.tv_sec = 0;
  begin_time.tv_usec = 0;
  for (i = 0; i < sizeof(fp_responses) / sizeof(*fp_responses); i++)
    fp_responses[i] = NULL;
  flow_label = 0;
}

FingerPrintResultsIPv6::~FingerPrintResultsIPv6() {
  unsigned int i;

  for (i = 0; i < sizeof(fp_responses) / sizeof(*fp_responses); i++) {
    if (fp_responses[i])
      delete fp_responses[i];
  }
}

const struct OS_Classification_Results *FingerPrintResults::getOSClassification() {
  if (!isClassified) { populateClassification(); isClassified = true; }
  return &OSR;
}

/* If the fingerprint is of potentially poor quality, we don't want to
   print it and ask the user to submit it.  In that case, the reason
   for skipping the FP is returned as a static string.  If the FP is
   great and should be printed, NULL is returned. */
const char *FingerPrintResults::OmitSubmissionFP() {
  static char reason[128];

  if (o.scan_delay > 500) { // This can screw up the sequence timing
    Snprintf(reason, sizeof(reason), "Scan delay (%d) is greater than 500", o.scan_delay);
    return reason;
  }

  if (o.timing_level > 4)
    return "Timing level 5 (Insane) used";

  if (osscan_opentcpport <= 0)
    return "Missing an open TCP port so results incomplete";

  if (osscan_closedtcpport <= 0)
    return "Missing a closed TCP port so results incomplete";

  /* This can happen if the TTL in the response to the UDP probe is somehow
     greater than the TTL in the probe itself. We exclude -1 because that is
     used to mean the distance is unknown, though there's a chance it could
     have come from the distance calculation. */
  if (distance < -1) {
    Snprintf(reason, sizeof(reason), "Host distance (%d network hops) appears to be negative", distance);
    return reason;
  }

  if (distance > 5) {
    Snprintf(reason, sizeof(reason), "Host distance (%d network hops) is greater than five", distance);
    return reason;
  }

  if (maxTimingRatio > 1.4) {
    Snprintf(reason, sizeof(reason), "maxTimingRatio (%e) is greater than 1.4", maxTimingRatio);
    return reason;
  }

  if (osscan_closedudpport < 0 && !o.udpscan) {
    /* If we didn't get a U1 response, that might be just
       because we didn't search for an closed port rather than
       because this OS doesn't respond to that sort of probe.
       So we don't print FP if U1 response is lacking AND no UDP
       scan was performed. */
    return "Didn't receive UDP response. Please try again with -sSU";
  }

  return NULL;
}

/* IPv6 classification is more robust to errors than IPv4, so apply less
   stringent conditions than the general OmitSubmissionFP. */
const char *FingerPrintResultsIPv6::OmitSubmissionFP() {
  static char reason[128];

  if (o.scan_delay > 500) { // This can screw up the sequence timing
    Snprintf(reason, sizeof(reason), "Scan delay (%d) is greater than 500", o.scan_delay);
    return reason;
  }

  return NULL;
}


/* Goes through fingerprinting results to populate OSR */
void FingerPrintResults::populateClassification() {
  std::vector<OS_Classification>::iterator osclass;
  int printno;

  OSR.OSC_num_perfect_matches = OSR.OSC_num_matches = 0;
  OSR.overall_results = OSSCAN_SUCCESS;

  if (overall_results == OSSCAN_TOOMANYMATCHES) {
    // The normal classification overflowed so we don't even have all the perfect matches,
    // I don't see any good reason to do classification.
    OSR.overall_results = OSSCAN_TOOMANYMATCHES;
    return;
  }

  for(printno = 0; printno < num_matches; printno++) {
    // a single print may have multiple classifications
    for (osclass = matches[printno]->OS_class.begin();
         osclass != matches[printno]->OS_class.end();
         osclass++) {
      if (!classAlreadyExistsInResults(&*osclass)) {
	// Then we have to add it ... first ensure we have room
	if (OSR.OSC_num_matches == MAX_FP_RESULTS) {
	  // Out of space ... if the accuracy of this one is 100%, we have a problem
	  if (accuracy[printno] == 1.0) OSR.overall_results = OSSCAN_TOOMANYMATCHES;
	  return;
	}

	// We have space, but do we even want this one?  No point
	// including lesser matches if we have 1 or more perfect
	// matches.
	if (OSR.OSC_num_perfect_matches > 0 && accuracy[printno] < 1.0) {
	  return;
	}

	// OK, we will add the new class
       OSR.OSC[OSR.OSC_num_matches] = &*osclass;
	OSR.OSC_Accuracy[OSR.OSC_num_matches] = accuracy[printno];
	if (printno < num_perfect_matches) OSR.OSC_num_perfect_matches++;
	OSR.OSC_num_matches++;
      }
    }
  }

  if (OSR.OSC_num_matches == 0)
    OSR.overall_results = OSSCAN_NOMATCHES;

  return;
}

/* Return true iff s and t are both NULL or both the same string. */
static bool strnulleq(const char *s, const char *t) {
  if (s == NULL && t == NULL)
    return true;
  else if (s == NULL || t == NULL)
    return false;
  else
    return strcmp(s, t) == 0;
}

// Go through any previously enterted classes to see if this is a dupe;
bool FingerPrintResults::classAlreadyExistsInResults(struct OS_Classification *OSC) {
  int i;

  for (i=0; i < OSR.OSC_num_matches; i++) {
    if (strnulleq(OSC->OS_Vendor, OSR.OSC[i]->OS_Vendor) &&
        strnulleq(OSC->OS_Family, OSR.OSC[i]->OS_Family) &&
        strnulleq(OSC->Device_Type, OSR.OSC[i]->Device_Type) &&
        strnulleq(OSC->OS_Generation, OSR.OSC[i]->OS_Generation)) {
    // Found a duplicate!
    return true;
    }
  }

  // Went through all the results -- no duplicates found
  return false;
}

