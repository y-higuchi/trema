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
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <netinet/in.h>
#include "trema.h"
#include "libtopology.h"

static char *libtopology_queue_name = NULL;
static char *topology_name = NULL;


static void ( *link_status_updated_callback )( void *,
                                               const topology_link_status * ) = NULL;
static void *link_status_updated_callback_param = NULL;

static void ( *port_status_updated_callback )( void *,
                                              const topology_port_status * ) = NULL;
static void *port_status_updated_callback_param = NULL;

static void ( *switch_status_updated_callback )( void *, const topology_switch_status* ) = NULL;
static void *switch_status_updated_callback_param = NULL;

static hash_table *transaction_table = NULL;

static bool is_subscribed = false;

struct send_request_param {
  void ( *callback )();
  void *user_data;
  uint32_t transaction_id;
  uint16_t message_type;
  struct timeval called_at;
};


static buffer*
create_request_message( const char *name ) {
  size_t req_len = strlen( name ) + 1;
  buffer *buf = alloc_buffer_with_length( req_len );
  topology_request *req = append_back_buffer( buf, req_len );
  strcpy( req->name, name );
  return buf;
}


static uint32_t
get_request_transaction_id() {
  static uint32_t transaction_id = 0;

  return transaction_id++;
}


static void
mark_transaction( struct send_request_param *param, uint16_t message_type ) {
  gettimeofday( &param->called_at, NULL );
  param->transaction_id = get_request_transaction_id();
  param->message_type = message_type;
  void *duplicated = insert_hash_entry( transaction_table, &param->transaction_id, param );
  assert( duplicated == NULL );
}


static void
unmark_transaction( struct send_request_param *param ) {
  void *deleted = delete_hash_entry( transaction_table, &param->transaction_id );
  assert( deleted != NULL );
}


static struct send_request_param *
create_request_param( void ( *callback )(), void *user_data ) {
  struct send_request_param *param = xmalloc( sizeof( *param ) );
  param->callback = callback;
  param->user_data = user_data;

  return param;
}


static bool
send_request( uint16_t message_type, void ( *callback )(), void *user_data ) {
  // register transaction and continuation
  // make request header
  buffer *buf = create_request_message( libtopology_queue_name );

  void *param = create_request_param( callback, user_data );
  mark_transaction( param, message_type );

  bool ret = send_request_message( topology_name, libtopology_queue_name,
                              message_type, buf->data, buf->length,
                              param );

  if ( !ret ) {
    warn("Failed to send a request message %d to %s.", message_type, topology_name);
    xfree( param );
  }
  free_buffer( buf );
  return ret;
}


static buffer *
create_update_link_status_message( const topology_update_link_status *link_status ) {
  buffer *buf = alloc_buffer_with_length( sizeof( topology_update_link_status ) );
  topology_update_link_status *req = append_back_buffer( buf, sizeof( topology_update_link_status ) );

  req->from_dpid = htonll( link_status->from_dpid );
  req->from_portno = htons( link_status->from_portno );
  req->to_dpid = htonll( link_status->to_dpid );
  req->to_portno = htons( link_status->to_portno );
  req->status = link_status->status;

  return buf;
}


static bool
send_update_link_status( const topology_update_link_status *link_status,
                         void ( *callback )(), void *user_data ) {
  // register transaction and continuation
  // make request header
  buffer *buf = create_update_link_status_message( link_status );

  struct send_request_param *param = create_request_param( callback, user_data );
  mark_transaction( param, TD_MSGTYPE_UPDATE_LINK_STATUS_REQUEST );

  bool ret = send_request_message( topology_name, libtopology_queue_name,
                              TD_MSGTYPE_UPDATE_LINK_STATUS_REQUEST,
                              buf->data, buf->length, param );

  if ( !ret ) {
    warn( "Failed to send a set link status request to %s.", topology_name );
    xfree( param );
  }
  free_buffer( buf );

  return ret;
}


// handle reply from topology
static void
recv_query_link_status_reply( uint16_t tag,
                              void *data, size_t len,
                              void *param0 ) {
  UNUSED( tag );
  topology_link_status *const link_status = data;
  const int number_of_links =( int ) ( len / sizeof( topology_link_status ) );
  int i;
  struct send_request_param *param = param0;

  if ( param->callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
  } else {
    // rearrange byte order
    for ( i = 0; i < number_of_links; i++ ) {
      topology_link_status *s = &link_status[ i ];
      s->from_dpid = ntohll( s->from_dpid );
      s->from_portno = ntohs( s->from_portno );
      s->to_dpid = ntohll( s->to_dpid );
      s->to_portno = ntohs( s->to_portno );
    }

    // rebuild link topology
    ( *param->callback )( param->user_data, number_of_links, link_status );
  }
  xfree( param );
}


