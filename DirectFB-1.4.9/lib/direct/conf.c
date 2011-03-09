/*
   (c) Copyright 2001-2009  The world wide DirectFB Open Source Community (directfb.org)
   (c) Copyright 2000-2004  Convergence (integrated media) GmbH

   All rights reserved.

   Written by Denis Oliver Kropp <dok@directfb.org>,
              Andreas Hundt <andi@fischlustig.de>,
              Sven Neumann <neo@directfb.org>,
              Ville Syrjälä <syrjala@sci.fi> and
              Claudio Ciccani <klan@users.sf.net>.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the
   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.
*/

#include <config.h>

#include <stdlib.h>
#include <string.h>

#include <direct/conf.h>
#include <direct/mem.h>
#include <direct/util.h>


static DirectConfig config = {
     .debug                 = false,
     .trace                 = true,
     .sighandler            = true,

     .fatal                 = DCFL_ASSERT,
     .fatal_break           = true,
     .thread_block_signals  = true,
     .thread_priority_scale = 100,
};

DirectConfig *direct_config       = &config;
const char   *direct_config_usage =
     "libdirect options:\n"
     "  memcpy=<method>                Skip memcpy() probing (help = show list)\n"
     "  [no-]quiet                     Disable text output except debug messages or direct logs\n"
     "  [no-]quiet=<type>              Only quiet certain types (cumulative with 'quiet')\n"
     "                                 [ info | warning | error | once | unimplemented ]\n"
     "  [no-]debug                     Enable debug output\n"
     "  [no-]debugmem                  Enable memory allocation tracking\n"
     "  [no-]trace                     Enable stack trace support\n"
     "  log-file=<name>                Write all messages to a file\n"
     "  log-udp=<host>:<port>          Send all messages via UDP to host:port\n"
     "  fatal-level=<level>            Abort on NONE, ASSERT (default) or ASSUME (incl. assert)\n"
     "  [no-]fatal-break               Abort on BREAK (default)\n"
     "  dont-catch=<num>[[,<num>]...]  Don't catch these signals\n"
     "  [no-]sighandler                Enable signal handler\n"
     "  [no-]thread-block-signals      Block all signals in new threads?\n"
     "  disable-module=<module_name>   suppress loading this module\n"
     "  module-dir=<directory>         Override default module search directory (default = $libdir/directfb-x.y-z)\n"
     "  thread-priority-scale=<100th>  Apply scaling factor on thread type based priorities\n"
     "\n";

/**********************************************************************************************************************/

