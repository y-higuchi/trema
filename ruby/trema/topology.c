/*
 * topology.c
 *
 *  Created on: 2012/11/20
 *      Author: y-higuchi
 */

#include "ruby.h"
#include "topology.h"

#include "libtopology.h"

#include <stdio.h>
#include <stdlib.h>

extern VALUE mTrema;
VALUE mTopology;


/*
 * init_libtopology(service_name)
 *   Initialize topology client.
 *
 *   This method is intended to be called implicitly by TopologyNotifiedController.
 *
 *   @param [String] service_name
 *     name of the topology service to use.
 */
static VALUE
topology_init_libtopology( VALUE self, VALUE service_name ) {
  init_libtopology( StringValuePtr( service_name ) );
  return self;
}


/*
 * finalize_libtopology(service_name)
 *   Finalize topology client.
 *
 *   This method is intended to be called implicitly by TopologyNotifiedController.
 */
static VALUE
topology_finalize_libtopology( VALUE self ) {
  finalize_libtopology();
  return self;
}

static VALUE
switch_status_to_hash( const topology_switch_status* sw_status ) {
  VALUE sw = rb_hash_new();
  rb_hash_aset( sw, ID2SYM( rb_intern( "dpid" ) ), ULL2NUM( sw_status->dpid ) );
  rb_hash_aset( sw, ID2SYM( rb_intern( "status" ) ), INT2FIX( (int)sw_status->status ) );
  // TODO document the definition of Switch "up" state
  if( sw_status->status == TD_SWITCH_UP ) {
    rb_hash_aset( sw, ID2SYM( rb_intern( "up" ) ), Qtrue );
  } else {
    rb_hash_aset( sw, ID2SYM( rb_intern( "up" ) ), Qfalse );
  }
  return sw;
}

static void
handle_switch_status_updated( void* self, const topology_switch_status* sw_status ) {
  UNUSED( sw_status );
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "switch_status_updated" ) ) == Qtrue ) {
    VALUE sw = switch_status_to_hash( sw_status );
    rb_funcall( ( VALUE ) self, rb_intern( "switch_status_updated" ), 1, sw );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_switch_status_updated" ) ) == Qtrue ) {
    VALUE sw = switch_status_to_hash( sw_status );
    rb_funcall( ( VALUE ) self, rb_intern( "_switch_status_updated" ), 1, sw );
  }
}

static VALUE
port_status_to_hash( const topology_port_status* port_status ) {
  VALUE port = rb_hash_new();
  rb_hash_aset( port, ID2SYM( rb_intern( "dpid" ) ), ULL2NUM( port_status->dpid ) );
  rb_hash_aset( port, ID2SYM( rb_intern( "port_no" ) ), INT2FIX( (int)port_status->port_no ) );
  rb_hash_aset( port, ID2SYM( rb_intern( "name" ) ), rb_str_new2( port_status->name ) );
  char macaddr[] = "FF:FF:FF:FF:FF:FF";
  const uint8_t* mac = port_status->mac;
  snprintf ( macaddr, sizeof(macaddr), "%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5] );
  rb_hash_aset( port, ID2SYM( rb_intern( "mac" ) ), rb_str_new2( macaddr ) );
  rb_hash_aset( port, ID2SYM( rb_intern( "external" ) ), INT2FIX( (int)port_status->external ) );
  rb_hash_aset( port, ID2SYM( rb_intern( "status" ) ), INT2FIX( (int)port_status->status ) );
  return port;
}

static void
handle_port_status_updated( void* self, const topology_port_status* port_status ) {
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "port_status_updated" ) ) == Qtrue ) {
    VALUE port = port_status_to_hash( port_status );
    rb_funcall( ( VALUE ) self, rb_intern( "port_status_updated" ), 1, port );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_port_status_updated" ) ) == Qtrue ) {
    VALUE port = port_status_to_hash( port_status );
    rb_funcall( ( VALUE ) self, rb_intern( "_port_status_updated" ), 1, port );
  }
}

static VALUE
link_status_to_hash( const topology_link_status* link_status ) {
  VALUE link = rb_hash_new();
  rb_hash_aset( link, ID2SYM( rb_intern( "from_dpid" ) ), ULL2NUM( link_status->from_dpid ) );
  rb_hash_aset( link, ID2SYM( rb_intern( "from_port_no" ) ), INT2FIX( (int)link_status->from_portno ) );
  rb_hash_aset( link, ID2SYM( rb_intern( "to_dpid" ) ), ULL2NUM( link_status->to_dpid ) );
  rb_hash_aset( link, ID2SYM( rb_intern( "to_port_no" ) ), INT2FIX( (int)link_status->to_portno ) );
  rb_hash_aset( link, ID2SYM( rb_intern( "status" ) ), INT2FIX( (int)link_status->status ) );
  // TODO document the definition of Link "up" state
  if( link_status->status != TD_LINK_DOWN ) {
    rb_hash_aset( link, ID2SYM( rb_intern( "up" ) ), Qtrue );
  } else {
    rb_hash_aset( link, ID2SYM( rb_intern( "up" ) ), Qfalse );
  }
  if( link_status->status == TD_LINK_UNSTABLE ) {
    rb_hash_aset( link, ID2SYM( rb_intern( "unstable" ) ), Qtrue );
  } else {
    rb_hash_aset( link, ID2SYM( rb_intern( "unstable" ) ), Qfalse );
  }
  return link;
}

