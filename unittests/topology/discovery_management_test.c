/*
 * discovery_management_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>

#include "checks.h"
#include "cmockery_trema.h"
#include "trema.h"

#include "discovery_management.h"
#include "service_management.h"

#include "topology_table.h"
#include "probe_timer_table.h"


/********************************************************************************
 * Common function.
 ********************************************************************************/

#define TEST_TREMA_NAME "disc_mgmt_test"
#define TEST_OFA_NAME TEST_TREMA_NAME ".ofa"
// defined in trema.c
extern void set_trema_name( const char *name );
extern void _free_trema_name();

/********************************************************************************
 * Mock functions.
 ********************************************************************************/

static void ( *original_notice )( const char *format, ... );
static void ( *original_warn )( const char *format, ... );

static bool ( *original_set_port_status_updated_hook )( port_status_updated_hook, void *user_data );
static bool ( *original_set_switch_status_updated_hook )( switch_status_updated_hook, void *user_data );

static void ( *original_execute_timer_events )( int *next_timeout_usec );


#define swap_original( funcname ) \
  original_##funcname = funcname;\
  funcname = mock_##funcname;

#define revert_original( funcname ) \
  funcname = original_##funcname;


static bool check_notice = false;
static void
mock_notice_check( const char *format, va_list args ) {
  char message[ 1000 ];
  vsnprintf( message, 1000, format, args );

  check_expected( message );
}


void
mock_notice( const char *format, ... ) {
  if( check_notice ) {
    va_list arg;
    va_start( arg, format );
    mock_notice_check( format, arg );
    va_end( arg );
  }
}


static bool check_warn = false;
static void
mock_warn_check( const char *format, va_list args ) {
  char message[ 1000 ];
  vsnprintf( message, 1000, format, args );

  check_expected( message );
}


void
mock_warn( const char *format, ... ) {
  if( check_warn ) {
    va_list arg;
    va_start( arg, format );
    mock_warn_check( format, arg );
    va_end( arg );
  }
}

static port_status_updated_hook port_status_updated_hook_callback;
static bool
mock_set_port_status_updated_hook( port_status_updated_hook callback, void *user_data ) {
  port_status_updated_hook_callback = callback;
  check_expected( callback );
  check_expected( user_data );
  return (bool)mock();
}

static switch_status_updated_hook switch_status_updated_hook_callback;
static bool
mock_set_switch_status_updated_hook( switch_status_updated_hook callback, void *user_data ) {
  switch_status_updated_hook_callback = callback;
  check_expected( callback );
  check_expected( user_data );
  return (bool)mock();
}


static void
expect_switch_and_port_status_hook_set() {
  expect_not_value( mock_set_switch_status_updated_hook, callback, NULL );
  expect_value( mock_set_switch_status_updated_hook, user_data, NULL );
  will_return( mock_set_switch_status_updated_hook, true );
  expect_not_value( mock_set_port_status_updated_hook, callback, NULL );
  expect_value( mock_set_port_status_updated_hook, user_data, NULL );
  will_return( mock_set_port_status_updated_hook, true );
}

static void
expect_switch_and_port_status_hook_clear() {
  expect_value( mock_set_switch_status_updated_hook, callback, NULL );
  expect_value( mock_set_switch_status_updated_hook, user_data, NULL );
  will_return( mock_set_switch_status_updated_hook, true );
  expect_value( mock_set_port_status_updated_hook, callback, NULL );
  expect_value( mock_set_port_status_updated_hook, user_data, NULL );
  will_return( mock_set_port_status_updated_hook, true );
}

static void
mock_execute_timer_events( int *next_timeout_usec ) {
  UNUSED( next_timeout_usec );
  // Do nothing.
}

/********************************************************************************
 * Setup and teardown functions.
 ********************************************************************************/

static void
setup() {
  set_trema_name( TEST_TREMA_NAME );
  init_messenger("/tmp");
  init_timer();
  init_stat();
  init_openflow_application_interface( TEST_OFA_NAME );

  swap_original( notice );
  swap_original( warn );
  swap_original( set_switch_status_updated_hook );
  swap_original( set_port_status_updated_hook );

}

static void
teardown() {
  revert_original( notice );
  revert_original( warn );
  check_notice = false;
  check_warn = false;
  revert_original( set_switch_status_updated_hook );
  revert_original( set_port_status_updated_hook );

  finalize_openflow_application_interface();
  finalize_stat();
  finalize_timer();
  finalize_messenger();
  _free_trema_name();
}

