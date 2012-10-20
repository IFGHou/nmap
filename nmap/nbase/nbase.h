
/***************************************************************************
 * nbase.h -- The main include file exposing the external API for          *
 * libnbase, a library of base (often compatability) routines.  Programs   *
 * using libnbase can guarantee the availability of functions like         *
 * (v)snprintf and inet_pton.  This library also provides consistency and  *
 * extended features for some functions.  It was originally written for    *
 * use in the Nmap Security Scanner ( http://nmap.org ).                   *
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

#ifndef NBASE_H
#define NBASE_H

/* NOTE -- libnbase offers the following features that you should probably
 * be aware of:
 *
 * * 'inline' is defined to what is neccessary for the C compiler being
 *   used (which may be nothing)
 *
 * * snprintf, inet_pton, memcpy, and bzero are 
 *   provided if you don't have them (prototypes for these are 
 *   included either way).
 *
 * * WORDS_BIGENDIAN is defined if platform is big endian
 *
 * * Definitions included which give the operating system type.  They
 *   will generally be one of the following: LINUX, FREEBSD, NETBSD,
 *   OPENBSD, SOLARIS, SUNOS, BSDI, IRIX, NETBSD
 *
 * * Insures that getopt_* functions exist (such as getopt_long_only)
 *
 * * Various string functions such as Strncpy() and strcasestr() see protos 
 *   for more info.
 *
 * * IPv6 structures like 'sockaddr_storage' are provided if they do
 *   not already exist.
 *
 * * Various Windows -> UNIX compatability definitions are added (such as defining EMSGSIZE to WSAEMSGSIZE)
 */

#if HAVE_CONFIG_H
#include "nbase_config.h"
#else
#ifdef WIN32
#include "nbase_winconfig.h"
#endif /* WIN32 */
#endif /* HAVE_CONFIG_H */

#ifdef WIN32
#include "nbase_winunix.h"
#endif

#if HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <stdlib.h>
#include <ctype.h>

#if HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#if HAVE_STRING_H
#include <string.h>
#endif

#if HAVE_NETDB_H
#include <netdb.h>  
#endif

#if HAVE_INTTYPES_H
#include <inttypes.h>
#endif

#include <stdio.h>

#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 64
#endif

#ifndef MAXPATHLEN
#define MAXPATHLEN 2048
#endif

#ifndef HAVE___ATTRIBUTE__
#define __attribute__(args)
#endif

#include <stdarg.h>

/* Keep assert() defined for security reasons */
#undef NDEBUG

/* Integer types */
typedef uint8_t u8;
typedef int8_t s8;
typedef uint16_t u16;
typedef int16_t s16;
typedef uint32_t u32;
typedef int32_t s32;
typedef uint64_t u64;
typedef int64_t s64;

/* Mathematicial MIN/MAX/ABS (absolute value) macros */
#ifndef MAX
#define MAX(x,y) (((x)>(y))?(x):(y))
#endif
#ifndef MIN
#define MIN(x,y) (((x)<(y))?(x):(y))
#endif
#ifndef ABS
#define ABS(x) (((x) >= 0)?(x):-(x)) 
#endif

/* Timeval subtraction in microseconds */
#define TIMEVAL_SUBTRACT(a,b) (((a).tv_sec - (b).tv_sec) * 1000000 + (a).tv_usec - (b).tv_usec)
/* Timeval subtract in milliseconds */
#define TIMEVAL_MSEC_SUBTRACT(a,b) ((((a).tv_sec - (b).tv_sec) * 1000) + ((a).tv_usec - (b).tv_usec) / 1000)
/* Timeval subtract in seconds; truncate towards zero */
#define TIMEVAL_SEC_SUBTRACT(a,b) ((a).tv_sec - (b).tv_sec + (((a).tv_usec < (b).tv_usec) ? - 1 : 0))
/* Timeval subtract in fractional seconds; convert to float */
#define TIMEVAL_FSEC_SUBTRACT(a,b) ((a).tv_sec - (b).tv_sec + (((a).tv_usec - (b).tv_usec)/1000000.0))

/* assign one timeval to another timeval plus some msecs: a = b + msecs */
#define TIMEVAL_MSEC_ADD(a, b, msecs) { (a).tv_sec = (b).tv_sec + ((msecs) / 1000); (a).tv_usec = (b).tv_usec + ((msecs) % 1000) * 1000; (a).tv_sec += (a).tv_usec / 1000000; (a).tv_usec %= 1000000; }
#define TIMEVAL_ADD(a, b, usecs) { (a).tv_sec = (b).tv_sec + ((usecs) / 1000000); (a).tv_usec = (b).tv_usec + ((usecs) % 1000000); (a).tv_sec += (a).tv_usec / 1000000; (a).tv_usec %= 1000000; }

/* Find our if one timeval is before or after another, avoiding the integer
   overflow that can result when doing a TIMEVAL_SUBTRACT on two widely spaced
   timevals. */
