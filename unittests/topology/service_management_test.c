/*
 * service_management_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>

#include "checks.h"
#include "cmockery_trema.h"
#include "trema.h"

#include "service_management.h"

#include "subscriber_table.h"

/********************************************************************************
 * Common function.
 ********************************************************************************/

#define TEST_TREMA_NAME "test_service_mgmt"
#define TEST_SUBSCRIBER_NAME "test_topo-client-12345"

// defined in trema.c
extern void set_trema_name( const char *name );
extern void _free_trema_name();

/********************************************************************************
 * Mock functions.
 ********************************************************************************/

#define swap_original( funcname ) \
  original_##funcname = funcname;\
  funcname = mock_##funcname;

#define revert_original( funcname ) \
  funcname = original_##funcname;

static bool ( *original_add_message_requested_callback )( const char *service_name, void ( *callback )( const messenger_context_handle *handle, uint16_t tag, void *data, size_t len ) );
static bool ( *original_add_message_replied_callback )( const char *service_name, void ( *callback )( uint16_t tag, void *data, size_t len, void *user_data ) );

static bool ( *original_add_periodic_event_callback )( const time_t seconds, timer_callback callback, void *user_data );

static bool
mock_add_message_requested_callback( const char *service_name,
                                     void ( *callback )( const messenger_context_handle *handle, uint16_t tag, void *data, size_t len ) ) {
  check_expected( service_name );
  UNUSED( callback );
  return ( bool ) mock();
}

static bool
mock_add_message_replied_callback( const char *service_name, void ( *callback )( uint16_t tag, void *data, size_t len, void *user_data ) ) {
  check_expected( service_name );
//  check_expected( callback );
  UNUSED( callback );
  return (bool)mock();
}

static bool
mock_add_periodic_event_callback( const time_t seconds, timer_callback callback, void *user_data ) {
  check_expected( seconds );
//  check_expected( callback );
  UNUSED( callback );
  check_expected( user_data );
  return ( bool ) mock();
}


static void
mock_link_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  topology_link_status *const link_status = data;
  const int number_of_links = ( int ) ( len / sizeof( topology_link_status ) );
  int i;

  // (re)build topology db
  for ( i = 0; i < number_of_links; i++ ) {
    topology_link_status *s = &link_status[ i ];
    s->from_dpid = ntohll( s->from_dpid );
    s->from_portno = ntohs( s->from_portno );
    s->to_dpid = ntohll( s->to_dpid );
    s->to_portno = ntohs( s->to_portno );

    const uint64_t from_dpid = s->from_dpid;
    check_expected( from_dpid );

    const uint16_t from_portno = s->from_portno;
    check_expected( from_portno );

    const uint64_t to_dpid = s->to_dpid;
    check_expected( to_dpid );

    const uint16_t to_portno = s->to_portno;
    check_expected( to_portno );

    const uint8_t status = s->status;
    check_expected( status );
  }
}


// handle asynchronous notification from topology
static void
mock_port_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  UNUSED( len );
  topology_port_status *const port_status = data;


  // arrange byte order
  topology_port_status *s = port_status;
  s->dpid = ntohll( s->dpid );
  s->port_no = ntohs( s->port_no );

  const uint64_t dpid = s->dpid;
  check_expected( dpid );

  const uint16_t port_no = s->port_no;
  check_expected( port_no );

  const char* name = s->name;
  check_expected( name );

  const uint8_t* mac = s->mac;
  check_expected( mac );

  const uint8_t external = s->external;
  check_expected( external );

  const uint8_t status = s->status;
  check_expected( status );
}

static void
mock_switch_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  UNUSED( len );
  topology_switch_status* switch_status = data;

  // arrange byte order
  switch_status->dpid = ntohll( switch_status->dpid );

  const uint64_t dpid = switch_status->dpid;
  check_expected( dpid );

  const uint8_t status = switch_status->status;
  check_expected( status );
}

static void
callback_fake_libtopology_client_notification_end( uint16_t tag, void *data, size_t len ) {

  switch( tag ){
  case TD_MSGTYPE_LINK_STATUS_NOTIFICATION:
    mock_link_status_notification( tag, data, len );
    break;

  case TD_MSGTYPE_PORT_STATUS_NOTIFICATION:
    mock_port_status_notification( tag, data, len );
    break;

  case TD_MSGTYPE_SWITCH_STATUS_NOTIFICATION:
    mock_switch_status_notification( tag, data, len );
    break;

  default:
    // not reachable
    assert_int_equal(tag, NULL);
  }

  stop_event_handler();
  stop_messenger();
}


/********************************************************************************
 * Setup and teardown functions.
 ********************************************************************************/

static void
setup() {
  set_trema_name( TEST_TREMA_NAME );

  swap_original( add_message_requested_callback );
  swap_original( add_message_replied_callback );

  swap_original( add_periodic_event_callback );

}