static void
handle_link_status_updated( void* self, const topology_link_status* link_status ) {
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "link_status_updated" ) ) == Qtrue ) {
    VALUE link = link_status_to_hash( link_status );
    rb_funcall( ( VALUE ) self, rb_intern( "link_status_updated" ), 1, link );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_link_status_updated" ) ) == Qtrue ) {
    VALUE link = link_status_to_hash( link_status );
    rb_funcall( ( VALUE ) self, rb_intern( "_link_status_updated" ), 1, link );
  }
}


static void
handle_subscribed_reply( void* self, topology_response *res ) {
  switch ( res->status ) {
  case TD_RESPONSE_OK:
  case TD_RESPONSE_ALREADY_SUBSCRIBED:
    if( res->status == TD_RESPONSE_ALREADY_SUBSCRIBED ){
      warn( "Already subscribed to topology service." );
    }

    rb_iv_set( (VALUE)self, "@is_topology_ready", Qtrue );

    if ( rb_respond_to( ( VALUE ) self, rb_intern( "topology_ready" ) ) == Qtrue ) {
      rb_funcall( ( VALUE ) self, rb_intern( "topology_ready" ), 0 );
    }
    break;

  default:
    warn( "%s: Abnormal subscription reply: 0x%x", __func__, (unsigned int)res->status );
  }
}


static void
handle_unsubscribed_reply( void* self, topology_response *res ) {
  if( res->status == TD_RESPONSE_NO_SUCH_SUBSCRIBER ) {
    warn( "Already unsubscribed from topology Service." );
  }else{
    warn( "%s: Abnormal unsubscription reply: 0x%x", __func__, (unsigned int)res->status );
  }
  rb_iv_set( (VALUE)self, "@is_topology_ready", Qfalse );
}


/*
 * subscribe_topology()
 *   Subscribe to topology.
 *
 *   This method is intended to be called implicitly by TopologyNotifiedController.
 *
 */
static VALUE
topology_subscribe_topology( VALUE self ) {
  add_callback_switch_status_updated( handle_switch_status_updated, ( void * ) self );
  add_callback_port_status_updated( handle_port_status_updated, ( void * ) self );
  add_callback_link_status_updated( handle_link_status_updated, ( void * ) self );

  subscribe_topology( handle_subscribed_reply, ( void * ) self );
  return self;
}

/*
 * unsubscribe_topology()
 *   Unsubscribe from topology.
 *
 *   This method is intended to be called implicitly by TopologyNotifiedController.
 *
 */
static VALUE
topology_unsubscribe_topology( VALUE self ) {
  unsubscribe_topology( handle_unsubscribed_reply, ( void * ) self );

  add_callback_switch_status_updated( NULL, NULL );
  add_callback_port_status_updated( NULL, NULL );
  add_callback_link_status_updated( NULL, NULL );
  return self;
}

static void
handle_enable_topology_discovery_reply( void* self, topology_response *res ) {
  if( res->status != TD_RESPONSE_OK ){
    warn( "%s: Abnormal reply: 0x%x", __func__, (unsigned int)res->status );
    // FIXME Should failure of enable_topology_discovery notified to Ruby side?
    return;
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "topology_discovery_ready" ) ) == Qtrue ) {
    rb_funcall( ( VALUE ) self, rb_intern( "topology_discovery_ready" ), 0 );
  }
}

/*
 * Enable topology discovery.
 *
 */
static VALUE
topology_enable_topology_discovery( VALUE self ) {
  enable_topology_discovery( handle_enable_topology_discovery_reply, (void*) self );
  return self;
}

static void
handle_disable_topology_discovery_reply( void* self, topology_response *res ) {
  UNUSED( self );
  if( res->status != TD_RESPONSE_OK ){
    warn( "%s: Abnormal reply: 0x%x", __func__, (unsigned int)res->status );
    // FIXME Should failure of disable_topology_discovery notified to Ruby side?
    return;
  }
  // TODO Should successful disable_topology_discovery call be notified to Ruby side?
}

/*
 * Disable topology discovery.
 *
 */
static VALUE
topology_disable_topology_discovery( VALUE self ) {
  disable_topology_discovery( handle_disable_topology_discovery_reply, (void*) self );
  return self;
}

