/*
 * libtopology_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include <unistd.h>

#include "checks.h"
#include "cmockery_trema.h"

#include "libtopology.h"

#include "event_handler.h"
#include "messenger.h"



/********************************************************************************
 * Common function.
 ********************************************************************************/

#define TOPOLOGY_NAME "topo_test_service"
#define TOPOLOGY_CLIENT_NAME_BASE  TOPOLOGY_NAME "-client-"

/********************************************************************************
 * Mock functions.
 ********************************************************************************/

#define swap_original( funcname ) \
  original_##funcname = funcname;\
  funcname = mock_##funcname;

#define revert_original( funcname ) \
  funcname = original_##funcname;


static void ( *original_die )( const char *format, ... );
static void ( *original_error )( const char *format, ... );
static void ( *original_warn )( const char *format, ... );

static bool ( *original_add_message_received_callback )( const char *service_name, const callback_message_received function );
static bool ( *original_add_message_requested_callback )( const char *service_name, void ( *callback )( const messenger_context_handle *handle, uint16_t tag, void *data, size_t len ) );
static bool ( *original_add_message_replied_callback )( const char *service_name, void ( *callback )( uint16_t tag, void *data, size_t len, void *user_data ) );

static bool ( *original_add_periodic_event_callback )( const time_t seconds, timer_callback callback, void *user_data );

static bool ( *original_send_request_message)( const char *to_service_name, const char *from_service_name, const uint16_t tag, const void *data, size_t len, void *user_data );
static void
mock_die( const char *format, ... ) {
  UNUSED( format );
  mock_assert( false, "mock_die", __FILE__, __LINE__ ); } // Hoaxes gcov.


static void
mock_error( const char *format, ... ) {
  va_list args;
  va_start( args, format );
  char message[ 1000 ];
  vsprintf( message, format, args );
  va_end( args );

  check_expected( message );
}

static void
mock_warn( const char *format, ... ) {
  va_list args;
  va_start( args, format );
  char message[ 1000 ];
  vsprintf( message, format, args );
  va_end( args );

  check_expected( message );
}

static bool
mock_add_message_replied_callback( const char *service_name, void ( *callback )( uint16_t tag, void *data, size_t len, void *user_data ) ) {
  check_expected( service_name );
//  check_expected( callback );
  UNUSED( callback );
  return (bool)mock();
}

static bool
mock_add_message_received_callback( const char *service_name, const callback_message_received callback ) {
  check_expected( service_name );
//  check_expected( callback );
  UNUSED( callback );

  return ( bool ) mock();
}

static bool
mock_add_message_requested_callback( const char *service_name,
                                     void ( *callback )( const messenger_context_handle *handle, uint16_t tag, void *data, size_t len ) ) {
  check_expected( service_name );
  UNUSED( callback );
  return ( bool ) mock();
}

static bool
mock_add_periodic_event_callback( const time_t seconds, timer_callback callback, void *user_data ) {
  check_expected( seconds );
//  check_expected( callback );
  UNUSED( callback );
  check_expected( user_data );
  return ( bool ) mock();
}

static bool
mock_send_request_message( const char *to_service_name, const char *from_service_name, const uint16_t tag, const void *data, size_t len, void *user_data ) {
  uint32_t tag32 = tag;

  check_expected( to_service_name );
  check_expected( from_service_name );
  check_expected( tag32 );
  check_expected( data );
  check_expected( len );
  check_expected( user_data );

  return ( bool ) mock();
}

static void
mock_execute_timer_events( int *next_timeout_usec ) {
  UNUSED( next_timeout_usec );
  // Do nothing.
}

// helpers
static void
callback_get_all_link_status_end( void *user_data, size_t number, const topology_link_status *link_status ) {
  check_expected( user_data );
  check_expected( number );
  check_expected( link_status );

  stop_event_handler();
  stop_messenger();
}

static void
callback_get_all_port_status_end( void *user_data, size_t number, const topology_port_status *port_status ) {
  check_expected( user_data );
  check_expected( number );
  check_expected( port_status );

  stop_event_handler();
  stop_messenger();
}