DirectResult
direct_config_set( const char *name, const char *value )
{
     if (strcmp (name, "disable-module" ) == 0) {
          if (value) {
               int n = 0;

               while (direct_config->disable_module &&
                      direct_config->disable_module[n])
                    n++;

               direct_config->disable_module = D_REALLOC( direct_config->disable_module,
                                                          sizeof(char*) * (n + 2) );

               direct_config->disable_module[n] = D_STRDUP( value );
               direct_config->disable_module[n+1] = NULL;
          }
          else {
               D_ERROR("Direct/Config '%s': No module name specified!\n", name);
               return DR_INVARG;
          }
     } else
     if (strcmp (name, "module-dir" ) == 0) {
          if (value) {
               if (direct_config->module_dir)
                    D_FREE( direct_config->module_dir );
               direct_config->module_dir = D_STRDUP( value );
          }
          else {
               D_ERROR("Direct/Config 'module-dir': No directory name specified!\n");
               return DR_INVARG;
          }
     } else
     if (strcmp (name, "memcpy" ) == 0) {
          if (value) {
               if (direct_config->memcpy)
                    D_FREE( direct_config->memcpy );
               direct_config->memcpy = D_STRDUP( value );
          }
          else {
               D_ERROR("Direct/Config '%s': No method specified!\n", name);
               return DR_INVARG;
          }
     }
     else
          if (strcmp (name, "quiet" ) == 0 || strcmp (name, "no-quiet" ) == 0) {
          /* Enable/disable all at once by default. */
          DirectMessageType type = DMT_ALL;

          /* Find out the specific message type being configured. */
          if (value) {
               if (!strcmp( value, "info" ))           type = DMT_INFO;              else
               if (!strcmp( value, "warning" ))        type = DMT_WARNING;           else
               if (!strcmp( value, "error" ))          type = DMT_ERROR;             else
               if (!strcmp( value, "once" ))           type = DMT_ONCE;              else
               if (!strcmp( value, "unimplemented" ))  type = DMT_UNIMPLEMENTED; 
               else {
                    D_ERROR( "DirectFB/Config '%s': Unknown message type '%s'!\n", name, value );
                    return DR_INVARG;
               }
          }

          /* Set/clear the corresponding flag in the configuration. */
          if (name[0] == 'q')
               direct_config->quiet |= type;
          else
               direct_config->quiet &= ~type;
     }
     else
          if (strcmp (name, "no-quiet" ) == 0) {
          direct_config->quiet = false;
     }
     else
          if (strcmp (name, "debug" ) == 0) {
          if (value)
               direct_debug_config_domain( value, true );
          else
               direct_config->debug = true;
     }
     else
          if (strcmp (name, "no-debug" ) == 0) {
          if (value)
               direct_debug_config_domain( value, false );
          else
               direct_config->debug = false;
     }
     else
          if (strcmp (name, "debugmem" ) == 0) {
          direct_config->debugmem = true;
     }
     else
          if (strcmp (name, "no-debugmem" ) == 0) {
          direct_config->debugmem = false;
     }
     else
          if (strcmp (name, "trace" ) == 0) {
          direct_config->trace = true;
     }
     else
          if (strcmp (name, "no-trace" ) == 0) {
          direct_config->trace = false;
     }
     else
          if (strcmp (name, "log-file" ) == 0 || strcmp (name, "log-udp" ) == 0) {
          if (value) {
               DirectResult  ret;
               DirectLog    *log;

               ret = direct_log_create( strcmp(name,"log-udp") ? DLT_FILE : DLT_UDP, value, &log );
               if (ret)
                    return ret;

               if (direct_config->log)
                    direct_log_destroy( direct_config->log );

               direct_config->log = log;

               direct_log_set_default( log );
          }
          else {
               if (strcmp(name,"log-udp"))
                    D_ERROR("Direct/Config '%s': No file name specified!\n", name);
               else
                    D_ERROR("Direct/Config '%s': No host and port specified!\n", name);
               return DR_INVARG;
          }
     }
     else
          if (strcmp (name, "fatal-level" ) == 0) {
          if (strcasecmp (value, "none" ) == 0) {
               direct_config->fatal = DCFL_NONE;
          }
          else
               if (strcasecmp (value, "assert" ) == 0) {
               direct_config->fatal = DCFL_ASSERT;
          }
          else
               if (strcasecmp (value, "assume" ) == 0) {
               direct_config->fatal = DCFL_ASSUME;
          }
          else {
               D_ERROR("Direct/Config '%s': Unknown level specified (use 'none', 'assert', 'assume')!\n", name);
               return DR_INVARG;
          }
     }
     else
          if (strcmp (name, "fatal-break" ) == 0) {
          direct_config->fatal_break = true;
     }
     else
          if (strcmp (name, "no-fatal-break" ) == 0) {
          direct_config->fatal_break = false;
     }
     else
          if (strcmp (name, "sighandler" ) == 0) {
          direct_config->sighandler = true;
     }
     else
          if (strcmp (name, "no-sighandler" ) == 0) {
          direct_config->sighandler = false;
     }
     else
          if (strcmp (name, "dont-catch" ) == 0) {
          if (value) {
               char *signals   = D_STRDUP( value );
               char *p = NULL, *r, *s = signals;

               while ((r = strtok_r( s, ",", &p ))) {
                    char          *error;
                    unsigned long  signum;

                    direct_trim( &r );

                    signum = strtoul( r, &error, 10 );

                    if (*error) {
                         D_ERROR( "Direct/Config '%s': Error in number at '%s'!\n", name, error );
                         D_FREE( signals );
                         return DR_INVARG;
                    }

                    sigaddset( &direct_config->dont_catch, signum );

                    s = NULL;
               }

               D_FREE( signals );
          }
          else {
               D_ERROR("Direct/Config '%s': No signals specified!\n", name);
               return DR_INVARG;
          }
     }
     else
          if (strcmp (name, "thread_block_signals") == 0) {
          direct_config->thread_block_signals = true;
     }
     else
          if (strcmp (name, "no-thread_block_signals") == 0) {
          direct_config->thread_block_signals = false;
     } else
     if (strcmp (name, "thread-priority-scale" ) == 0) {
          if (value) {
               int scale;

               if (sscanf( value, "%d", &scale ) < 1) {
                    D_ERROR("Direct/Config '%s': Could not parse value!\n", name);
                    return DR_INVARG;
               }

               direct_config->thread_priority_scale = scale;
          }
          else {
               D_ERROR("Direct/Config '%s': No value specified!\n", name);
               return DR_INVARG;
          }
     } else
     if (strcmp (name, "thread-priority" ) == 0) {  /* Must be moved to lib/direct/conf.c in trunk! */
          if (value) {
               int priority;

               if (sscanf( value, "%d", &priority ) < 1) {
                    D_ERROR("Direct/Config '%s': Could not parse value!\n", name);
                    return DR_INVARG;
               }

               direct_config->thread_priority = priority;
          }
          else {
               D_ERROR("Direct/Config '%s': No value specified!\n", name);
               return DR_INVARG;
          }
     } else
     if (strcmp (name, "thread-scheduler" ) == 0) {  /* Must be moved to lib/direct/conf.c in trunk! */
          if (value) {
               if (strcmp( value, "other" ) == 0) {
                    direct_config->thread_scheduler = DCTS_OTHER;
               } else
               if (strcmp( value, "fifo" ) == 0) {
                    direct_config->thread_scheduler = DCTS_FIFO;
               } else
               if (strcmp( value, "rr" ) == 0) {
                    direct_config->thread_scheduler = DCTS_RR;
               } else {
                    D_ERROR( "Direct/Config '%s': Unknown scheduler '%s'!\n", name, value );
                    return DR_INVARG;
               }
          }
          else {
               D_ERROR( "Direct/Config '%s': No value specified!\n", name );
               return DR_INVARG;
          }
     } else
     if (strcmp (name, "thread-stacksize" ) == 0) {  /* Must be moved to lib/direct/conf.c in trunk! */
          if (value) {
               int size;

               if (sscanf( value, "%d", &size ) < 1) {
                    D_ERROR( "Direct/Config '%s': Could not parse value!\n", name );
                    return DR_INVARG;
               }

               direct_config->thread_stack_size = size;
          }
          else {
               D_ERROR( "Direct/Config '%s': No value specified!\n", name );
               return DR_INVARG;
          }
     }
     else
          return DR_UNSUPPORTED;

     return DR_OK;
}

