/***************************************************************************
 * ncat_listen.c -- --listen mode.                                         *
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
 * works of Nmap.  This list is not exclusive, but is meant to clarify our *
 * interpretation of derived works with some common examples.  Our         *
 * interpretation applies only to Nmap--we don't speak for other people's  *
 * GPL works.                                                              *
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
 * Insecure.Org development mailing lists, it is assumed that you are      *
 * offering the Nmap Project (Insecure.Com LLC) the unlimited,             *
 * non-exclusive right to reuse, modify, and relicense the code.  Nmap     *
 * will always be available Open Source, but this is important because the *
 * inability to relicense code has caused devastating problems for other   *
 * Free Software projects (such as KDE and NASM).  We also occasionally    *
 * relicense the code to third parties as discussed above.  If you wish to *
 * specify special license conditions of your contributions, just say so   *
 * when you send them.                                                     *
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

#include "ncat.h"

#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <limits.h>
#ifndef WIN32
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#else
#include <fcntl.h>
#endif

#ifdef HAVE_OPENSSL
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif

/* read_fds is the clients we are accepting data from. broadcast_fds is the
   clients were are sending data to. broadcast_fds doesn't include the listening
   socket and stdin. Network clients are not added to read_fds when --send-only
   is used, because they would be always selected without having data read.
   write_fds is the list of clients that are waiting for some kind of response
   from us, like a pending ssl negotiation. */
static fd_set master_readfds, master_writefds, master_broadcastfds;
#ifdef HAVE_OPENSSL
/* sslpending_fds containts the list of ssl sockets that are waiting to complete
   the ssl handshake */
static fd_set sslpending_fds;
#endif

/* These are bookkeeping data structures that are parallel to read_fds and
   broadcast_fds. */
static fd_list_t client_fdlist, broadcast_fdlist;

static int listen_socket[NUM_LISTEN_ADDRS];
/* Has stdin seen EOF? */
static int stdin_eof = 0;
static int crlf_state = 0;

static void handle_connection(int socket_accept);
static int read_stdin(void);
static int read_socket(int recv_fd);
static void post_handle_connection(struct fdinfo sinfo);
static void read_and_broadcast(int recv_socket);
static int chat_announce_connect(int fd, const union sockaddr_u *su);
static int chat_announce_disconnect(int fd);
static char *chat_filter(char *buf, size_t size, int fd, int *nwritten);

/* The number of connected clients is the difference of conn_inc and conn_dec.
   It is split up into two variables for signal safety. conn_dec is modified
   (asynchronously) only in signal handlers and conn_inc is modified
   (synchronously) only in the main program. get_conn_count loops while conn_dec
   is being modified. */
static unsigned int conn_inc = 0;
static volatile unsigned int conn_dec = 0;
static volatile sig_atomic_t conn_dec_changed;

static void decrease_conn_count(void) {
    conn_dec_changed = 1;
    conn_dec++;
}

static int get_conn_count(void)
{
    unsigned int count;

    /* conn_dec is modified in a signal handler, so loop until it stops
       changing. */
    do {
        conn_dec_changed = 0;
        count = conn_inc - conn_dec;
    } while (conn_dec_changed);
    assert(count <= INT_MAX);

    return count;
}

#ifndef WIN32
static void sigchld_handler(int signum)
{
    while (waitpid(-1, NULL, WNOHANG) > 0)
        decrease_conn_count();
}
#endif