static void
callback_get_all_switch_status_end( void *user_data, size_t number, const topology_switch_status *switch_status ) {
  check_expected( user_data );
  check_expected( number );
  check_expected( switch_status );

  stop_event_handler();
  stop_messenger();
}


static void
callback_topology_response( void *user_data, const topology_response *res ) {
  check_expected( user_data );
  check_expected( res );
}
static void
callback_topology_response_end( void *user_data, const topology_response *res ) {
  check_expected( user_data );
  check_expected( res );

  stop_event_handler();
  stop_messenger();
}
static void
callback_topology_response_no_const( void *user_data, topology_response *res ) {
  check_expected( user_data );
  check_expected( res );
}
static void
callback_topology_response_end_no_const( void *user_data, topology_response *res ) {
  check_expected( user_data );
  check_expected( res );

  stop_event_handler();
  stop_messenger();
}

static const topology_switch_status dummy_switch_status_up = {
    .dpid = 0x1234,
    .status = TD_SWITCH_UP,
};

static const topology_port_status dummy_port_status_up = {
    .dpid = 0x1234,
    .port_no = 42,
//           123456789012345
    .name = "port_name_maxln",
    .mac = {0xDE,0xAD,0xBE,0xEF,0xFF, 0xFE },
    .external = TD_PORT_EXTERNAL,
    .status = TD_PORT_UP,
};

static const topology_link_status dummy_link_status_up = {
    .from_dpid = 0x1234,
    .from_portno = 42,
    .to_dpid = 0x5678,
    .to_portno = 666,
    .status = TD_LINK_UP,
};

static const topology_response dummy_response_ok = {
    .status = TD_RESPONSE_OK,
};
static const topology_response dummy_response_already_subscribed = {
    .status = TD_RESPONSE_ALREADY_SUBSCRIBED,
};
static const topology_response dummy_response_no_such_subscriber = {
    .status = TD_RESPONSE_NO_SUCH_SUBSCRIBER,
};


static int
check_topology_link_status_equals( const LargestIntegralType val, const LargestIntegralType check_val ) {
  const topology_link_status* target = (const topology_link_status*)val;
  const topology_link_status* reference = (const topology_link_status*)check_val;

  if( !(target->from_dpid == reference->from_dpid) ) {
    print_error(".from_dpid:'%#" PRIx64 "' != '%#" PRIx64 "'\n", target->from_dpid, reference->from_dpid);
    return 0;
  }
  if( !(target->from_portno == reference->from_portno) ) {
    print_error(".from_portno:'%" PRId16 "' != '%" PRId16 "'\n", target->from_portno, reference->from_portno);
    return 0;
  }

  if( !(target->to_dpid == reference->to_dpid) ) {
    print_error(".to_dpid:'%#" PRIx64 "' != '%#" PRIx64 "'\n", target->to_dpid, reference->to_dpid);
    return 0;
  }
  if( !(target->to_portno == reference->to_portno) ) {
    print_error(".to_portno: '%" PRId16 "' != '%" PRId16 "'\n", target->from_portno, reference->from_portno);
    return 0;
  }
  if( !(target->status == reference->status) ) {
    print_error(".status: '%d' != '%d'\n", target->status, reference->status);
    return 0;
  }
  return 1;
}

static void
reset_messenger() {
  execute_timer_events = mock_execute_timer_events;
}

/********************************************************************************
 * Setup and teardown functions.
 ********************************************************************************/


static void
setup() {
//  swap_original( die );
//  swap_original( error );
//  swap_original( warn );

  swap_original( add_message_received_callback );
  swap_original( add_message_replied_callback );
  swap_original( add_message_requested_callback );

  swap_original( add_periodic_event_callback );

  swap_original( send_request_message );
}

static void
teardown() {
//  revert_original( die );
//  revert_original( error );
//  revert_original( warn );

  revert_original( add_message_received_callback );
  revert_original( add_message_replied_callback );
  revert_original( add_message_requested_callback );

  revert_original( add_periodic_event_callback );

  revert_original( send_request_message );
}

