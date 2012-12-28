/*
 * Author: Shuji Ishii, Kazushi SUGYO
 *
 * Copyright (C) 2008-2011 NEC Corporation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */


#include <assert.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ether.h>
#include <arpa/inet.h>
#include <openflow.h>
#include "trema.h"

#include "service_management.h"
#include "topology_management.h"
#include "discovery_management.h"

#include "topology_option_parser.h"


int
main( int argc, char *argv[] ) {
  topology_options options;

  init_trema( &argc, &argv );

  parse_options( &options, &argc, &argv );

  char ofa_service_name[MESSENGER_SERVICE_NAME_LENGTH] = {};
  if ( strlen( get_trema_name() ) >= ( MESSENGER_SERVICE_NAME_LENGTH - 4 ) ) {
    die( "Base service name too long to create open flow appllication service name ( %s ).", get_trema_name() );
  }
  snprintf( ofa_service_name, MESSENGER_SERVICE_NAME_LENGTH, "%s.ofa", get_trema_name() );
  init_openflow_application_interface( ofa_service_name );

  info( "Initializing topology services");
  init_topology_table();

  init_topology_management();
  init_discovery_management( options.discovery );
  init_service_management( options.service );

  info( "Starting topology services");
  start_topology_management();
  start_service_management();
  start_discovery_management();

  start_trema();

  info( "Stopping topology services");
  stop_discovery_management();
  stop_service_management();
  stop_topology_management();

  info( "Finalizing topology services");
  finalize_service_management();
  finalize_discovery_management();
  finalize_topology_management();

  finalize_topology_table();

  return 0;
}


/*
 * Local variables:
 * c-basic-offset: 2
 * indent-tabs-mode: nil
 * End:
 */