static void
setup_discovery_mgmt() {
  setup();
  discovery_management_options options;
  options.always_enabled = false;

  assert_true( init_discovery_management( options ) );
  assert_true( start_discovery_management() );
}

static void
teardown_discovery_mgmt() {
  stop_discovery_management();
  finalize_discovery_management();

  // deleted timer event struct will not be freed until next timer event
  // fake timer event;
  int next=100000;
  execute_timer_events(&next);

  teardown();
}

/********************************************************************************
 * Tests.
 ********************************************************************************/


static void
test_init_finalize() {
  discovery_management_options options;
  options.always_enabled = false;

  assert_true( init_discovery_management( options ) );

  assert_true( start_discovery_management() );
  stop_discovery_management();

  finalize_discovery_management();

  // deleted timer event struct will not be freed until next timer event
  // fake timer event;
  int next=100000;
  execute_timer_events(&next);
}

static void
test_init_finalize_with_always_discovery() {
  discovery_management_options options;
  options.always_enabled = true;

  assert_true( init_discovery_management( options ) );


  expect_switch_and_port_status_hook_set();

  assert_true( start_discovery_management() );


  expect_switch_and_port_status_hook_clear();

  check_notice = true;
  stop_discovery_management();
  check_notice = false;


  finalize_discovery_management();

  // deleted timer event struct will not be freed until next timer event
  // fake timer event;
  int next=100000;
  execute_timer_events(&next);
}

static void
test_enable_discovery_twice_prints_message() {


  check_warn = true;

  expect_switch_and_port_status_hook_set();

  enable_discovery();

  expect_string( mock_warn_check, message, "Topology Discovery is already enabled." );

  expect_switch_and_port_status_hook_set();

  enable_discovery();

  check_warn = false;

  expect_switch_and_port_status_hook_clear();

  disable_discovery();
}

static void
test_disable_discovery_twice_prints_message() {


  check_warn = true;
  check_notice = true;

  expect_switch_and_port_status_hook_set();

  enable_discovery();

  expect_switch_and_port_status_hook_clear();

  disable_discovery();

  expect_string( mock_warn_check, message, "Topology Discovery was not enabled." );

  expect_switch_and_port_status_hook_clear();

  disable_discovery();

  check_warn = false;
  check_notice = false;
}


static void
helper_sw_received_flow_mod_add_lldp_message_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );

  buffer* buffer = alloc_buffer_with_length(len);
  void* raw_data = append_back_buffer( buffer, len );
  memcpy( raw_data, data, len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t ofs_header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );

  struct ofp_flow_mod* ofp_flow_mod = remove_front_buffer(buffer, ofs_header_length );
  assert_int_equal( ofp_flow_mod->header.type, OFPT_FLOW_MOD );
  assert_int_equal( ntohs(ofp_flow_mod->priority), UINT16_MAX );
  assert_int_equal( ntohs(ofp_flow_mod->command), OFPFC_ADD );
  assert_int_equal( ntohs(ofp_flow_mod->idle_timeout), 0 );
  assert_int_equal( ntohs(ofp_flow_mod->hard_timeout), 0 );

  struct ofp_match match;
  ntoh_match( &match, &ofp_flow_mod->match );
  assert_int_equal( match.wildcards, OFPFW_ALL & ~OFPFW_DL_TYPE );
  assert_int_equal( match.dl_type, ETH_ETHTYPE_LLDP );

  struct ofp_action_output* act_out = remove_front_buffer(buffer, offsetof( struct ofp_flow_mod, actions ) );
  assert_int_equal( ntohs(act_out->type), OFPAT_OUTPUT );
  assert_int_equal( ntohs(act_out->port), OFPP_CONTROLLER );

  free_buffer( buffer );

  stop_event_handler();
  stop_messenger();
}