static void
init_libtopology_mock() {

  // init_libtopology internals
  expect_any( mock_add_message_replied_callback, service_name );
  will_return( mock_add_message_replied_callback, true);

  expect_any( mock_add_message_received_callback, service_name );
  will_return( mock_add_message_received_callback, true);

  expect_any( mock_add_message_requested_callback, service_name );
  will_return( mock_add_message_requested_callback, true);

  expect_any( mock_add_periodic_event_callback, seconds );
  expect_any( mock_add_periodic_event_callback, user_data );
  will_return( mock_add_periodic_event_callback, true);

  init_libtopology( TOPOLOGY_NAME );
}

static void
finalize_libtopology_mock() {
  finalize_libtopology();
}
/********************************************************************************
 * Tests.
 ********************************************************************************/


//bool init_libtopology( const char *topology_service_name );
static void
test_init_libtopology() {
  const char* topology_name = TOPOLOGY_NAME;
  const char* topology_client_name_base = TOPOLOGY_CLIENT_NAME_BASE;
  char* topology_client_name = xcalloc( 1, strlen(topology_client_name_base) + (size_t)(ceil(log10(INT_MAX))) + 1 );

  sprintf( topology_client_name, TOPOLOGY_CLIENT_NAME_BASE "%d", getpid() );

  expect_string( mock_add_message_replied_callback, service_name, topology_client_name);
  will_return( mock_add_message_replied_callback, true);

  expect_string( mock_add_message_received_callback, service_name, topology_client_name);
  will_return( mock_add_message_received_callback, true);

  expect_string( mock_add_message_requested_callback, service_name, topology_client_name);
  will_return( mock_add_message_requested_callback, true);

  // don't care
  expect_any( mock_add_periodic_event_callback, seconds );
  expect_any( mock_add_periodic_event_callback, user_data );
  will_return( mock_add_periodic_event_callback, true);

  bool result = init_libtopology( topology_name );
  assert_true( result );

  // cleanup
  finalize_libtopology_mock();

  xfree( topology_client_name );
}

//bool finalize_libtopology( void );

//bool subscribe_topology( void ( *callback )( void *user_data, topology_response *res ), void *user_data );
static void
test_subscribe_topology() {
  init_libtopology_mock();

  expect_string( mock_send_request_message, to_service_name, TOPOLOGY_NAME );
  expect_memory( mock_send_request_message, from_service_name, TOPOLOGY_CLIENT_NAME_BASE, strlen(TOPOLOGY_CLIENT_NAME_BASE) );
  expect_value( mock_send_request_message, tag32, TD_MSGTYPE_SUBSCRIBE_REQUEST );
  expect_any( mock_send_request_message, data );
  expect_any( mock_send_request_message, len );
//  expect_value( mock_send_request_message, user_data, user_data );
  expect_any( mock_send_request_message, user_data );
  will_return( mock_send_request_message, true );

  bool result = subscribe_topology( NULL, NULL );
  assert_true( result );

  finalize_libtopology_mock();
}

static bool test_is_subscribed = false;
static void
helper_respond_subscribe( const messenger_context_handle *handle, uint16_t tag,
                          void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  assert_true( tag == TD_MSGTYPE_SUBSCRIBE_REQUEST );

  buffer *reply = alloc_buffer_with_length( sizeof( topology_response ) );
  topology_response *response = append_back_buffer( reply, sizeof( topology_response ) );
  memset( response, 0, sizeof( topology_response ) );

  if( test_is_subscribed ) {
    response->status = TD_RESPONSE_ALREADY_SUBSCRIBED;
  } else {
    response->status = TD_RESPONSE_OK;
    test_is_subscribed = true;
  }

  send_reply_message( handle, TD_MSGTYPE_SUBSCRIBE_RESPONSE,
                      reply->data, reply->length );
  free_buffer( reply );
}

