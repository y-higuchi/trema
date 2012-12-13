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

#include "trema.h"

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
static const uint8_t broadcast_mac_dst[] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

//bool send_lldp( probe_timer_entry *port );
static void
helper_sw_message_received_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );
  UNUSED( len );

  buffer* parse_lldp_buffer = alloc_buffer_with_length(len);
  void* parse_data = append_back_buffer( parse_lldp_buffer, len );
  memcpy( parse_data, data, len );

  openflow_service_header_t* of_s_h = data;
  const uint64_t datapath_id = ntohll( of_s_h->datapath_id );
  check_expected( datapath_id );
  const size_t ofs_header_length = sizeof(openflow_service_header_t) + ntohs( of_s_h->service_name_length );


  struct ofp_header* ofp_header = (struct ofp_header*) (((char*)data) + ofs_header_length);
  assert( ofp_header->type == OFPT_PACKET_OUT );

  struct ofp_packet_out* packet_out = (struct ofp_packet_out*) (((char*)data) + ofs_header_length);
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
  assert_int_equal( ntohs(ether_frame->type), ETH_ETHTYPE_LLDP );
  assert_memory_equal( ether_frame->macda, default_lldp_mac_dst, ETH_ADDRLEN );
  const uint8_t* macsa = ether_frame->macsa;
  check_expected( macsa );


  // chassis
  struct tlv* chassis_id_tlv = (struct tlv*) (((char*)ether_frame) + sizeof(ether_header_t));
  assert_int_equal( ((ntohs(chassis_id_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_CHASSIS_ID ); // upper 7bits in uint16_t;
  const uint16_t chassis_id_tlv_len = ntohs(chassis_id_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  const size_t chassis_id_strlen = chassis_id_tlv_len - LLDP_SUBTYPE_LEN;
  assert_in_range( chassis_id_strlen, 1, LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN );
  char chassis_id[LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN] = {};
  memcpy( chassis_id, chassis_id_tlv->val+LLDP_SUBTYPE_LEN, chassis_id_strlen );
  check_expected( chassis_id );

  //  struct tlv* port_id_tlv;
  struct tlv* port_id_tlv = (struct tlv*) (((char*)chassis_id_tlv) + LLDP_TLV_HEAD_LEN + chassis_id_tlv_len);
  assert_int_equal( ((ntohs(port_id_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_PORT_ID ); // upper 7bits in uint16_t;
  const uint16_t port_id_tlv_len = ntohs(port_id_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  const size_t port_id_strlen = port_id_tlv_len - LLDP_SUBTYPE_LEN;
  assert_in_range( port_id_strlen, 1, LLDP_TLV_PORT_ID_INFO_MAX_LEN );
  char port_id[LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN] = {};
  memcpy( port_id, port_id_tlv->val+LLDP_SUBTYPE_LEN, port_id_strlen );
  check_expected( port_id );

  //  struct tlv* ttl_tlv;
  struct tlv* ttl_tlv = (struct tlv*) (((char*)port_id_tlv) + LLDP_TLV_HEAD_LEN + port_id_tlv_len);
  assert_int_equal( ((ntohs(ttl_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_TTL ); // upper 7bits in uint16_t;
  const uint16_t ttl_tlv_len = ntohs(ttl_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  assert_int_equal( ttl_tlv_len, sizeof(uint16_t) );
  assert_int_equal( ntohs( *((uint16_t*)ttl_tlv->val) ), LLDP_DEFAULT_TTL );

  //  struct tlv* end_tlv;
  struct tlv* end_tlv = (struct tlv*) (((char*)ttl_tlv) + LLDP_TTL_LEN );
  assert_int_equal( ((ntohs(end_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_END ); // upper 7bits in uint16_t;
  const uint16_t end_tlv_len = ntohs(end_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  assert_int_equal( end_tlv_len, 0 );


  // test parse_lldp
  // extract ethernet frame
  remove_front_buffer( parse_lldp_buffer, (size_t)(((char*)ether_frame) - ((char*)data)) );
  bool parse_ok = parse_packet( parse_lldp_buffer );
  assert_true( parse_ok );

  uint64_t parsed_dpid;
  uint16_t parsed_port_no;
  parse_ok = parse_lldp( &parsed_dpid, &parsed_port_no, parse_lldp_buffer );
  assert_true( parse_ok );
  assert_int_equal( parsed_dpid, datapath_id );
  assert_int_equal( parsed_port_no, atoi(port_id) );
  free_buffer( parse_lldp_buffer );

  stop_event_handler();
  stop_messenger();
}
static void
test_send_lldp() {
  setup();

  lldp_options options = {
      .lldp_mac_dst = { 0x01, 0x80, 0xc2, 0x00, 0x00, 0x0e },
      .lldp_over_ip = false,
  };

  assert_true( init_lldp( options ) );

  uint64_t datapath_id = 0x1234;
  uint16_t port_no = 42;
  uint8_t mac[] = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};

  // dummy OFA receiving notification
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_received_end ) );

  expect_value( helper_sw_message_received_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_message_received_end, datapath_id, 0x1234 );
  expect_value( helper_sw_message_received_end, port, 42 );
  expect_memory( helper_sw_message_received_end, macsa, mac, ETH_ADDRLEN );
  expect_string( helper_sw_message_received_end, chassis_id, "0x1234" );
  expect_string( helper_sw_message_received_end, port_id, "42" );

  assert_true( send_lldp( mac, datapath_id, port_no ) );

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_received_end ) );
  assert_true( finalize_lldp() );

  teardown();
}

static void
helper_sw_message_over_ip_received_end( uint16_t tag, void *data, size_t len ) {
  check_expected( tag );
  UNUSED( len );

  buffer* parse_lldp_buffer = alloc_buffer_with_length(len);
  void* parse_data = append_back_buffer( parse_lldp_buffer, len );
  memcpy( parse_data, data, len );

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
  assert_int_equal( ntohs(ether_frame->type), ETH_ETHTYPE_IPV4 );
  assert_memory_equal( ether_frame->macda, broadcast_mac_dst, ETH_ADDRLEN );
  const uint8_t* macsa = ether_frame->macsa;
  check_expected( macsa );

  ipv4_header_t* ip = (ipv4_header_t*) (((char*)ether_frame) + sizeof(ether_header_t));
  const uint32_t src_ip = ntohl( ip->saddr );
  check_expected( src_ip );
  const uint32_t dst_ip = ntohl( ip->daddr );
  check_expected( dst_ip );

  etherip_header* etherip = (etherip_header*) (((char*)ip) + sizeof(ipv4_header_t));

  // ip payload ether
  ether_header_t* etherip_frame = (ether_header_t*) (((char*)etherip) + sizeof(etherip_header));
  assert_int_equal( ntohs(etherip_frame->type), ETH_ETHTYPE_LLDP );
  assert_memory_equal( etherip_frame->macda, default_lldp_mac_dst, ETH_ADDRLEN );
  assert_memory_equal( etherip_frame->macsa, ether_frame->macsa, ETH_ADDRLEN );

  // chassis
  struct tlv* chassis_id_tlv = (struct tlv*) (((char*)etherip_frame) + sizeof(ether_header_t));
  assert_int_equal( ((ntohs(chassis_id_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_CHASSIS_ID ); // upper 7bits in uint16_t;
  const uint16_t chassis_id_tlv_len = ntohs(chassis_id_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  const size_t chassis_id_strlen = chassis_id_tlv_len - LLDP_SUBTYPE_LEN;
  assert_in_range( chassis_id_strlen, 1, LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN );
  char chassis_id[LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN] = {};
  memcpy( chassis_id, chassis_id_tlv->val+LLDP_SUBTYPE_LEN, chassis_id_strlen );
  check_expected( chassis_id );

  //  struct tlv* port_id_tlv;
  struct tlv* port_id_tlv = (struct tlv*) (((char*)chassis_id_tlv) + LLDP_TLV_HEAD_LEN + chassis_id_tlv_len);
  assert_int_equal( ((ntohs(port_id_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_PORT_ID ); // upper 7bits in uint16_t;
  const uint16_t port_id_tlv_len = ntohs(port_id_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  const size_t port_id_strlen = port_id_tlv_len - LLDP_SUBTYPE_LEN;
  assert_in_range( port_id_strlen, 1, LLDP_TLV_PORT_ID_INFO_MAX_LEN );
  char port_id[LLDP_TLV_CHASSIS_ID_INFO_MAX_LEN] = {};
  memcpy( port_id, port_id_tlv->val+LLDP_SUBTYPE_LEN, port_id_strlen );
  check_expected( port_id );

  //  struct tlv* ttl_tlv;
  struct tlv* ttl_tlv = (struct tlv*) (((char*)port_id_tlv) + LLDP_TLV_HEAD_LEN + port_id_tlv_len);
  assert_int_equal( ((ntohs(ttl_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_TTL ); // upper 7bits in uint16_t;
  const uint16_t ttl_tlv_len = ntohs(ttl_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  assert_int_equal( ttl_tlv_len, sizeof(uint16_t) );
  assert_int_equal( ntohs( *((uint16_t*)ttl_tlv->val) ), LLDP_DEFAULT_TTL );

  //  struct tlv* end_tlv;
  struct tlv* end_tlv = (struct tlv*) (((char*)ttl_tlv) + LLDP_TTL_LEN );
  assert_int_equal( ((ntohs(end_tlv->type_len) & 0xFE00)>>9), LLDP_TYPE_END ); // upper 7bits in uint16_t;
  const uint16_t end_tlv_len = ntohs(end_tlv->type_len) & 0x1FF; // lower 9bits in uint16_t;
  assert_int_equal( end_tlv_len, 0 );

  // test parse_lldp
  // extract ethernet frame
  remove_front_buffer( parse_lldp_buffer, (size_t)(((char*)ether_frame) - ((char*)data)) );
  bool parse_ok = parse_packet( parse_lldp_buffer );
  assert_true( parse_ok );

  uint64_t parsed_dpid;
  uint16_t parsed_port_no;
  parse_ok = parse_lldp( &parsed_dpid, &parsed_port_no, parse_lldp_buffer );
  assert_true( parse_ok );
  assert_int_equal( parsed_dpid, datapath_id );
  assert_int_equal( parsed_port_no, atoi(port_id) );
  free_buffer( parse_lldp_buffer );

  stop_event_handler();
  stop_messenger();
}
static void
test_send_lldp_over_ip() {
  setup();

  lldp_options options = {
      .lldp_mac_dst = { 0x01, 0x80, 0xc2, 0x00, 0x00, 0x0e },
      .lldp_over_ip = true,
      .lldp_ip_src = ((127<< 24) + (0<< 16) + (1 <<8) + 1),
      .lldp_ip_dst = ((127<< 24) + (1<< 16) + (2 <<8) + 2),
  };

  assert_true( init_lldp( options ) );

  uint64_t datapath_id = 0x1234;
  uint16_t port_no = 42;
  uint8_t mac[] = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};

  // dummy OFA receiving notification
  const char* SRC_SW_MSNGER_NAME = "switch.0x1234";
  assert_true( add_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_over_ip_received_end ) );

  expect_value( helper_sw_message_over_ip_received_end, tag, MESSENGER_OPENFLOW_MESSAGE );
  expect_value( helper_sw_message_over_ip_received_end, datapath_id, 0x1234 );
  expect_value( helper_sw_message_over_ip_received_end, port, 42 );
  expect_value( helper_sw_message_over_ip_received_end, src_ip, options.lldp_ip_src );
  expect_value( helper_sw_message_over_ip_received_end, dst_ip, options.lldp_ip_dst );
  expect_memory( helper_sw_message_over_ip_received_end, macsa, mac, ETH_ADDRLEN );
  expect_string( helper_sw_message_over_ip_received_end, chassis_id, "0x1234" );
  expect_string( helper_sw_message_over_ip_received_end, port_id, "42" );

  assert_true( send_lldp( mac, datapath_id, port_no ) );

  start_messenger();
  start_event_handler();

  assert_true( delete_message_received_callback( SRC_SW_MSNGER_NAME, helper_sw_message_over_ip_received_end ) );
  assert_true( finalize_lldp() );

  teardown();
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
      unit_test( test_send_lldp ),
      unit_test( test_send_lldp_over_ip ),
      unit_test_setup_teardown( test_init_finalize_lldp, setup, teardown ),
  };

  setup_leak_detector();
  return run_tests( tests );
}