#define TIMEVAL_BEFORE(a, b) (((a).tv_sec < (b).tv_sec) || ((a).tv_sec == (b).tv_sec && (a).tv_usec < (b).tv_usec))
#define TIMEVAL_AFTER(a, b) (((a).tv_sec > (b).tv_sec) || ((a).tv_sec == (b).tv_sec && (a).tv_usec > (b).tv_usec))

/* Convert a timeval to floating point seconds */
#define TIMEVAL_SECS(a) ((double) (a).tv_sec + (double) (a).tv_usec / 1000000)


/* sprintf family */
#if !defined(HAVE_SNPRINTF) && defined(__cplusplus)
extern "C" int snprintf (char *str, size_t sz, const char *format, ...)
     __attribute__ ((format (printf, 3, 4)));
#endif

#if !defined(HAVE_VSNPRINTF) && defined(__cplusplus)
extern "C" int vsnprintf (char *str, size_t sz, const char *format,
     va_list ap)
     __attribute__((format (printf, 3, 0)));
#endif

#if !defined(HAVE_ASPRINTF) && defined(__cplusplus)
extern "C" int asprintf (char **ret, const char *format, ...)
     __attribute__ ((format (printf, 2, 3)));
#endif

#if !defined(HAVE_VASPRINTF) && defined(__cplusplus)
extern "C" int vasprintf (char **ret, const char *format, va_list ap)
     __attribute__((format (printf, 2, 0)));
#endif

#if !defined(HAVE_ASNPRINTF) && defined(__cplusplus)
extern "C" int asnprintf (char **ret, size_t max_sz, const char *format, ...)
     __attribute__ ((format (printf, 3, 4)));
#endif

#if !defined(HAVE_VASNPRINTF) && defined(__cplusplus)
extern "C" int vasnprintf (char **ret, size_t max_sz, const char *format,
     va_list ap)
     __attribute__((format (printf, 3, 0)));
#endif

#if defined(NEED_SNPRINTF_PROTO) && defined(__cplusplus)
extern "C" int snprintf (char *, size_t, const char *, ...);
#endif

#if defined(NEED_VSNPRINTF_PROTO) && defined(__cplusplus)
extern "C" int vsnprintf (char *, size_t, const char *, va_list);
#endif

#ifdef HAVE_GETOPT_H
#include <getopt.h>
#else
#ifndef HAVE_GETOPT_LONG_ONLY
#include "getopt.h"
#endif
#endif /* HAVE_GETOPT_H */

/* More Windows-specific stuff */
#ifdef WIN32

#define WIN32_LEAN_AND_MEAN /* Whatever this means! From winclude.h*/

/* Apparently Windows doesn't have S_ISDIR */
#ifndef S_ISDIR
#define S_ISDIR(m)      (((m) & _S_IFMT) == _S_IFDIR)
#endif

/* Windows doesn't have the access() defines */
#ifndef F_OK
#define F_OK 00
#endif
#ifndef W_OK
#define W_OK 02
#endif
#ifndef R_OK
#define R_OK 04
#endif

/* wtf was ms thinking? */
#define access _access
#define stat _stat
#define execve _execve
#define getpid _getpid
#define dup _dup
#define dup2 _dup2
#define strdup _strdup
#define write _write
#define open _open
#define stricmp _stricmp
#define putenv _putenv

#if !defined(__GNUC__)
#define snprintf _snprintf
#endif

#define strcasecmp _stricmp
#define strncasecmp _strnicmp
#define execv _execv

#endif /* WIN32 */

/* Apparently Windows doesn't like /dev/null */
#ifdef WIN32
#define DEVNULL "NUL"
#else
#define DEVNULL "/dev/null"
#endif