static void
test_duplicate_subscribe_topology() {

  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding ok response
  test_is_subscribed = false;
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_subscribe ) );

  void* user_data = (void*)0x1234;
  bool result = false;
  expect_value( callback_topology_response_no_const, user_data, user_data );
  expect_memory( callback_topology_response_no_const, res, &dummy_response_ok, sizeof(dummy_response_ok) );

  result = subscribe_topology( callback_topology_response_no_const, user_data );
  assert_true( result );

  expect_value( callback_topology_response_end_no_const, user_data, user_data );
  expect_memory( callback_topology_response_end_no_const, res, &dummy_response_already_subscribed, sizeof(dummy_response_already_subscribed) );

  result = subscribe_topology( callback_topology_response_end_no_const, user_data );
  assert_true( result );


  // start pump
  start_messenger();
  start_event_handler();

  // remove dummy topology service responding ok response
  test_is_subscribed = false;
  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_subscribe ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}


//bool unsubscribe_topology( void ( *callback )( void *user_data, topology_response *res ), void *user_data );
static void
test_unsubscribe_topology() {
  init_libtopology_mock();

  void* user_data = (void*)0x1234;

  expect_string( mock_send_request_message, to_service_name, TOPOLOGY_NAME );
  expect_memory( mock_send_request_message, from_service_name, TOPOLOGY_CLIENT_NAME_BASE, strlen(TOPOLOGY_CLIENT_NAME_BASE) );
  expect_value( mock_send_request_message, tag32, TD_MSGTYPE_UNSUBSCRIBE_REQUEST );
  expect_any( mock_send_request_message, data );
  expect_any( mock_send_request_message, len );
//  expect_value( mock_send_request_message, user_data, user_data );
  expect_any( mock_send_request_message, user_data );
  will_return( mock_send_request_message, true );

  bool result = unsubscribe_topology( NULL, user_data );
  assert_true( result );

  finalize_libtopology_mock();
}

static bool test_is_unsubscribed = false;
static void
helper_respond_unsubscribe( const messenger_context_handle *handle, uint16_t tag,
                          void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  assert_true( tag == TD_MSGTYPE_UNSUBSCRIBE_REQUEST );

  buffer *reply = alloc_buffer_with_length( sizeof( topology_response ) );
  topology_response *response = append_back_buffer( reply, sizeof( topology_response ) );
  memset( response, 0, sizeof( topology_response ) );

  if( test_is_unsubscribed ) {
    response->status = TD_RESPONSE_NO_SUCH_SUBSCRIBER;
  } else {
    response->status = TD_RESPONSE_OK;
    test_is_unsubscribed = true;
  }

  send_reply_message( handle, TD_MSGTYPE_UNSUBSCRIBE_RESPONSE,
                      reply->data, reply->length );
  free_buffer( reply );
}


static void
test_duplicate_unsubscribe_topology() {

  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding ok response
  test_is_subscribed = false;
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_unsubscribe ) );

  void* user_data = (void*)0x1234;
  bool result = false;
  expect_value( callback_topology_response_no_const, user_data, user_data );
  expect_memory( callback_topology_response_no_const, res, &dummy_response_ok, sizeof(dummy_response_ok) );

  result = unsubscribe_topology( callback_topology_response_no_const, user_data );
  assert_true( result );

  expect_value( callback_topology_response_end_no_const, user_data, user_data );
  expect_memory( callback_topology_response_end_no_const, res, &dummy_response_no_such_subscriber, sizeof(dummy_response_no_such_subscriber) );

  result = unsubscribe_topology( callback_topology_response_end_no_const, user_data );
  assert_true( result );


  // start pump
  start_messenger();
  start_event_handler();

  // remove dummy topology service responding ok response
  test_is_subscribed = false;
  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_unsubscribe ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

//bool add_callback_switch_status_updated( void ( *callback )( void *user_data,
//                                                             const topology_switch_status *switch_status ),
//                                         void *user_data );
static void
handle_switch_status_updated_end( void *user_data, const topology_switch_status *switch_status ) {
  check_expected( user_data );
  check_expected( switch_status );

  stop_event_handler();
  stop_messenger();
}
static void
handle_link_status_updated_end( void *user_data, const topology_link_status *link_status ) {
  check_expected( user_data );
  check_expected( link_status );

  stop_event_handler();
  stop_messenger();
}
static void
handle_port_status_updated_end( void *user_data, const topology_port_status *port_status ) {
  check_expected( user_data );
  check_expected( port_status );

  stop_event_handler();
  stop_messenger();
}

