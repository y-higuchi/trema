/*
 * lldp_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>

#include "checks.h"
#include "cmockery_trema.h"

#include "messenger.h"
#include "openflow_application_interface.h"

#include "lldp.h"


/********************************************************************************
 * Common function.
 ********************************************************************************/


/********************************************************************************
 * Mock functions.
 ********************************************************************************/

#define swap_original( funcname ) \
  original_##funcname = funcname;\
  funcname = mock_##funcname;

#define revert_original( funcname ) \
  funcname = original_##funcname;


/********************************************************************************
 * Setup and teardown functions.
 ********************************************************************************/

const char* OFA_SERVICE_NAME = "test_lldp.ofa";

static void
setup() {
  init_messenger("/tmp");
  init_timer();
  init_stat();
  init_openflow_application_interface( OFA_SERVICE_NAME );
}

static void
teardown() {
  finalize_openflow_application_interface();
  finalize_timer();
  finalize_stat();
  finalize_messenger();
}

/********************************************************************************
 * Tests.
 ********************************************************************************/

static const uint8_t default_lldp_mac_dst[] = { 0x01, 0x80, 0xc2, 0x00, 0x00, 0x0e };

//bool send_lldp( probe_timer_entry *port );
static void
helper_sw_message_received_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );
//  check_expected( data );
//  check_expected( len );
  UNUSED( len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );

  struct ofp_header* ofp_header = (struct ofp_header*) (((char*)data) + header_length);
  assert( ofp_header->type == OFPT_PACKET_OUT );

  struct ofp_packet_out* packet_out = (struct ofp_packet_out*) (((char*)data) + header_length);
  const uint16_t actions_len = ntohs(packet_out->actions_len);
  assert( actions_len > 0 );
  assert( actions_len == sizeof( struct ofp_action_output ) );

  struct ofp_action_header* act_header = (struct ofp_action_header*) (((char*)packet_out) + offsetof( struct ofp_packet_out, actions ));
  const uint16_t action_type = act_header->type;
  assert( action_type == OFPAT_OUTPUT );
  const uint16_t action_length = ntohs(act_header->len);// no byte order conversion?
  assert( action_length == sizeof( struct ofp_action_output ) );

  struct ofp_action_output* act_out = (struct ofp_action_output*) act_header;
  assert( ntohs(act_out->len) == sizeof( struct ofp_action_output ) );
  const uint16_t port = ntohs( act_out->port );
  check_expected( port );
  ether_header_t* ether_frame = (ether_header_t*) (((char*)packet_out) + offsetof( struct ofp_packet_out, actions ) + actions_len);
  assert_memory_equal( ether_frame->macda, default_lldp_mac_dst, ETH_ADDRLEN );
  const uint8_t* macsa = ether_frame->macsa;
  check_expected( macsa );
  struct tlv* chassis_id_tlv = (struct tlv*) (((char*)ether_frame) + sizeof(ether_header_t));
  assert( (chassis_id_tlv->type_len & 0xFE00)>>9  == 1 ); // upper 7bits in uint16_t;
  const uint16_t chassis_id_tlv_len = chassis_id_tlv->type_len & 0x1FF; // lower 9bits in uint16_t;
  const size_t chassis_id_strlen = chassis_id_tlv_len - ( LLDP_TLV_HEAD_LEN + LLDP_SUBTYPE_LEN );
  assert( chassis_id_strlen > 0 );

//  struct tlv* port_id_tlv;
//  struct tlv* ttl_tlv;
//  struct tlv* end_tlv;

  stop_event_handler();
  stop_messenger();
}
static void
test_send_lldp() {
  probe_timer_entry port = {
      .datapath_id = 0x1234,
      .port_no = 42,
      .to_datapath_id = 0x5678,
      .to_port_no = 72,
      .mac = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06},
  };

  // dummy OFA receiving notification
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_received_end ) );

  expect_value( helper_sw_message_received_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_message_received_end, datapath_id, 0x1234 );
  expect_value( helper_sw_message_received_end, port, 42 );
  expect_memory( helper_sw_message_received_end, macsa, port.mac, ETH_ADDRLEN );
//  expect_value( helper_sw_message_received_end, len, 108 );

  assert_true( send_lldp( &port ) );

  start_messenger();
  start_event_handler();

  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_received_end ) );
}

//bool init_lldp( lldp_options options );
//bool finalize_lldp( void );
static void
test_init_finalize_lldp() {
  lldp_options options = {
      .lldp_mac_dst = { 0x01, 0x80, 0xc2, 0x00, 0x00, 0x0e },
      .lldp_over_ip = false,
  };

  assert_true( init_lldp( options ) );
  assert_true( finalize_lldp() );
}
/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
//      unit_test_setup_teardown( test_send_lldp, setup, teardown ),
      unit_test_setup_teardown( test_init_finalize_lldp, setup, teardown ),
  };
  UNUSED( test_send_lldp );

  setup_leak_detector();
  return run_tests( tests );
}