static void
test_switch_status_event_then_flow_mod_lldp_if_sw_up() {
  setup_discovery_mgmt();
  expect_switch_and_port_status_hook_set();
  enable_discovery();

  assert_true( switch_status_updated_hook_callback != NULL );

  // Test: do nothing if sw down
  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = false;

  switch_status_updated_hook_callback( NULL, &sw );


  // Test: send LLDP flow mod if sw up

  // dummy OFA receiving notification
  UNUSED( helper_sw_received_flow_mod_add_lldp_message_end );
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_message_end ) );

  expect_value( helper_sw_received_flow_mod_add_lldp_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_add_lldp_message_end, datapath_id, 0x1234 );


  sw.up = true;
  switch_status_updated_hook_callback( NULL, &sw );

  start_messenger();
  start_event_handler();


  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_message_end ) );

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  teardown_discovery_mgmt();
}


static void
helper_sw_received_flow_mod_add_lldp_over_ip_message_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );

  buffer* buffer = alloc_buffer_with_length(len);
  void* raw_data = append_back_buffer( buffer, len );
  memcpy( raw_data, data, len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t ofs_header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );

  struct ofp_flow_mod* ofp_flow_mod = remove_front_buffer(buffer, ofs_header_length );
  assert_int_equal( ofp_flow_mod->header.type, OFPT_FLOW_MOD );
  assert_int_equal( ntohs(ofp_flow_mod->priority), UINT16_MAX );
  assert_int_equal( ntohs(ofp_flow_mod->command), OFPFC_ADD );
  assert_int_equal( ntohs(ofp_flow_mod->idle_timeout), 0 );
  assert_int_equal( ntohs(ofp_flow_mod->hard_timeout), 0 );

  struct ofp_match match;
  ntoh_match( &match, &ofp_flow_mod->match );
  assert_int_equal( match.wildcards, OFPFW_ALL & ~( OFPFW_DL_TYPE | OFPFW_NW_PROTO | OFPFW_NW_SRC_MASK | OFPFW_NW_DST_MASK ) );
  assert_int_equal( match.dl_type, ETH_ETHTYPE_IPV4 );
  assert_int_equal( match.nw_proto, IPPROTO_ETHERIP );
  const uint32_t nw_src = match.nw_src;
  const uint32_t nw_dst = match.nw_dst;
  check_expected( nw_src );
  check_expected( nw_dst );

  struct ofp_action_output* act_out = remove_front_buffer(buffer, offsetof( struct ofp_flow_mod, actions ) );
  assert_int_equal( ntohs(act_out->type), OFPAT_OUTPUT );
  assert_int_equal( ntohs(act_out->port), OFPP_CONTROLLER );

  free_buffer( buffer );

  stop_event_handler();
  stop_messenger();
}


static void
test_switch_status_event_over_ip_then_flow_mod_lldp_if_sw_up() {
  setup();
  discovery_management_options options;
  options.always_enabled = false;
  options.lldp.lldp_over_ip = true;
  options.lldp.lldp_ip_src = 0x01234567;
  options.lldp.lldp_ip_dst = 0x89ABCDEF;

  assert_true( init_discovery_management( options ) );
  assert_true( start_discovery_management() );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  assert_true( switch_status_updated_hook_callback != NULL );

  // Test: do nothing if sw down
  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = false;

  switch_status_updated_hook_callback( NULL, &sw );


  // Test: send LLDP flow mod if sw up

  // dummy OFA receiving notification
  UNUSED( helper_sw_received_flow_mod_add_lldp_message_end );
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_over_ip_message_end ) );

  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, datapath_id, 0x1234 );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, nw_src, 0x01234567 );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, nw_dst, 0x89ABCDEF );


  sw.up = true;
  switch_status_updated_hook_callback( NULL, &sw );

  start_messenger();
  start_event_handler();


  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_over_ip_message_end ) );

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  teardown_discovery_mgmt();
}


static void
test_port_status_event() {
  // disable timer events
  UNUSED( original_execute_timer_events );
  UNUSED( mock_execute_timer_events );
  swap_original( execute_timer_events );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  assert_true( port_status_updated_hook_callback != NULL );

  const uint64_t dpid = 0x1234;
  sw_entry* sw = update_sw_entry( &dpid );
  sw->up = true;
  port_entry* p = update_port_entry( sw, 42, "Some Portname" );
  p->up = true;

  // port up for the 1st time => probe_timer_entry created with UP event
  port_status_updated_hook_callback( NULL, p );

  probe_timer_entry* e = lookup_probe_timer_entry( &dpid, 42 );
  assert_true( e != NULL );
  assert_int_equal( e->state, PROBE_TIMER_STATE_SEND_DELAY );

  // port down => probe_timer_entry removed
  p->up = false;
  port_status_updated_hook_callback( NULL, p );
  e = lookup_probe_timer_entry( &dpid, 42 );
  assert_true( e == NULL );


  delete_port_entry( sw, p );
  delete_sw_entry( sw );

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  revert_original( execute_timer_events );
}