static void
test_add_callback_switch_status_updated() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  void* user_data = (void*)0x1234;

  const char* topology_client_name_base = TOPOLOGY_CLIENT_NAME_BASE;
  char* topology_client_name = xcalloc( 1, strlen(topology_client_name_base) + (size_t)(ceil(log10(INT_MAX))) + 1 );
  sprintf( topology_client_name, TOPOLOGY_CLIENT_NAME_BASE "%d", getpid() );

  expect_value( handle_switch_status_updated_end, user_data, user_data );
  expect_memory( handle_switch_status_updated_end, switch_status, &dummy_switch_status_up, sizeof(dummy_switch_status_up) );
  assert_true( add_callback_switch_status_updated( handle_switch_status_updated_end, user_data ) );

  // create dummy topology service sending event
  buffer* buf = alloc_buffer_with_length( sizeof( topology_switch_status ) );
  topology_switch_status* status = append_back_buffer( buf, sizeof( topology_switch_status ) );
  memset( status, 0, sizeof( topology_switch_status ) );

  status->dpid = htonll( dummy_switch_status_up.dpid );
  status->status = dummy_switch_status_up.status;
  assert_true( send_message( topology_client_name, TD_MSGTYPE_SWITCH_STATUS_NOTIFICATION,
                buf->data, buf->length ) );
  free_buffer( buf );

  // start pump
  start_messenger();
  start_event_handler();

  xfree( topology_client_name );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

//bool add_callback_link_status_updated( void ( *callback )( void *user_data,
//                                                           const topology_link_status *link_status ),
//                                       void *user_data );
static void
test_add_callback_link_status_updated() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  void* user_data = (void*)0x1234;

  const char* topology_client_name_base = TOPOLOGY_CLIENT_NAME_BASE;
  char* topology_client_name = xcalloc( 1, strlen(topology_client_name_base) + (size_t)(ceil(log10(INT_MAX))) + 1 );
  sprintf( topology_client_name, TOPOLOGY_CLIENT_NAME_BASE "%d", getpid() );

  expect_value( handle_link_status_updated_end, user_data, user_data );
  expect_memory( handle_link_status_updated_end, link_status, &dummy_link_status_up, sizeof(dummy_link_status_up) );
  assert_true( add_callback_link_status_updated( handle_link_status_updated_end, user_data ) );

  // create dummy topology service sending event
  buffer* buf = alloc_buffer_with_length( sizeof( topology_link_status ) );
  topology_link_status* status = append_back_buffer( buf, sizeof( topology_link_status ) );
  memset( status, 0, sizeof( topology_link_status ) );

  status->from_dpid = htonll( dummy_link_status_up.from_dpid );
  status->from_portno = htons( dummy_link_status_up.from_portno );
  status->to_dpid = htonll( dummy_link_status_up.to_dpid );
  status->to_portno = htons( dummy_link_status_up.to_portno );
  status->status = dummy_link_status_up.status;
  assert_true( send_message( topology_client_name, TD_MSGTYPE_LINK_STATUS_NOTIFICATION,
               buf->data, buf->length ) );
  free_buffer( buf );

  // start pump
  start_messenger();
  start_event_handler();

  xfree( topology_client_name );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