static void
teardown() {
  revert_original( add_message_requested_callback );
  revert_original( add_message_replied_callback );

  revert_original( add_periodic_event_callback );

  _free_trema_name();
}

static void
setup_fake_subscriber() {
  service_management_options options = {
      .ping_interval_sec = 60,
      .ping_ageout_cycles = 5,
  };
  assert_true( init_service_management( options ) );

  insert_subscriber_entry( TEST_SUBSCRIBER_NAME );
}


static void
teardown_fake_subscriber() {
  subscriber_entry* e = lookup_subscriber_entry( TEST_SUBSCRIBER_NAME );
  assert_true( e != NULL );
  delete_subscriber_entry( e );
  finalize_service_management();
}

/********************************************************************************
 * Tests.
 ********************************************************************************/



//bool init_service_management( service_management_options new_options );
//void finalize_service_management();
static void
test_init_finalize_service_management() {
  service_management_options options = {
      .ping_interval_sec = 60,
      .ping_ageout_cycles = 5,
  };
  assert_true( init_service_management( options ) );
  finalize_service_management();
}

//bool start_service_management( void );
//void stop_service_management( void );
static void
test_init_start_stop_finalize_service_management() {
  service_management_options options = {
      .ping_interval_sec = 60,
      .ping_ageout_cycles = 5,
  };
  assert_true( init_service_management( options ) );


  expect_string( mock_add_message_requested_callback, service_name, TEST_TREMA_NAME );
  will_return( mock_add_message_requested_callback, true);
  expect_string( mock_add_message_replied_callback, service_name, TEST_TREMA_NAME );
  will_return( mock_add_message_replied_callback, true);

  expect_value( mock_add_periodic_event_callback, seconds, 60 );
  expect_value( mock_add_periodic_event_callback, user_data, NULL );
  will_return( mock_add_periodic_event_callback, true);

  assert_true( start_service_management() );

  stop_service_management();
  finalize_service_management();
}