static int ncat_listen_stream(int proto)
{
    int rc, i, fds_ready;
    fd_set listen_fds;

    /* clear out structs */
    FD_ZERO(&master_readfds);
    FD_ZERO(&master_writefds);
    FD_ZERO(&master_broadcastfds);
    FD_ZERO(&listen_fds);
#ifdef HAVE_OPENSSL
    FD_ZERO(&sslpending_fds);
#endif
    zmem(&client_fdlist, sizeof(client_fdlist));
    zmem(&broadcast_fdlist, sizeof(broadcast_fdlist));

#ifdef WIN32
    set_pseudo_sigchld_handler(decrease_conn_count);
#else
    /* Reap on SIGCHLD */
    Signal(SIGCHLD, sigchld_handler);
    /* Ignore the SIGPIPE that occurs when a client disconnects suddenly and we
       send data to it before noticing. */
    Signal(SIGPIPE, SIG_IGN);
#endif

#ifdef HAVE_OPENSSL
    if (o.ssl)
        setup_ssl_listen();
#endif

    /* We need a list of fds to keep current fdmax. The second parameter is a
       number added to the supplied connection limit, that will compensate
       maxfds for the added by default listen and stdin sockets. */
    init_fdlist(&client_fdlist, sadd(o.conn_limit, num_listenaddrs + 1));

    for (i = 0; i < NUM_LISTEN_ADDRS; i++)
        listen_socket[i] = -1;

    for (i = 0; i < num_listenaddrs; i++) {
        /* setup the main listening socket */
        listen_socket[i] = do_listen(SOCK_STREAM, proto, &listenaddrs[i]);

        /* Make our listening socket non-blocking because there are timing issues
         * which could cause us to block on accept() even though select() says it's
         * readable.  See UNPv1 2nd ed, p422 for more.
         */
        unblock_socket(listen_socket[i]);

        /* setup select sets and max fd */
        FD_SET(listen_socket[i], &master_readfds);
        add_fd(&client_fdlist, listen_socket[i]);

        FD_SET(listen_socket[i], &listen_fds);
    }
    add_fd(&client_fdlist, STDIN_FILENO);

    init_fdlist(&broadcast_fdlist, o.conn_limit);

    while (1) {
        /* We pass these temporary descriptor sets to fselect, since fselect
           modifies the sets it receives. */
        fd_set readfds = master_readfds, writefds = master_writefds;
        struct fdinfo *fdi = NULL;

        if (o.debug > 1)
            logdebug("selecting, fdmax %d\n", client_fdlist.fdmax);

        if (o.debug > 1 && o.broker)
            logdebug("Broker connection count is %d\n", get_conn_count());

        fds_ready = fselect(client_fdlist.fdmax + 1, &readfds, &writefds, NULL, NULL);

        if (o.debug > 1)
            logdebug("select returned %d fds ready\n", fds_ready);

        /*
         * FIXME: optimize this loop to look only at the fds in the fd list,
         * doing it this way means that if you have one descriptor that is very
         * large, say 500, and none close to it, that you'll loop many times for
         * nothing.
         */
        for (i = 0; i <= client_fdlist.fdmax && fds_ready > 0; i++) {
            /* Loop through descriptors until there's something to read */
            if (!FD_ISSET(i, &readfds) && !FD_ISSET(i, &writefds))
                continue;

            if (o.debug > 1)
                logdebug("fd %d is ready\n", i);

#ifdef HAVE_OPENSSL
            /* Is this an ssl socket pending a handshake? If so handle it. */
            if (o.ssl && FD_ISSET(i, &sslpending_fds)) {
                FD_CLR(i, &master_readfds);
                FD_CLR(i, &master_writefds);
                fdi = get_fdinfo(&client_fdlist, i);
                switch(ssl_handshake(fdi)){
                case NCAT_SSL_HANDSHAKE_COMPLETED:
                    /* Clear from sslpending_fds once ssl is established */
                    FD_CLR(i, &sslpending_fds);
                    rm_fd(&client_fdlist, i);
                    post_handle_connection(*fdi);
                    break;
                case NCAT_SSL_HANDSHAKE_PENDING_WRITE:
                    FD_SET(i, &master_writefds);
                    break;
                case NCAT_SSL_HANDSHAKE_PENDING_READ:
                    FD_SET(i, &master_readfds);
                    break;
                case NCAT_SSL_HANDSHAKE_FAILED:
                default:
                    SSL_free(fdi->ssl);
                    Close(fdi->fd);
                    FD_CLR(i, &sslpending_fds);
                    FD_CLR(i, &master_readfds);
                    rm_fd(&client_fdlist, i);
                    /* Are we in single listening mode(without -k)? If so
                       then we should quit also. */
                    if (!o.keepopen && !o.broker)
                        return 1;
                    --conn_inc;
                    break;
                }
            } else
#endif
            if (FD_ISSET(i, &listen_fds)) {
                /* we have a new connection request */
                handle_connection(i);
            } else if (i == STDIN_FILENO) {
                if(o.broker) {
                    read_and_broadcast(i);
                }else {
                    /* Read from stdin and write to all clients. */
                    rc = read_stdin();
                    if (rc == 0 && o.sendonly)
                        /* There will be nothing more to send. If we're not
                           receiving anything, we can quit here. */
                        return 0;
                    if (rc < 0)
                        return 1;
                }
            } else if (!o.sendonly) {
                if(o.broker) {
                    read_and_broadcast(i);
                }else {
                    /* Read from a client and write to stdout. */
                    rc = read_socket(i);
                    if (rc <= 0 && !o.keepopen)
                        return rc == 0 ? 0 : 1;
                }
            }

            fds_ready--;
        }
    }

    return 0;
}