//bool add_callback_port_status_updated( void ( *callback )( void *user_data,
//                                                           const topology_port_status *port_status ),
//                                       void *user_data );
static void
test_add_callback_port_status_updated() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  void* user_data = (void*)0x1234;

  const char* topology_client_name_base = TOPOLOGY_CLIENT_NAME_BASE;
  char* topology_client_name = xcalloc( 1, strlen(topology_client_name_base) + (size_t)(ceil(log10(INT_MAX))) + 1 );
  sprintf( topology_client_name, TOPOLOGY_CLIENT_NAME_BASE "%d", getpid() );

  expect_value( handle_port_status_updated_end, user_data, user_data );
  expect_memory( handle_port_status_updated_end, port_status, &dummy_port_status_up, sizeof(dummy_port_status_up) );
  assert_true( add_callback_port_status_updated( handle_port_status_updated_end, user_data ) );

  // create dummy topology service sending event
  buffer* buf = alloc_buffer_with_length( sizeof( topology_port_status ) );
  topology_port_status* status = append_back_buffer( buf, sizeof( topology_port_status ) );
  memset( status, 0, sizeof( topology_port_status ) );

  status->dpid = htonll( dummy_port_status_up.dpid );
  status->port_no = htons( dummy_port_status_up.port_no );
  memcpy( status->name, dummy_port_status_up.name, sizeof( dummy_port_status_up.name ) );
  memcpy( status->mac, dummy_port_status_up.mac, sizeof( dummy_port_status_up.mac ) );
  status->external = dummy_port_status_up.external;
  status->status = dummy_port_status_up.status;
  assert_true( send_message( topology_client_name, TD_MSGTYPE_PORT_STATUS_NOTIFICATION,
               buf->data, buf->length ) );
  free_buffer( buf );

  // start pump
  start_messenger();
  start_event_handler();

  xfree( topology_client_name );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}
//bool get_all_link_status( void ( *callback )( void *user_data, size_t number,
//                                              const topology_link_status *link_status ),
//                          void *user_data );
static void
helper_respond_1_link( const messenger_context_handle *handle, uint16_t tag,
                       void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  assert_true( tag == TD_MSGTYPE_QUERY_LINK_STATUS_REQUEST );

  buffer *reply = alloc_buffer_with_length( 2048 );

  topology_link_status *status = NULL;
  status = append_back_buffer( reply, sizeof( topology_link_status ) );
  // zero clear including padding area to enable use of expect_memory checking
  memset( status, 0, sizeof( topology_link_status ) );

  status->from_dpid = htonll( dummy_link_status_up.from_dpid );
  status->from_portno = htons( dummy_link_status_up.from_portno );
  status->to_dpid = htonll( dummy_link_status_up.to_dpid );
  status->to_portno = htons( dummy_link_status_up.to_portno );
  status->status = dummy_link_status_up.status;

  send_reply_message( handle, TD_MSGTYPE_QUERY_LINK_STATUS_RESPONSE,
                      reply->data, reply->length );
  free_buffer( reply );
}

static void
test_get_all_link_status() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding 1 topology
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_link ) );


  void* user_data = (void*)0x1234;

  expect_value( callback_get_all_link_status_end, user_data, user_data );
  expect_value( callback_get_all_link_status_end, number, 1 );
//  expect_check( callback_get_all_link_status_end, link_status, check_topology_link_status_equals, &dummy_link_up );
//  expect_value( callback_get_all_link_status_end, link_status, &dummy_link_up );
  expect_memory( callback_get_all_link_status_end, link_status, &dummy_link_status_up, sizeof(dummy_link_status_up) );
  UNUSED( check_topology_link_status_equals );

  bool result = get_all_link_status( callback_get_all_link_status_end, user_data );
  assert_true( result );

  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_link ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}
//bool get_all_port_status( void ( *callback )( void *user_data, size_t number,
//                                              const topology_port_status *port_status ),
//                          void *user_data );
static void
helper_respond_1_port( const messenger_context_handle *handle, uint16_t tag,
                       void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  assert_true( tag == TD_MSGTYPE_QUERY_PORT_STATUS_REQUEST );

  buffer *reply = alloc_buffer_with_length( 2048 );

  topology_port_status *status = NULL;
  status = append_back_buffer( reply, sizeof( topology_port_status ) );
  // zero clear including padding area to enable use of expect_memory checking
  memset( status, 0, sizeof( topology_port_status ) );

  status->dpid = htonll( dummy_port_status_up.dpid );
  status->port_no = htons( dummy_port_status_up.port_no );
  memcpy( status->name, dummy_port_status_up.name, sizeof( dummy_port_status_up.name ) );
  memcpy( status->mac, dummy_port_status_up.mac, sizeof( dummy_port_status_up.mac ) );
  status->external = dummy_port_status_up.external;
  status->status = dummy_port_status_up.status;

  send_reply_message( handle, TD_MSGTYPE_QUERY_PORT_STATUS_RESPONSE,
                      reply->data, reply->length );
  free_buffer( reply );
}
static void
test_get_all_port_status() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding 1 topology
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_port ) );

  void* user_data = (void*)0x1234;

  expect_value( callback_get_all_port_status_end, user_data, user_data );
  expect_value( callback_get_all_port_status_end, number, 1 );
  expect_memory( callback_get_all_port_status_end, port_status, &dummy_port_status_up, sizeof(dummy_port_status_up) );

  bool result = get_all_port_status( callback_get_all_port_status_end, user_data );
  assert_true( result );

  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_port ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

