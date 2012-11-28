/*
 * discovery_management.c
 *
 *  Created on: 2012/11/19
 *      Author: y-higuchi
 */

#include "discovery_management.h"
#include "service_management.h"
//#include "topology_table.h"
#include "lldp.h"
#include "probe_timer_table.h"

#include "utility.h"
#include "wrapper.h"

static bool g_discovery_enabled = false;

static const uint16_t INITIAL_DISCOVERY_PERIOD = 5;
static discovery_management_options options;

bool
init_discovery_management( discovery_management_options new_options ) {
  options = new_options;
  bool result = true;

  init_probe_timer_table();
  result = init_lldp( new_options.lldp );

  return result;
}


void
finalize_discovery_management( void ) {
  finalize_lldp();
  finalize_probe_timer_table();
}


bool
start_discovery_management( void ){
  return true;
}


void
stop_discovery_management( void ){
  if( g_discovery_enabled ) {
    notice( "Discovery was left enabled." );
    disable_discovery();
  }
}


static void
send_flow_mod_receiving_lldp( const sw_entry *sw, uint16_t hard_timeout, uint16_t priority, bool add ) {
  struct ofp_match match;
  memset( &match, 0, sizeof( struct ofp_match ) );
  if ( !options.lldp.lldp_over_ip ) {
    match.wildcards = OFPFW_ALL & ~OFPFW_DL_TYPE;
    match.dl_type = ETH_ETHTYPE_LLDP;
  }
  else {
    match.wildcards = OFPFW_ALL & ~( OFPFW_DL_TYPE | OFPFW_NW_PROTO | OFPFW_NW_SRC_MASK | OFPFW_NW_DST_MASK );
    match.dl_type = ETH_ETHTYPE_IPV4;
    match.nw_proto = IPPROTO_ETHERIP;
    match.nw_src = options.lldp.lldp_ip_src;
    match.nw_dst = options.lldp.lldp_ip_dst;
  }

  openflow_actions *actions = create_actions();
  const uint16_t max_len = UINT16_MAX;
  append_action_output( actions, OFPP_CONTROLLER, max_len );

  const uint16_t idle_timeout = 0;
  const uint32_t buffer_id = UINT32_MAX;
  const uint16_t flags = 0;
  buffer *flow_mod = create_flow_mod( get_transaction_id(), match, get_cookie(),
                                      ( add )? OFPFC_ADD : OFPFC_DELETE, idle_timeout, hard_timeout,
                                      priority, buffer_id,
                                      OFPP_NONE, flags, actions );
  send_openflow_message( sw->datapath_id, flow_mod );
  delete_actions( actions );
  free_buffer( flow_mod );
  debug( "Sent a flow_mod for receiving LLDP frames from %#" PRIx64 ".", sw->datapath_id );
}


static void
send_add_LLDP_flow_mods( const sw_entry *sw ) {
  const bool add = true;
  send_flow_mod_receiving_lldp( sw, 0, UINT16_MAX, add );
}


static void
send_del_LLDP_flow_mods( const sw_entry *sw ) {
  const bool add = false;
  send_flow_mod_receiving_lldp( sw, 0, UINT16_MAX, add );
}


static void
update_port_status( const port_entry *s ) {
  if ( s->port_no > OFPP_MAX ) {
    return;
  }
  probe_timer_entry *entry = delete_probe_timer_entry( &( s->sw->datapath_id ), s->port_no );
  if ( !s->up ) {
    if ( entry != NULL ) {
      probe_request( entry, PROBE_TIMER_EVENT_DOWN, 0, 0 );
      free_probe_timer_entry( entry );
    }
    return;
  }
  if ( entry == NULL ) {
    entry = allocate_probe_timer_entry( &( s->sw->datapath_id ), s->port_no, s->mac );
  }
  probe_request( entry, PROBE_TIMER_EVENT_UP, 0, 0 );
}

static void
port_entry_walker( port_entry *entry, void *user_data ) {
  UNUSED( user_data );
  update_port_status( entry );
}

static void
handle_port_status_updated_callback( void* param, const port_entry *port ) {
  UNUSED( param );
  update_port_status( port );
}

static void
handle_switch_status_updated_callback( void* param, const sw_entry *sw ) {
  UNUSED( param );
  if ( sw->up ) {
    // switch ready
    send_add_LLDP_flow_mods( sw );
  }
}

static void
switch_add_LLDP_flow_mods( sw_entry *sw, void *user_data ) {
  UNUSED( user_data );
  send_add_LLDP_flow_mods( sw );
}

static void
switch_del_LLDP_flow_mods( sw_entry *sw, void *user_data ) {
  UNUSED( user_data );
  send_del_LLDP_flow_mods( sw );
}


void
enable_discovery( void ) {
  if ( g_discovery_enabled ) {
    warn( "Topology Discovery is already enabled." );
  }
  g_discovery_enabled = true;
  // insert LLDP flow entry
  foreach_sw_entry( switch_add_LLDP_flow_mods, NULL );

  // update all port status
  foreach_port_entry( port_entry_walker, NULL );

  set_switch_status_updated_hook( handle_switch_status_updated_callback, NULL );
  set_port_status_updated_hook( handle_port_status_updated_callback, NULL );
}

void
disable_discovery( void ) {
  if ( !g_discovery_enabled ) {
    warn( "Topology Discovery was not enabled." );
  }
  g_discovery_enabled = false;

  // ignore switch/port events
  set_switch_status_updated_hook( NULL, NULL );
  set_port_status_updated_hook( NULL, NULL );

  // remove LLDP flow entry
  foreach_sw_entry( switch_del_LLDP_flow_mods, NULL );
}