static void
helper_sw_received_flow_mod_del_lldp_message_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );

  buffer* buffer = alloc_buffer_with_length(len);
  void* raw_data = append_back_buffer( buffer, len );
  memcpy( raw_data, data, len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t ofs_header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );

  struct ofp_flow_mod* ofp_flow_mod = remove_front_buffer(buffer, ofs_header_length );
  assert_int_equal( ofp_flow_mod->header.type, OFPT_FLOW_MOD );
  assert_int_equal( ntohs(ofp_flow_mod->priority), UINT16_MAX );
  assert_int_equal( ntohs(ofp_flow_mod->command), OFPFC_DELETE );
  assert_int_equal( ntohs(ofp_flow_mod->idle_timeout), 0 );
  assert_int_equal( ntohs(ofp_flow_mod->hard_timeout), 0 );

  struct ofp_match match;
  ntoh_match( &match, &ofp_flow_mod->match );
  assert_int_equal( match.wildcards, OFPFW_ALL & ~OFPFW_DL_TYPE );
  assert_int_equal( match.dl_type, ETH_ETHTYPE_LLDP );

  struct ofp_action_output* act_out = remove_front_buffer(buffer, offsetof( struct ofp_flow_mod, actions ) );
  assert_int_equal( ntohs(act_out->type), OFPAT_OUTPUT );
  assert_int_equal( ntohs(act_out->port), OFPP_CONTROLLER );

  free_buffer( buffer );

  stop_event_handler();
  stop_messenger();
}


static void
test_enable_discovery_when_sw_exist_then_flow_mod_add_lldp() {
  setup_discovery_mgmt();

  const uint64_t datapath_id = 0x1234;
  sw_entry* sw = update_sw_entry( &datapath_id );
  sw->up = true;

  // dummy OFA receiving notification
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_message_end ) );

  expect_value( helper_sw_received_flow_mod_add_lldp_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_add_lldp_message_end, datapath_id, 0x1234 );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_message_end ) );

  delete_sw_entry( sw );

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  teardown_discovery_mgmt();
}

static void
test_disable_discovery_when_sw_exist_then_flow_mod_del_lldp() {
  setup_discovery_mgmt();

  // dummy OFA receiving notification
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_del_lldp_message_end ) );

  expect_value( helper_sw_received_flow_mod_del_lldp_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_del_lldp_message_end, datapath_id, 0x1234 );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  const uint64_t datapath_id = 0x1234;
  sw_entry* sw = update_sw_entry( &datapath_id );
  sw->up = true;

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_del_lldp_message_end ) );

  delete_sw_entry( sw );

  teardown_discovery_mgmt();
}


static void
helper_sw_received_flow_mod_del_lldp_over_ip_message_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );

  buffer* buffer = alloc_buffer_with_length(len);
  void* raw_data = append_back_buffer( buffer, len );
  memcpy( raw_data, data, len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t ofs_header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );

  struct ofp_flow_mod* ofp_flow_mod = remove_front_buffer(buffer, ofs_header_length );
  assert_int_equal( ofp_flow_mod->header.type, OFPT_FLOW_MOD );
  assert_int_equal( ntohs(ofp_flow_mod->priority), UINT16_MAX );
  assert_int_equal( ntohs(ofp_flow_mod->command), OFPFC_DELETE );
  assert_int_equal( ntohs(ofp_flow_mod->idle_timeout), 0 );
  assert_int_equal( ntohs(ofp_flow_mod->hard_timeout), 0 );

  struct ofp_match match;
  ntoh_match( &match, &ofp_flow_mod->match );
  assert_int_equal( match.wildcards, OFPFW_ALL & ~( OFPFW_DL_TYPE | OFPFW_NW_PROTO | OFPFW_NW_SRC_MASK | OFPFW_NW_DST_MASK ) );
  assert_int_equal( match.dl_type, ETH_ETHTYPE_IPV4 );
  assert_int_equal( match.nw_proto, IPPROTO_ETHERIP );
  const uint32_t nw_src = match.nw_src;
  const uint32_t nw_dst = match.nw_dst;
  check_expected( nw_src );
  check_expected( nw_dst );

  struct ofp_action_output* act_out = remove_front_buffer(buffer, offsetof( struct ofp_flow_mod, actions ) );
  assert_int_equal( ntohs(act_out->type), OFPAT_OUTPUT );
  assert_int_equal( ntohs(act_out->port), OFPP_CONTROLLER );

  free_buffer( buffer );

  stop_event_handler();
  stop_messenger();
}