//void notify_switch_status_for_all_user( sw_entry *sw );
static void
test_notify_switch_status_for_all_user() {

  init_messenger( "/tmp" );
  init_timer();
  assert_true( add_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;


  notify_switch_status_for_all_user( &sw );

  expect_value( mock_switch_status_notification, dpid, 0x1234);
  expect_value( mock_switch_status_notification, status, TD_SWITCH_UP );


  start_event_handler();
  start_messenger();

  assert_true( delete_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  finalize_timer();
  finalize_messenger();
}


//void notify_port_status_for_all_user( port_entry *port );
static void
test_notify_port_status_for_all_user() {

  init_messenger( "/tmp" );
  init_timer();
  assert_true( add_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;
  port_entry port = {
      .sw = &sw,
      .port_no = 42,
      .name = "Some port name",
      .mac = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06 },
      .up = true,
      .external = false,
  };

  notify_port_status_for_all_user( &port );

  expect_value( mock_port_status_notification, dpid, 0x1234 );
  expect_value( mock_port_status_notification, port_no, 42 );

  expect_string( mock_port_status_notification, name, "Some port name" );
  expect_memory( mock_port_status_notification, mac, port.mac, ETH_ADDRLEN );
  expect_value( mock_port_status_notification, external, TD_PORT_INACTIVE );

  expect_value( mock_port_status_notification, status, TD_PORT_UP );


  start_event_handler();
  start_messenger();

  assert_true( delete_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  finalize_timer();
  finalize_messenger();
}


//void notify_link_status_for_all_user( port_entry *port );
static void
test_notify_link_status_for_all_user() {

  init_messenger( "/tmp" );
  init_timer();
  assert_true( add_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;

  link_to link = {
      .datapath_id = 0x5678,
      .port_no = 72,
      .up = true
  };

  port_entry port = {
      .sw = &sw,
      .port_no = 42,
      .name = "Some port name",
      .mac = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06 },
      .up = true,
      .external = false,
      .link_to = &link,
  };

  notify_link_status_for_all_user( &port );

  expect_value( mock_link_status_notification, from_dpid, 0x1234 );
  expect_value( mock_link_status_notification, from_portno, 42 );

  expect_value( mock_link_status_notification, to_dpid, 0x5678 );
  expect_value( mock_link_status_notification, to_portno, 72 );

  expect_value( mock_link_status_notification, status, TD_LINK_UP );


  start_event_handler();
  start_messenger();

  assert_true( delete_message_received_callback( TEST_SUBSCRIBER_NAME, callback_fake_libtopology_client_notification_end ) );

  finalize_timer();
  finalize_messenger();
}


//bool set_link_status_updated_hook( link_status_updated_hook, void *user_data );
static void
local_link_status_updated_handler( void *user_data, const port_entry *port ) {
  check_expected( user_data );

  const sw_entry* sw = port->sw;
  check_expected( sw );

  const uint16_t port_no = port->port_no;
  check_expected( port_no );

  const char* name = port->name;
  check_expected( name );

  const uint8_t* mac = port->mac;
  check_expected( mac );

  const bool up = port->up;
  check_expected( up );

  const bool external = port->external;
  check_expected( external );

  assert( port->link_to != NULL );

  const uint64_t link_dpid = port->link_to->datapath_id;
  check_expected( link_dpid );

  const uint16_t link_port_no = port->link_to->port_no;
  check_expected( link_port_no );

  const bool link_up = port->link_to->up;
  check_expected( link_up );
}

static void
test_set_link_status_updated_hook() {
  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;

  link_to link = {
      .datapath_id = 0x5678,
      .port_no = 72,
      .up = true
  };

  port_entry port = {
      .sw = &sw,
      .port_no = 42,
      .name = "Some port name",
      .mac = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06 },
      .up = true,
      .external = false,
      .link_to = &link,
  };

  assert_true( set_link_status_updated_hook( local_link_status_updated_handler, NULL ) );

  expect_value( local_link_status_updated_handler, user_data, NULL );

  expect_not_value( local_link_status_updated_handler, sw, NULL );
  expect_value( local_link_status_updated_handler, port_no, 42 );
  expect_string( local_link_status_updated_handler, name, "Some port name" );
  expect_memory( local_link_status_updated_handler, mac, port.mac, ETH_ADDRLEN );
  expect_value( local_link_status_updated_handler, up, true );
  expect_value( local_link_status_updated_handler, external, false );

  expect_value( local_link_status_updated_handler, link_dpid, 0x5678 );
  expect_value( local_link_status_updated_handler, link_port_no, 72 );
  expect_value( local_link_status_updated_handler, link_up, true );

  notify_link_status_for_all_user( &port );
}


//bool set_port_status_updated_hook( port_status_updated_hook, void *user_data );
static void
local_port_status_updated_handler( void *user_data, const port_entry *port ) {
  check_expected( user_data );

  const sw_entry* sw = port->sw;
  check_expected( sw );

  const uint16_t port_no = port->port_no;
  check_expected( port_no );

  const char* name = port->name;
  check_expected( name );

  const uint8_t* mac = port->mac;
  check_expected( mac );

  const bool up = port->up;
  check_expected( up );

  const bool external = port->external;
  check_expected( external );
}

static void
test_set_port_status_updated_hook() {
  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;
  port_entry port = {
      .sw = &sw,
      .port_no = 42,
      .name = "Some port name",
      .mac = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06 },
      .up = true,
      .external = false,
  };

  assert_true( set_port_status_updated_hook( local_port_status_updated_handler, NULL ) );

  expect_value( local_port_status_updated_handler, user_data, NULL );

  expect_not_value( local_port_status_updated_handler, sw, NULL );
  expect_value( local_port_status_updated_handler, port_no, 42 );
  expect_string( local_port_status_updated_handler, name, "Some port name" );
  expect_memory( local_port_status_updated_handler, mac, port.mac, ETH_ADDRLEN );
  expect_value( local_port_status_updated_handler, up, true );
  expect_value( local_port_status_updated_handler, external, false );

  notify_port_status_for_all_user( &port );
}

//bool set_switch_status_updated_hook( switch_status_updated_hook, void *user_data );
static void
local_switch_status_updated_handler( void *user_data, const sw_entry *sw ) {
  check_expected( user_data );

  const uint64_t datapath_id = sw->datapath_id;
  check_expected( datapath_id );

  const bool up = sw->up;
  check_expected( up );
}

static void
test_set_switch_status_updated_hook() {
  sw_entry sw;
  sw.datapath_id = 0x1234;
  sw.up = true;

  assert_true( set_switch_status_updated_hook( local_switch_status_updated_handler, NULL ) );

  expect_value( local_switch_status_updated_handler, user_data, NULL );
  expect_value( local_switch_status_updated_handler, datapath_id, 0x1234 );
  expect_value( local_switch_status_updated_handler, up, true );
  notify_switch_status_for_all_user( &sw );
}

//uint8_t set_discovered_link_status( topology_update_link_status* link_status );

/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
      unit_test( test_init_finalize_service_management ),
      unit_test_setup_teardown( test_init_start_stop_finalize_service_management, setup, teardown ),

      unit_test_setup_teardown( test_notify_switch_status_for_all_user, setup_fake_subscriber, teardown_fake_subscriber ),
      unit_test_setup_teardown( test_notify_port_status_for_all_user, setup_fake_subscriber, teardown_fake_subscriber ),
      unit_test_setup_teardown( test_notify_link_status_for_all_user, setup_fake_subscriber, teardown_fake_subscriber ),

      unit_test( test_set_switch_status_updated_hook ),
      unit_test( test_set_port_status_updated_hook ),
      unit_test( test_set_link_status_updated_hook ),
  };

  setup_leak_detector();
  return run_tests( tests );
}