/* Accept a connection on a listening socket. Allow or deny the connection.
   Fork a command if o.cmdexec is set. Otherwise, add the new socket to the
   watch set. */
static void handle_connection(int socket_accept)
{
    union sockaddr_u remoteaddr;
    socklen_t ss_len;
    struct fdinfo s = { 0 };
    int conn_count;

    zmem(&s, sizeof(s));

    ss_len = sizeof(remoteaddr.storage);
    errno = 0;
    s.fd = accept(socket_accept, &remoteaddr.sockaddr, &ss_len);

    if (s.fd < 0) {
        if (o.debug)
            logdebug("Error in accept: %s\n", strerror(errno));

        close(s.fd);
        return;
    }

    if (o.verbose) {
        if (o.chat)
            loguser("Connection from %s on file descriptor %d.\n", inet_socktop(&remoteaddr), s.fd);
        else
            loguser("Connection from %s.\n", inet_socktop(&remoteaddr));
    }

    if (!o.keepopen && !o.broker)  {
        int i;
        for (i = 0; i < num_listenaddrs; i++) {
            Close(listen_socket[i]);
            FD_CLR(listen_socket[i], &master_readfds);
            rm_fd(&client_fdlist, listen_socket[i]);
        }
    }

    if (o.verbose)
        loguser("Connection from %s:%hu.\n", inet_socktop(&remoteaddr), inet_port(&remoteaddr));

    /* Check conditions that might cause us to deny the connection. */
    conn_count = get_conn_count();
    if (conn_count >= o.conn_limit) {
        if (o.verbose)
            loguser("New connection denied: connection limit reached (%d)\n", conn_count);
        Close(s.fd);
        return;
    }
    if (!allow_access(&remoteaddr)) {
        if (o.verbose)
            loguser("New connection denied: not allowed\n");
        Close(s.fd);
        return;
    }

    s.remoteaddr = remoteaddr;

    conn_inc++;

    unblock_socket(s.fd);

 #ifdef HAVE_OPENSSL
    if (o.ssl) {
        /* Add the socket to the necessary descriptor lists. */
        FD_SET(s.fd, &sslpending_fds);
        FD_SET(s.fd, &master_readfds);
        FD_SET(s.fd, &master_writefds);
        /* Add it to our list of fds too for maintaining maxfd. */
        if (add_fdinfo(&client_fdlist, &s) < 0)
            bye("add_fdinfo() failed.");
    } else
 #endif
        post_handle_connection(s);
}

/* This function handles the post connection specific actions that are needed
 * after a socket has been initialized(normal socket or ssl socket). */
static void post_handle_connection(struct fdinfo sinfo)
{
    /*
     * Are we executing a command? If so then don't add this guy
     * to our descriptor list or set.
     */
    if (o.cmdexec) {
        if (o.keepopen)
            netrun(&sinfo, o.cmdexec);
        else
            netexec(&sinfo, o.cmdexec);
    } else {
        /* Now that a client is connected, pay attention to stdin. */
        if (!stdin_eof)
            FD_SET(STDIN_FILENO, &master_readfds);
        if (!o.sendonly) {
            /* add to our lists */
            FD_SET(sinfo.fd, &master_readfds);
            /* add it to our list of fds for maintaining maxfd */
            if (add_fdinfo(&client_fdlist, &sinfo) < 0)
                 bye("add_fdinfo() failed.");
        }
        FD_SET(sinfo.fd, &master_broadcastfds);
        if (add_fdinfo(&broadcast_fdlist, &sinfo) < 0)
             bye("add_fdinfo() failed.");

        if (o.chat)
            chat_announce_connect(sinfo.fd, &sinfo.remoteaddr);
    }
}