static void
test_enable_discovery_when_sw_exist_then_flow_mod_add_lldp_over_ip() {
  setup();
  discovery_management_options options;
  options.always_enabled = false;
  options.lldp.lldp_over_ip = true;
  options.lldp.lldp_ip_src = 0x01234567;
  options.lldp.lldp_ip_dst = 0x89ABCDEF;

  assert_true( init_discovery_management( options ) );
  assert_true( start_discovery_management() );

  const uint64_t datapath_id = 0x1234;
  sw_entry* sw = update_sw_entry( &datapath_id );
  sw->up = true;

  // dummy OFA receiving notification
  UNUSED( helper_sw_received_flow_mod_add_lldp_message_end );
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_over_ip_message_end ) );

  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, datapath_id, 0x1234 );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, nw_src, 0x01234567 );
  expect_value( helper_sw_received_flow_mod_add_lldp_over_ip_message_end, nw_dst, 0x89ABCDEF );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_add_lldp_over_ip_message_end ) );

  delete_sw_entry( sw );

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  teardown_discovery_mgmt();
}


static void
test_disable_discovery_when_sw_exist_then_flow_mod_del_lldp_over_ip() {
  setup();
  discovery_management_options options;
  options.always_enabled = false;
  options.lldp.lldp_over_ip = true;
  options.lldp.lldp_ip_src = 0x01234567;
  options.lldp.lldp_ip_dst = 0x89ABCDEF;

  assert_true( init_discovery_management( options ) );
  assert_true( start_discovery_management() );


  // dummy OFA receiving notification
  UNUSED( helper_sw_received_flow_mod_add_lldp_message_end );
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_del_lldp_over_ip_message_end ) );

  expect_value( helper_sw_received_flow_mod_del_lldp_over_ip_message_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_received_flow_mod_del_lldp_over_ip_message_end, datapath_id, 0x1234 );
  expect_value( helper_sw_received_flow_mod_del_lldp_over_ip_message_end, nw_src, 0x01234567 );
  expect_value( helper_sw_received_flow_mod_del_lldp_over_ip_message_end, nw_dst, 0x89ABCDEF );

  expect_switch_and_port_status_hook_set();
  enable_discovery();

  const uint64_t datapath_id = 0x1234;
  sw_entry* sw = update_sw_entry( &datapath_id );
  sw->up = true;

  expect_switch_and_port_status_hook_clear();
  disable_discovery();

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_received_flow_mod_del_lldp_over_ip_message_end ) );

  delete_sw_entry( sw );


  teardown_discovery_mgmt();
}


/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
      unit_test_setup_teardown( test_init_finalize, setup, teardown ),
      unit_test_setup_teardown( test_init_finalize_with_always_discovery, setup, teardown ),
      unit_test_setup_teardown( test_enable_discovery_twice_prints_message, setup_discovery_mgmt, teardown_discovery_mgmt ),
      unit_test_setup_teardown( test_disable_discovery_twice_prints_message, setup_discovery_mgmt, teardown_discovery_mgmt ),

      unit_test( test_enable_discovery_when_sw_exist_then_flow_mod_add_lldp ),
      unit_test( test_enable_discovery_when_sw_exist_then_flow_mod_add_lldp_over_ip ),

      unit_test( test_disable_discovery_when_sw_exist_then_flow_mod_del_lldp ),
      unit_test( test_disable_discovery_when_sw_exist_then_flow_mod_del_lldp_over_ip ),

      unit_test( test_switch_status_event_then_flow_mod_lldp_if_sw_up ),
      unit_test( test_switch_status_event_over_ip_then_flow_mod_lldp_if_sw_up ),
      unit_test_setup_teardown( test_port_status_event, setup_discovery_mgmt, teardown_discovery_mgmt ),
  };

  setup_leak_detector();
  return run_tests( tests );
}