//bool get_all_switch_status( void ( *callback )( void *user_data, size_t number,
//                                                const topology_switch_status *sw_status ),
//                            void *user_data );
static void
helper_respond_1_switch( const messenger_context_handle *handle, uint16_t tag,
                       void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  assert_true( tag == TD_MSGTYPE_QUERY_SWITCH_STATUS_REQUEST );

  buffer *reply = alloc_buffer_with_length( 2048 );

  topology_switch_status *status = NULL;
  status = append_back_buffer( reply, sizeof( topology_switch_status ) );
  // zero clear including padding area to enable use of expect_memory checking
  memset( status, 0, sizeof( topology_switch_status ) );

  status->dpid = htonll( dummy_switch_status_up.dpid );
  status->status = dummy_switch_status_up.status;

  send_reply_message( handle, TD_MSGTYPE_QUERY_SWITCH_STATUS_RESPONSE,
                      reply->data, reply->length );
  free_buffer( reply );
}
static void
test_get_all_switch_status() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding 1 topology
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_switch ) );

  void* user_data = (void*)0x1234;

  expect_value( callback_get_all_switch_status_end, user_data, user_data );
  expect_value( callback_get_all_switch_status_end, number, 1 );
  expect_memory( callback_get_all_switch_status_end, switch_status, &dummy_switch_status_up, sizeof(dummy_switch_status_up) );

  bool result = get_all_switch_status( callback_get_all_switch_status_end, user_data );
  assert_true( result );

  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_1_switch ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

/// will not test. Obsolete interface for discovery process
//bool set_link_status( const topology_update_link_status *link_status,
//                      void ( *callback )( void *user_data, topology_response *res ),
//                      void *user_data );


//bool enable_topology_discovery( void ( *callback )( void *user_data, topology_response *res ), void *user_data );
static void
helper_respond_topology_ok( const messenger_context_handle *handle, uint16_t tag,
                       void *data, size_t len ) {

  UNUSED( data );
  UNUSED( len );

  uint16_t response_tag;
  switch( tag ){
  case TD_MSGTYPE_ENABLE_DISCOVERY_REQUEST:
    response_tag = TD_MSGTYPE_ENABLE_DISCOVERY_RESPONSE;
    break;
  case TD_MSGTYPE_DISABLE_DISCOVERY_REQUEST:
    response_tag = TD_MSGTYPE_DISABLE_DISCOVERY_RESPONSE;
    break;
  default:
    assert(false);
    return;
  }
  assert_true( tag == TD_MSGTYPE_ENABLE_DISCOVERY_REQUEST );

  buffer *reply = alloc_buffer_with_length( sizeof(topology_response) );

  topology_response *status = NULL;
  status = append_back_buffer( reply, sizeof( topology_response ) );
  // zero clear including padding area to enable use of expect_memory checking
  memset( status, 0, sizeof( topology_response ) );

  status->status = dummy_response_ok.status;

  send_reply_message( handle, response_tag,
                      reply->data, reply->length );
  free_buffer( reply );
}
static void
test_enable_topology_discovery() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding ok response
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_topology_ok ) );

  void* user_data = (void*)0x1234;

  expect_value( callback_topology_response_end, user_data, user_data );
  expect_memory( callback_topology_response_end, res, &dummy_response_ok, sizeof(dummy_response_ok) );

  bool result = enable_topology_discovery( callback_topology_response_end, user_data );
  assert_true( result );

  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_topology_ok ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}