/* Read from stdin and broadcast to all client sockets. Return the number of
   bytes read, or -1 on error. */
int read_stdin(void)
{
    int nbytes;
    char buf[DEFAULT_TCP_BUF_LEN];
    char *tempbuf = NULL;

    nbytes = read(STDIN_FILENO, buf, sizeof(buf));
    if (nbytes <= 0) {
        if (nbytes < 0 && o.verbose)
            logdebug("Error reading from stdin: %s\n", strerror(errno));
        if (nbytes == 0 && o.debug)
            logdebug("EOF on stdin\n");

        /* Don't close the file because that allows a socket to be fd 0. */
        FD_CLR(STDIN_FILENO, &master_readfds);
        /* Buf mark that we've seen EOF so it doesn't get re-added to the
           select list. */
        stdin_eof = 1;

        return nbytes;
    }

    if (o.crlf)
        fix_line_endings((char *) buf, &nbytes, &tempbuf, &crlf_state);

    if (o.linedelay)
        ncat_delay_timer(o.linedelay);

    /* Write to everything in the broadcast set. */
    if (tempbuf != NULL) {
        ncat_broadcast(&master_broadcastfds, &broadcast_fdlist, tempbuf, nbytes);
        free(tempbuf);
        tempbuf = NULL;
    } else {
        ncat_broadcast(&master_broadcastfds, &broadcast_fdlist, buf, nbytes);
    }

    return nbytes;
}

/* Read from a client socket and write to stdout. Return the number of bytes
   read from the socket, or -1 on error. */
int read_socket(int recv_fd)
{
    char buf[DEFAULT_TCP_BUF_LEN];
    struct fdinfo *fdn;
    int nbytes, pending;

    fdn = get_fdinfo(&client_fdlist, recv_fd);
    assert(fdn != NULL);

    nbytes = 0;
    do {
        int n;

        n = ncat_recv(fdn, buf, sizeof(buf), &pending);
        if (n <= 0) {
            if (o.debug)
                logdebug("Closing connection.\n");
#ifdef HAVE_OPENSSL
            if (o.ssl && fdn->ssl) {
                if (nbytes == 0)
                    SSL_shutdown(fdn->ssl);
                SSL_free(fdn->ssl);
            }
#endif
            close(recv_fd);
            FD_CLR(recv_fd, &master_readfds);
            rm_fd(&client_fdlist, recv_fd);
            FD_CLR(recv_fd, &master_broadcastfds);
            rm_fd(&broadcast_fdlist, recv_fd);

            conn_inc--;
            if (get_conn_count() == 0)
                FD_CLR(STDIN_FILENO, &master_readfds);

            return n;
        }

        Write(STDOUT_FILENO, buf, n);
        nbytes += n;
    } while (pending);

    return nbytes;
}

/* This is sufficiently different from the TCP code (wrt SSL, etc) that it
 * resides in its own simpler function
 */