// handle reply from topology
static void
recv_query_port_status_reply( uint16_t tag,
                              void *data, size_t len,
                              void *param0 ) {
  UNUSED( tag );
  topology_port_status *const port_status = data;
  const int number_of_ports =( int ) ( len / sizeof( topology_port_status ) );
  int i;
  struct send_request_param *param = param0;

  if ( param->callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
  } else {
    // rearrange byte order
    for ( i = 0; i < number_of_ports; i++ ) {
      topology_port_status *s = &port_status[ i ];
      s->dpid = ntohll( s->dpid );
      s->port_no = ntohs( s->port_no );
    }

    // rebuild link topology
    ( *param->callback )( param->user_data, number_of_ports, port_status );
  }
  xfree( param );
}


// handle reply from topology
static void
recv_query_switch_status_reply( uint16_t tag,
                                void *data, size_t len, void *param0 ) {
  UNUSED( tag );
  topology_switch_status *const switch_status = data;
  const int number_of_ports = ( int ) ( len / sizeof( topology_switch_status ) );
  int i;
  struct send_request_param *param = param0;

  if ( param->callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
  } else {
    // rearrange byte order
    for ( i = 0; i < number_of_ports; i++ ) {
      topology_switch_status *s = &switch_status[ i ];
      s->dpid = ntohll( s->dpid );
    }

    // rebuild link topology
    ( *param->callback )( param->user_data, number_of_ports, switch_status );
  }
  xfree( param );
}


// handle asynchronouse notification from topology
static void
recv_link_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  topology_link_status *const link_status = data;
  const int number_of_links = ( int ) ( len / sizeof( topology_link_status ) );
  int i;

  if ( link_status_updated_callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
    return;
  }

  // (re)build topology db
  for ( i = 0; i < number_of_links; i++ ) {
    topology_link_status *s = &link_status[ i ];
    s->from_dpid = ntohll( s->from_dpid );
    s->from_portno = ntohs( s->from_portno );
    s->to_dpid = ntohll( s->to_dpid );
    s->to_portno = ntohs( s->to_portno );

    // TODO update link cache when implementing Topology cache in C

    ( *link_status_updated_callback )( link_status_updated_callback_param, s );
  }
}


// handle asynchronouse notification from topology
static void
recv_port_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  UNUSED( len );
  topology_port_status *const port_status = data;

  if ( port_status_updated_callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
    return;
  }

  // arrange byte order
  topology_port_status *s = port_status;
  s->dpid = ntohll( s->dpid );
  s->port_no = ntohs( s->port_no );

  // TODO update port cache when implementing Topology cache in C

  // (re)build port db
  ( *port_status_updated_callback )( port_status_updated_callback_param, s );
}

static void
recv_switch_status_notification( uint16_t tag, void *data, size_t len ) {
  UNUSED( tag );
  UNUSED( len );
  topology_switch_status* switch_status = data;

  if( switch_status_updated_callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
    return;
  }

  // arrange byte order
  switch_status->dpid = ntohll( switch_status->dpid );

  // TODO update switch cache when implementing Topology cache in C

  (* switch_status_updated_callback )( switch_status_updated_callback_param, switch_status );
}

static void
recv_ping_request( const messenger_context_handle *handle, void *data, size_t len ) {
  UNUSED( len );
  UNUSED( data );

//  topology_request *req = data;

  // respond to topology ping
  const size_t name_bytes = strlen( libtopology_queue_name ) + 1;
  const size_t req_len = sizeof(topology_ping_response) + name_bytes;

  buffer *buf = alloc_buffer_with_length( req_len );
  topology_ping_response *res = append_back_buffer( buf, req_len );
  strncpy( res->name, libtopology_queue_name, name_bytes );
//  assert( res->name[name_bytes] == '\0' );

  bool ret = send_reply_message( handle, TD_MSGTYPE_PING_RESPONSE,
                      buf->data, buf->length );
  if ( !ret ) {
    warn( "Failed to respond to ping from topology. %d" );
  }
  free_buffer( buf );
}