//bool disable_topology_discovery( void ( *callback )( void *user_data, topology_response *res ), void *user_data );
static void
test_disable_topology_discovery() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // create dummy topology service responding ok response
  assert_true( add_message_requested_callback( TOPOLOGY_NAME, helper_respond_topology_ok ) );

  void* user_data = (void*)0x1234;

  expect_value( callback_topology_response_end, user_data, user_data );
  expect_memory( callback_topology_response_end, res, &dummy_response_ok, sizeof(dummy_response_ok) );

  bool result = disable_topology_discovery( callback_topology_response_end, user_data );
  assert_true( result );

  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_requested_callback( TOPOLOGY_NAME, helper_respond_topology_ok ) );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}


static void
helper_ping_reply_end( uint16_t tag, void *data, size_t len, void *user_data ) {
  check_expected( tag );
  check_expected( data );
  check_expected( len );
  check_expected( user_data );

  stop_event_handler();
  stop_messenger();
}


static void
test_respond_to_ping_from_topology() {
  init_messenger( "/tmp" );
  init_timer();

  init_libtopology( TOPOLOGY_NAME );

  // receive ping reply from libtopology
  assert_true( add_message_replied_callback( TOPOLOGY_NAME, helper_ping_reply_end ) );

  void* user_data = (void*)0x1234;

  const char* topology_client_name_base = TOPOLOGY_CLIENT_NAME_BASE;
  char* topology_client_name = xcalloc( 1, strlen(topology_client_name_base) + (size_t)(ceil(log10(INT_MAX))) + 1 );
  sprintf( topology_client_name, TOPOLOGY_CLIENT_NAME_BASE "%d", getpid() );

  expect_value( helper_ping_reply_end, tag, TD_MSGTYPE_PING_RESPONSE );
  // data == topology_ping_response.name
  expect_string( helper_ping_reply_end, data, topology_client_name );
  expect_value( helper_ping_reply_end, len, strlen(topology_client_name)+1 );
  expect_value( helper_ping_reply_end, user_data, user_data );

  // create dummy topology service sending ping event
  buffer* buf = alloc_buffer_with_length( sizeof( topology_request ) + strlen(topology_client_name)+1  );
  topology_request* status = append_back_buffer( buf, sizeof( topology_request ) + strlen(topology_client_name)+1 );
  memset( status, 0, sizeof( topology_request ) );

  strcpy( status->name, topology_client_name);

  assert_true( send_request_message( topology_client_name, TOPOLOGY_NAME,TD_MSGTYPE_PING_REQUEST,
               buf->data, buf->length, user_data ) );
  free_buffer( buf );



  // start pump
  start_messenger();
  start_event_handler();

  assert_true( delete_message_replied_callback( TOPOLOGY_NAME, helper_ping_reply_end ) );


  xfree( topology_client_name );

  finalize_libtopology();

  finalize_timer();
  finalize_messenger();
}

/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
    unit_test_setup_teardown( test_init_libtopology,
                              setup, teardown ),
    unit_test_setup_teardown( test_subscribe_topology,
                              setup, teardown ),
    unit_test( test_duplicate_subscribe_topology ),
    unit_test_setup_teardown( test_unsubscribe_topology,
                              setup, teardown ),
    unit_test( test_duplicate_unsubscribe_topology ),
    unit_test( test_get_all_link_status ),
    unit_test( test_get_all_port_status ),
    unit_test( test_get_all_switch_status ),
    unit_test( test_enable_topology_discovery ),
    unit_test( test_disable_topology_discovery ),
    unit_test( test_add_callback_switch_status_updated ),
    unit_test( test_add_callback_link_status_updated ),
    unit_test( test_add_callback_port_status_updated ),
    unit_test( test_respond_to_ping_from_topology ),
  };
  UNUSED( test_duplicate_subscribe_topology );
  UNUSED( original_die );
  UNUSED( original_error );
  UNUSED( original_warn );
  UNUSED( mock_die );
  UNUSED( mock_error );
  UNUSED( mock_warn );
  UNUSED( reset_messenger );
  UNUSED( callback_topology_response );
  setup_leak_detector();
  return run_tests( tests );
}