static int ncat_listen_dgram(int proto)
{
    int sockfd[NUM_LISTEN_ADDRS];
    int i, fdn = -1;
    int fdmax, nbytes, fds_ready;
    char buf[DEFAULT_UDP_BUF_LEN] = {0};
    char *tempbuf = NULL;
    fd_set read_fds;
    union sockaddr_u remotess;
    socklen_t sslen = sizeof(remotess.storage);

    for (i = 0; i < NUM_LISTEN_ADDRS; i++) {
        sockfd[i] = -1;
    }

    FD_ZERO(&read_fds);

    /* Initialize remotess struct so recvfrom() doesn't hit the fan.. */
    zmem(&remotess.storage, sizeof(remotess.storage));
    remotess.storage.ss_family = o.af;

#ifdef WIN32
    set_pseudo_sigchld_handler(decrease_conn_count);
#else
    /* Reap on SIGCHLD */
    Signal(SIGCHLD, sigchld_handler);
    /* Ignore the SIGPIPE that occurs when a client disconnects suddenly and we
       send data to it before noticing. */
    Signal(SIGPIPE, SIG_IGN);
#endif

    /* set for selecting udp listening sockets */
    fd_set listen_fds;
    fd_list_t listen_fdlist;
    FD_ZERO(&listen_fds);
    init_fdlist(&listen_fdlist, num_listenaddrs);

    for (i = 0; i < num_listenaddrs; i++) {
        /* create the UDP listen sockets */
        sockfd[i] = do_listen(SOCK_DGRAM, proto, &listenaddrs[i]);
        FD_SET(sockfd[i],&listen_fds);
        add_fd(&listen_fdlist, sockfd[i]);
    }

    while (1) {
        int i, j, conn_count, socket_n;

        if (fdn != -1) {
            /*remove socket descriptor which is burnt */
            FD_CLR(sockfd[fdn], &listen_fds);
            rm_fd(&listen_fdlist, sockfd[fdn]);

            /* Rebuild the udp socket which got burnt */
            sockfd[fdn] = do_listen(SOCK_DGRAM, proto, &listenaddrs[fdn]);
            FD_SET(sockfd[fdn],&listen_fds);
            add_fd(&listen_fdlist, sockfd[fdn]);

        }
        fdn = -1;
        socket_n = -1;
            fd_set fds;
            FD_ZERO(&fds);
        while (1) {
            /*
             * We just select to get a list of sockets which we can talk to
             */
            if (o.debug > 1)
                logdebug("selecting, fdmax %d\n", listen_fdlist.fdmax);
            fds = listen_fds;
            fds_ready = fselect(listen_fdlist.fdmax + 1, &fds, NULL, NULL, NULL);

            if (o.debug > 1)
                logdebug("select returned %d fds ready\n", fds_ready);


            /*
             * Figure out which listening socket got a connection. This loop should
             * really call a function for each ready socket instead of breaking on
             * the first one.
             */
            for (i = 0; i <= listen_fdlist.fdmax && fds_ready >0; i++) {
                /* Loop through descriptors until there is something ready */
                if (!FD_ISSET(i, &fds))
                    continue;

                /* Check each listening socket */
                for (j = 0; j < num_listenaddrs; j++) {
                    if (i == sockfd[j]) {
                        if (o.debug >1)
                            logdebug("Valid descriptor %d \n", i);
                        fdn = j;
                        socket_n = i;
                        break;
                    }
                }

                /* if we found a valid socket break */
                if (fdn != -1) {
                    fds_ready--;
                    break;
                }
            }

            /* Make sure someone connected */
            if (fdn == -1)
                continue;

            /*
             * We just peek so we can get the client connection details without
             * removing anything from the queue. Sigh.
             */
            nbytes = Recvfrom(socket_n, buf, sizeof(buf), MSG_PEEK,
                              &remotess.sockaddr, &sslen);

            /* Check conditions that might cause us to deny the connection. */
            conn_count = get_conn_count();
            if (conn_count >= o.conn_limit) {
                if (o.verbose)
                    loguser("New connection denied: connection limit reached (%d)\n", conn_count);
            } else if (!allow_access(&remotess)) {
                if (o.verbose)
                    loguser("New connection denied: not allowed\n");
            } else {
                /* Good to go. */
                break;
            }

            /* Dump the current datagram */
            Recv(socket_n, buf, sizeof(buf), 0);
        }

        if (o.debug > 1)
            logdebug("Valid Connection from %d\n", socket_n);

        conn_inc++;

        /*
         * We're using connected udp. This has the down side of only
         * being able to handle one udp client at a time
         */
        Connect(socket_n, &remotess.sockaddr, sslen);

        /* clean slate for buf */
        zmem(buf, sizeof(buf));

        /* are we executing a command? then do it */
        if (o.cmdexec) {
            struct fdinfo info = { 0 };

            info.fd = socket_n;
            if (o.keepopen)
                netrun(&info, o.cmdexec);
            else
                netexec(&info, o.cmdexec);
            continue;
        }

        FD_SET(socket_n, &read_fds);
        FD_SET(STDIN_FILENO, &read_fds);
        fdmax = socket_n;

        /* stdin -> socket and socket -> stdout */
        while (1) {
            fd_set fds;

            fds = read_fds;

            if (o.debug > 1)
                logdebug("udp select'ing\n");

            fds_ready = fselect(fdmax + 1, &fds, NULL, NULL, NULL);

            if (FD_ISSET(STDIN_FILENO, &fds)) {
                nbytes = Read(STDIN_FILENO, buf, sizeof(buf));
                if (nbytes < 0) {
                    loguser("%s.\n", strerror(errno));
                    return 1;
                } else if (nbytes == 0) {
                    return 0;
                }
                if (o.crlf)
                    fix_line_endings((char *) buf, &nbytes, &tempbuf, &crlf_state);
                if (!o.recvonly) {
                    if (tempbuf != NULL)
                        send(socket_n, tempbuf, nbytes, 0);
                    else
                        send(socket_n, buf, nbytes, 0);
                }
                if (tempbuf != NULL) {
                    free(tempbuf);
                    tempbuf = NULL;
                }
            }
            if (FD_ISSET(socket_n, &fds)) {
                nbytes = recv(socket_n, buf, sizeof(buf), 0);
                if (nbytes < 0) {
                    loguser("%s.\n", socket_strerror(socket_errno()));
                    close(socket_n);
                    return 1;
                }
                if (!o.sendonly)
                    Write(STDOUT_FILENO, buf, nbytes);
            }

            zmem(buf, sizeof(buf));
        }
    }

    return 0;
}