static void
handle_get_all_link_status_callback( void *self, size_t number, const topology_link_status *link_status ) {
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "all_link_status_reply" ) ) == Qtrue ) {
    VALUE links = rb_ary_new2( (long)number );
    for( size_t i = 0 ; i < number ; ++i ){
      VALUE link = link_status_to_hash( &link_status[i] );
      rb_ary_push( links, link );
    }
    rb_funcall( ( VALUE ) self, rb_intern( "all_link_status_reply" ), 1, links );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_all_link_status_reply" ) ) == Qtrue ) {
    VALUE links = rb_ary_new2( (long)number );
    for( size_t i = 0 ; i < number ; ++i ){
      VALUE link = link_status_to_hash( &link_status[i] );
      rb_ary_push( links, link );
    }
    rb_funcall( ( VALUE ) self, rb_intern( "_all_link_status_reply" ), 1, links );
  }
}

/**
 * send_all_link_status_request
 */
static VALUE
topology_get_all_link_status( VALUE self ) {
  get_all_link_status( handle_get_all_link_status_callback, (void*) self );
  return self;
}

static void
handle_get_all_port_status_callback( void *self, size_t number, const topology_port_status *port_status ) {
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "all_port_status_reply" ) ) == Qtrue ) {
    VALUE ports = rb_ary_new2( (long)number );
    for( size_t i = 0 ; i < number ; ++i ){
      VALUE port = port_status_to_hash( &port_status[i] );
      rb_ary_push( ports, port );
    }
    rb_funcall( ( VALUE ) self, rb_intern( "all_port_status_reply" ), 1, ports );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_all_port_status_reply" ) ) == Qtrue ) {
    VALUE ports = rb_ary_new2( (long)number );
    for( size_t i = 0 ; i < number ; ++i ){
      VALUE port = port_status_to_hash( &port_status[i] );
      rb_ary_push( ports, port );
    }
    rb_funcall( ( VALUE ) self, rb_intern( "_all_port_status_reply" ), 1, ports );
  }
}

/**
 * send_all_port_status_request
 */
static VALUE
topology_get_all_port_status( VALUE self ) {
  get_all_port_status( handle_get_all_port_status_callback, (void*) self );
  return self;
}

static void
handle_get_all_switch_status_callback( void *self, size_t number, const topology_switch_status *sw_status ) {
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "all_switch_status_reply" ) ) == Qtrue ) {
    VALUE switches = rb_ary_new2( (long)number );
    for( size_t i = 0 ; i < number ; ++i ){
      VALUE sw = switch_status_to_hash( &sw_status[i] );
      rb_ary_push( switches, sw );
    }
    rb_funcall( ( VALUE ) self, rb_intern( "all_switch_status_reply" ), 1, switches );
  }
  if ( rb_respond_to( ( VALUE ) self, rb_intern( "_all_switch_status_reply" ) ) == Qtrue ) {
     VALUE switches = rb_ary_new2( (long)number );
     for( size_t i = 0 ; i < number ; ++i ){
       VALUE sw = switch_status_to_hash( &sw_status[i] );
       rb_ary_push( switches, sw );
     }
     rb_funcall( ( VALUE ) self, rb_intern( "_all_switch_status_reply" ), 1, switches );
   }
}


/**
 * send_all_switch_status_request
 */
static VALUE
topology_get_all_switch_status( VALUE self ) {
  get_all_switch_status( handle_get_all_switch_status_callback, (void*) self );
  return self;
}

void Init_topology( void ) {
//  rb_require( "trema/controller" );
//  VALUE cController = rb_eval_string( "Trema::Controller" );
//  cTopologyNotifiedController = rb_define_class_under( mTrema, "TopologyNotifiedController", cController );
  mTopology = rb_define_module_under(mTrema, "Topology" );
  rb_define_protected_method( mTopology, "init_libtopology", topology_init_libtopology, 1 );
  rb_define_protected_method( mTopology, "finalize_libtopology", topology_finalize_libtopology, 0 );

  rb_define_protected_method( mTopology, "subscribe_topology", topology_subscribe_topology, 0 );
  rb_define_protected_method( mTopology, "unsubscribe_topology", topology_unsubscribe_topology, 0 );

  rb_define_method( mTopology, "enable_topology_discovery", topology_enable_topology_discovery, 0 );
  rb_define_method( mTopology, "disable_topology_discovery", topology_disable_topology_discovery, 0 );

  rb_define_method( mTopology, "send_all_link_status_request", topology_get_all_link_status, 0 );
  rb_define_method( mTopology, "send_all_port_status_request", topology_get_all_port_status, 0 );
  rb_define_method( mTopology, "send_all_switch_status_request", topology_get_all_switch_status, 0 );

  rb_require( "trema/topology" );
}