static void
recv_topology_response( uint16_t tag, void *data, size_t len, void *param0 ) {
  UNUSED( tag );
  if( len < sizeof(topology_response) ) {
    error( "Invalid data length. (tag=0x%x len=%zu, where > %zu expected)", tag, len, sizeof(topology_response) );
    return;
  }
  topology_response *res = data;
  struct send_request_param *param = param0;

  if( res->status != TD_RESPONSE_OK ){
    warn( "Response other than TD_RESPONSE_OK received. (tag=0x%x, status=0x%x)", tag, res->status );
  }

  if ( param->callback == NULL ) {
    debug( "%s: callback is NULL", __FUNCTION__ );
  } else {
    ( *param->callback )( param->user_data, res );
  }
  xfree( param );
}

static void
recv_subscribe_reply( uint16_t tag, void *data, size_t len, void *param0 ) {
  UNUSED( tag );
  topology_response *res = data;

  if( res->status == TD_RESPONSE_OK ){
    is_subscribed = true;
  }else{
    error( "Failed to subscribe. (status=0x%x)", (int)res->status );
  }

  recv_topology_response(tag, data, len, param0);
}

static void
recv_unsubscribe_reply( uint16_t tag, void *data, size_t len, void *param0 ) {
  UNUSED( tag );
  topology_response *res = data;

  if( res->status == TD_RESPONSE_OK ){
    is_subscribed = false;
  }else{
    error( "Failed to unsubscribe. (status=0x%x)", (int)res->status );
  }

  recv_topology_response(tag, data, len, param0);
}

bool
subscribe_topology( void ( *callback )( void *user_data, topology_response *res ), void *user_data ) {
  if( is_subscribed ){
      warn( "Already subscribed." );
  }
  return send_request( TD_MSGTYPE_SUBSCRIBE_REQUEST, callback, user_data );
}

bool
unsubscribe_topology( void ( *callback )( void *user_data, topology_response *res ), void *user_data ) {
  if( !is_subscribed ){
      warn( "Not subscribed." );
  }
  return send_request( TD_MSGTYPE_UNSUBSCRIBE_REQUEST, callback, user_data );
}

bool
enable_topology_discovery( void ( *callback )( void *user_data, topology_response *res ), void *user_data ) {
  return send_request( TD_MSGTYPE_ENABLE_DISCOVERY_REQUEST, callback, user_data );
}

bool
disable_topology_discovery( void ( *callback )( void *user_data, topology_response *res ), void *user_data ) {
  return send_request( TD_MSGTYPE_ENABLE_DISCOVERY_REQUEST, callback, user_data );
}