int ncat_listen()
{
    if (o.httpserver)
        return ncat_http_server();
    else if (o.udp)
        return ncat_listen_dgram(IPPROTO_UDP);
    else if (o.sctp)
        return ncat_listen_stream(IPPROTO_SCTP);
    else
        return ncat_listen_stream(IPPROTO_TCP);

    /* unreached */
    return 1;
}

//---------------
/* Read from recv_fd and broadcast whatever is read to all other descriptors in
   read_fds, with the exception of stdin, listen_socket, and recv_fd itself.
   Handles EOL translation and chat mode. On read error or end of stream,
   closes the socket and removes it from the read_fds list. */
static void read_and_broadcast(int recv_fd)
{
    struct fdinfo *fdn;
    int pending;

    fdn = get_fdinfo(&client_fdlist, recv_fd);
    assert(fdn);

    /* Loop while ncat_recv indicates data is pending. */
    do {
        char buf[DEFAULT_TCP_BUF_LEN];
        char *chatbuf, *outbuf;
        char *tempbuf = NULL;
        fd_set broadcastfds;
        int n;

        /* Behavior differs depending on whether this is stdin or a socket. */
        if (recv_fd == STDIN_FILENO) {
            n = read(recv_fd, buf, sizeof(buf));
            if (n <= 0) {
                if (n < 0 && o.verbose)
                    logdebug("Error reading from stdin: %s\n", strerror(errno));
                if (n == 0 && o.debug)
                    logdebug("EOF on stdin\n");

                /* Don't close the file because that allows a socket to be
                   fd 0. */
                FD_CLR(recv_fd, &master_readfds);
                /* But mark that we've seen EOF so it doesn't get re-added to
                   the select list. */
                stdin_eof = 1;

                return;
            }

            if (o.crlf)
                fix_line_endings((char *) buf, &n, &tempbuf, &crlf_state);

            pending = 0;
        } else {
            /* From a connected socket, not stdin. */
            n = ncat_recv(fdn, buf, sizeof(buf), &pending);

            if (n <= 0) {
                if (o.debug)
                    logdebug("Closing connection.\n");
#ifdef HAVE_OPENSSL
                if (o.ssl && fdn->ssl) {
                    if (n == 0)
                        SSL_shutdown(fdn->ssl);
                    SSL_free(fdn->ssl);
                }
#endif
                close(recv_fd);
                FD_CLR(recv_fd, &master_readfds);
                rm_fd(&client_fdlist, recv_fd);
                FD_CLR(recv_fd, &master_broadcastfds);
                rm_fd(&broadcast_fdlist, recv_fd);

                conn_inc--;
                if (conn_inc == 0)
                    FD_CLR(STDIN_FILENO, &master_readfds);

                if (o.chat)
                    chat_announce_disconnect(recv_fd);

                return;
            }
        }

        if (o.debug > 1)
            logdebug("Handling data from client %d.\n", recv_fd);

        chatbuf = NULL;
        /* tempbuf is in use if we read from STDIN and fixed EOL */
        if (tempbuf == NULL)
            outbuf = buf;
        else
            outbuf = tempbuf;

        if (o.chat) {
            chatbuf = chat_filter(outbuf, n, recv_fd, &n);
            if (chatbuf == NULL) {
                if (o.verbose)
                    logdebug("Error formatting chat message from fd %d\n", recv_fd);
            } else {
                outbuf = chatbuf;
            }
        }

        /* Send to everyone except the one who sent this message. */
        broadcastfds = master_broadcastfds;
        FD_CLR(recv_fd, &broadcastfds);
        ncat_broadcast(&broadcastfds, &broadcast_fdlist, outbuf, n);

        free(chatbuf);
        free(tempbuf);
        tempbuf = NULL;
    } while (pending);
}