#ifdef __cplusplus
extern "C" {
#endif

  /* Returns the UNIX/Windows errno-equivalent.  Note that the Windows
     call is socket/networking specific.  Also, WINDOWS TENDS TO RESET
     THE ERROR, so it will return success the next time.  So SAVE THE
     RESULTS and re-use them, don't keep calling socket_errno().  The
     windows error number returned is like WSAMSGSIZE, but nbase.h
     includes #defines to correlate many of the common UNIX errors
     with their closest Windows equivalents.  So you can use EMSGSIZE
     or EINTR. */
int socket_errno();

/* We can't just use strerror to get socket errors on Windows because it has
   its own set of error codes: WSACONNRESET not ECONNRESET for example. This
   function will do the right thing on Windows. Call it like
     socket_strerror(socket_errno())
*/
char *socket_strerror(int errnum);

/* The usleep() function is important as well */
#ifndef HAVE_USLEEP
#if defined( HAVE_NANOSLEEP) || defined(WIN32)
void usleep(unsigned long usec);
#endif
#endif

/***************** String functions -- See nbase_str.c ******************/
/* I modified this conditional because !@# Redhat does not easily provide
   the prototype even though the function exists */
#if !defined(HAVE_STRCASESTR) || (defined(LINUX) && !defined(__USE_GNU) && !defined(_GNU_SOURCE))
/* strcasestr is like strstr() except case insensitive */
char *strcasestr(const char *haystack, const char *pneedle);
#endif

#ifndef HAVE_STRCASECMP
int strcasecmp(const char *s1, const char *s2);
#endif

#ifndef HAVE_STRNCASECMP
int strncasecmp(const char *s1, const char *s2, size_t n);
#endif

#ifndef HAVE_GETTIMEOFDAY
int gettimeofday(struct timeval *tv, struct timeval *tz);
#endif

#ifndef HAVE_SLEEP
unsigned int sleep(unsigned int seconds);
#endif

/* Strncpy is like strcpy() except it ALWAYS zero-terminates, even if
   it must truncate */
int Strncpy(char *dest, const char *src, size_t n);

int Vsnprintf(char *, size_t, const char *, va_list)
     __attribute__ ((format (printf, 3, 0)));
int Snprintf(char *, size_t, const char *, ...)
     __attribute__ ((format (printf, 3, 4)));

int alloc_vsprintf(char **strp, const char *fmt, va_list va)
     __attribute__ ((format (printf, 2, 0)));

/* Trivial function that returns nonzero if all characters in str of
   length strlength are printable (as defined by isprint()) */
int stringisprintable(const char *str, int strlength);

/* parse_long is like strtol or atoi, but it allows digits only.
   No whitespace, sign, or radix prefix. */
long parse_long(const char *s, char **tail);

/* This function takes a byte count and stores a short ascii equivalent
   in the supplied buffer. Eg: 0.122MB, 10.322Kb or 128B. */
char *format_bytecount(unsigned long long bytes, char *buf, size_t buflen);

/* Compare a canonical option name (e.g. "max-scan-delay") with a
   user-generated option such as "max_scan_delay" and returns 0 if the
   two values are considered equivalant (for example, - and _ are
   considered to be the same), nonzero otherwise. */
int optcmp(const char *a, const char *b);

/* Convert non-printable characters to replchar in the string */
void replacenonprintable(char *str, int strlength, char replchar);

/* Returns one if the file pathname given exists, is not a directory and
 * is readable by the executing process.  Returns two if it is readable
 * and is a directory.  Otherwise returns 0. */
int file_is_readable(const char *pathname);

/* Portable, incompatible replacements for dirname and basename. */
char *path_get_dirname(const char *path);
char *path_get_basename(const char *path);

/* A few simple wrappers for the most common memory allocation routines which will exit() if the
	allocation fails, so you don't always have to check -- see nbase_memalloc.c */
void *safe_malloc(size_t size);
void *safe_realloc(void *ptr, size_t size);
/* Zero-initializing version of safe_malloc */
void *safe_zalloc(size_t size);

  /* Some routines for obtaining simple (not secure on systems that
     lack /dev/random and friends' "random" numbers */
int get_random_bytes(void *buf, int numbytes);
int get_random_int();
unsigned short get_random_ushort();
unsigned int get_random_uint();
u32 get_random_u32();
u16 get_random_u16();
u8 get_random_u8();
u32 get_random_unique_u32();

/* Create a new socket inheritable by subprocesses. On non-Windows systems it's
   just a normal socket. */
int inheritable_socket(int af, int style, int protocol);
/* The dup function on Windows works only on file descriptors, not socket
   handles. This function accomplishes the same thing for sockets. */
int dup_socket(int sd);
int unblock_socket(int sd);
int block_socket(int sd);
int socket_bindtodevice(int sd, const char *device);

/* CRC32 Cyclic Redundancy Check */
unsigned long nbase_crc32(unsigned char *buf, int len);
/* CRC32C Cyclic Redundancy Check (Castagnoli) */
unsigned long nbase_crc32c(unsigned char *buf, int len);
/* Adler32 Checksum */
unsigned long nbase_adler32(unsigned char *buf, int len);

double tval2secs(const char *tspec);
long tval2msecs(const char *tspec);
const char *tval_unit(const char *tspec);

int fselect(int s, fd_set *rmaster, fd_set *wmaster, fd_set *emaster, struct timeval *tv);

char *hexdump(const u8 *cp, u32 length);

char *executable_path(const char *argv0);

/* addrset management functions and definitions */
/* A set of addresses. Used to match against allow/deny lists. */
struct addrset_elem;

/* A set of addresses. Used to match against allow/deny lists. */
struct addrset {
    /* Linked list of struct addset_elem. */
    struct addrset_elem *head;
};

void nbase_set_log(void (*log_user_func)(const char *, ...),void (*log_debug_func)(const char *, ...));
extern void addrset_init(struct addrset *set);
extern void addrset_free(struct addrset *set);
extern void addrset_elem_print(FILE *fp, const struct addrset_elem *elem);
extern int addrset_add_spec(struct addrset *set, const char *spec, int af, int dns);
extern int addrset_add_file(struct addrset *set, FILE *fd, int af, int dns);
extern int addrset_contains(const struct addrset *set, const struct sockaddr *sa);

#ifndef STDIN_FILENO
#define STDIN_FILENO 0
#endif

#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif

#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

#include "nbase_ipv6.h"

#ifdef __cplusplus
}
#endif

#endif /* NBASE_H */