static void
recv_reply( uint16_t tag, void *data, size_t len, void *user_data ) {
  unmark_transaction( (struct send_request_param *)user_data );
  debug( "%s: 0x%x", __func__, (unsigned int)tag );

  switch ( tag ) {
  case TD_MSGTYPE_SUBSCRIBE_RESPONSE:
    recv_subscribe_reply( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_UNSUBSCRIBE_RESPONSE:
    recv_unsubscribe_reply( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_QUERY_LINK_STATUS_RESPONSE:
    recv_query_link_status_reply( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_QUERY_PORT_STATUS_RESPONSE:
    recv_query_port_status_reply( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_QUERY_SWITCH_STATUS_RESPONSE:
    recv_query_switch_status_reply( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_UPDATE_LINK_STATUS_RESPONSE:
    // nothing to do. using default handler.
    recv_topology_response( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_PING_RESPONSE:
    // TODO add handler for client -> server ping response
    recv_topology_response( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_ENABLE_DISCOVERY_RESPONSE:
    // nothing to do. using default handler.
    recv_topology_response( tag, data, len, user_data );
    break;

  case TD_MSGTYPE_DISABLE_DISCOVERY_RESPONSE:
    // nothing to do. using default handler.
    recv_topology_response( tag, data, len, user_data );
    break;

  default:
    error( "%s: Unknown message type: 0x%x", __func__, (unsigned int)tag );
    // TODO Should we call default handler for unknown tag?
    //  Not calling default handler may leak user_data,
    //  but calling default handler may seg fault if the message was completely corrupted.
    recv_topology_response( tag, data, len, user_data );
  }
}


static void
recv_status_notification( uint16_t tag, void *data, size_t len ) {
  debug( "%s: 0x%x", __func__, (unsigned int)tag );
  switch ( tag ) {
  case TD_MSGTYPE_LINK_STATUS_NOTIFICATION:
    recv_link_status_notification( tag, data, len );
    break;

  case TD_MSGTYPE_PORT_STATUS_NOTIFICATION:
    recv_port_status_notification( tag, data, len );
    break;

  case TD_MSGTYPE_SWITCH_STATUS_NOTIFICATION:
    recv_switch_status_notification( tag, data, len );
    break;

  default:
    warn( "%s: Unknown message type: 0x%x", __func__, (unsigned int)tag );
  }
}

static void
recv_request( const messenger_context_handle *handle,
              uint16_t tag, void *data, size_t len ) {
  debug( "%s: 0x%x", __func__, (unsigned int)tag );
  switch ( tag ) {
  case TD_MSGTYPE_PING_REQUEST:
    // ping: topology service -> libtopology
    recv_ping_request( handle, data, len );
    break;

  default:
    warn( "%s: Unknown message type: 0x%x", __func__, (unsigned int)tag );
    break;
  }
}

static void
check_transaction_table( void *user_data ) {
  hash_table *transaction_table = user_data;

  // TODO implement client -> server heart beat check here?

  hash_iterator iter;
  init_hash_iterator( transaction_table, &iter );
  hash_entry *e;
  while (( e = iterate_hash_next( &iter ) ) != NULL ) {
    struct send_request_param *param = e->value;
    warn( "Outstanding transaction still remains: 0x%#x", param->transaction_id );
    warn( " message type is 0x%x", param->message_type );
    char buf[ 32 ];
    warn( " called at %s", ctime_r( ( time_t * ) &param->called_at.tv_sec, buf ) );
  }
}


bool
init_libtopology( const char *service_name ) {
  if ( topology_name != NULL || libtopology_queue_name != NULL ) {
    debug( "already initialized" );
    return false;
  }

  topology_name = xstrdup( service_name );

  const size_t name_len = strlen( service_name ) + strlen( "-client-4294967295" ) + 1;
  libtopology_queue_name = xcalloc( 1, name_len );
  snprintf( libtopology_queue_name, name_len, "%s-client-%d",
            service_name, getpid() );

  add_message_replied_callback( libtopology_queue_name, recv_reply );
  add_message_received_callback( libtopology_queue_name, recv_status_notification );

  add_message_requested_callback( libtopology_queue_name, recv_request );

  transaction_table = create_hash( compare_uint32, hash_uint32 );
  add_periodic_event_callback( 60, check_transaction_table, transaction_table );

  return true;
}

bool
add_callback_switch_status_updated( void ( *callback )( void *user_data,
                                                           const topology_switch_status *link_status ),
                                                           void *user_data ) {

  switch_status_updated_callback = callback;
  switch_status_updated_callback_param = user_data;

  return true;
}


bool
add_callback_port_status_updated(
  void ( *callback )( void *, const topology_port_status * ), void *param ) {

  port_status_updated_callback = callback;
  port_status_updated_callback_param = param;

  return true;
}


bool
add_callback_link_status_updated(
  void ( *callback )( void *, const topology_link_status * ), void *param ) {

  link_status_updated_callback = callback;
  link_status_updated_callback_param = param;

  return true;
}


bool
finalize_libtopology() {
  xfree( topology_name );
  topology_name = NULL;
  delete_message_received_callback( libtopology_queue_name, recv_status_notification );
  delete_message_replied_callback( libtopology_queue_name, recv_reply );
  xfree( libtopology_queue_name );
  libtopology_queue_name = NULL;
  delete_timer_event( check_transaction_table, transaction_table );
  delete_hash( transaction_table );
  transaction_table = NULL;

  return true;
}


bool
get_all_link_status( void ( *callback )(), void *user_data ) {
  // send request message
  return send_request( TD_MSGTYPE_QUERY_LINK_STATUS_REQUEST, callback, user_data );
}


bool
get_all_port_status( void ( *callback )(), void *user_data ) {
  // send request message
  return send_request( TD_MSGTYPE_QUERY_PORT_STATUS_REQUEST, callback, user_data );
}


bool
get_all_switch_status( void ( *callback )(), void *user_data ) {
  // send request message
  return send_request( TD_MSGTYPE_QUERY_SWITCH_STATUS_REQUEST, callback, user_data );
}


bool
set_link_status( const topology_update_link_status *link_status,
                 void ( *callback )( void *user_data, topology_response *res ), void *user_data ) {
  // send request message
  return send_update_link_status( link_status, callback, user_data );
}


/*
 * Local variables:
 * c-basic-offset: 2
 * indent-tabs-mode: nil
 * End:
 */