/* Announce the new connection and who is already connected. */
static int chat_announce_connect(int fd, const union sockaddr_u *su)
{
    char *buf = NULL;
    size_t size = 0, offset = 0;
    int i, count, ret;

    strbuf_sprintf(&buf, &size, &offset,
        "<announce> %s is connected as <user%d>.\n", inet_socktop(su), fd);

    strbuf_sprintf(&buf, &size, &offset, "<announce> already connected: ");
    count = 0;
    for (i = 0; i < client_fdlist.fdmax; i++) {
        union sockaddr_u su;
        socklen_t len = sizeof(su.storage);

        if (i == fd || !FD_ISSET(i, &master_broadcastfds))
            continue;

        if (getpeername(i, &su.sockaddr, &len) == -1)
            bye("getpeername for sd %d failed: %s.", strerror(errno));

        if (count > 0)
            strbuf_sprintf(&buf, &size, &offset, ", ");

        strbuf_sprintf(&buf, &size, &offset, "%s as <user%d>", inet_socktop(&su), i);

        count++;
    }
    if (count == 0)
        strbuf_sprintf(&buf, &size, &offset, "nobody");
    strbuf_sprintf(&buf, &size, &offset, ".\n");

    ret = ncat_broadcast(&master_broadcastfds, &broadcast_fdlist, buf, offset);

    free(buf);

    return ret;
}

static int chat_announce_disconnect(int fd)
{
    char buf[128];
    int n;

    n = Snprintf(buf, sizeof(buf),
        "<announce> <user%d> is disconnected.\n", fd);
    if (n >= sizeof(buf) || n < 0)
        return -1;

    return ncat_broadcast(&master_broadcastfds, &broadcast_fdlist, buf, n);
}

/*
 * This is stupid. But it's just a bit of fun.
 *
 * The file descriptor of the sender is prepended to the
 * message sent to clients, so you can distinguish
 * each other with a degree of sanity. This gives a
 * similar effect to an IRC session. But stupider.
 */
static char *chat_filter(char *buf, size_t size, int fd, int *nwritten)
{
    char *result = NULL;
    size_t n = 0;
    const char *p;
    int i;

    n = 32;
    result = (char *) safe_malloc(n);
    i = Snprintf(result, n, "<user%d> ", fd);

    /* Escape control characters. */
    for (p = buf; p - buf < size; p++) {
        char repl[32];
        int repl_len;

        if (isprint((int) (unsigned char) *p) || *p == '\r' || *p == '\n' || *p == '\t') {
            repl[0] = *p;
            repl_len = 1;
        } else {
            repl_len = Snprintf(repl, sizeof(repl), "\\%03o", (unsigned char) *p);
        }

        if (i + repl_len > n) {
            n = (i + repl_len) * 2;
            result = (char *) safe_realloc(result, n + 1);
        }
        memcpy(result + i, repl, repl_len);
        i += repl_len;
    }
    /* Trim to length. (Also does initial allocation when str is empty.) */
    result = (char *) safe_realloc(result, i + 1);
    result[i] = '\0';

    *nwritten = i;

    return result;
}
