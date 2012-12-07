/*
 * probe_timer_table_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>

#include "checks.h"
#include "cmockery_trema.h"
#include "trema.h"

#include "timer.h"
#include "probe_timer_table.h"


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

static bool ( *original_add_timer_event_callback )( struct itimerspec *interval, timer_callback callback, void *user_data );
static bool ( *original_delete_timer_event )( timer_callback callback, void *user_data );

static bool
mock_add_timer_event_callback( struct itimerspec *interval, timer_callback callback, void *user_data ) {
  check_expected( interval );
  check_expected( callback );
  check_expected( user_data );
  return (bool)mock();
}

static bool
mock_delete_timer_event( timer_callback callback, void *user_data ) {
  check_expected( callback );
  check_expected( user_data );
  return (bool)mock();
}

/********************************************************************************
 * Setup and teardown functions.
 ********************************************************************************/

static void
setup() {
  init_timer();
  init_probe_timer_table();
}

static void
teardown() {
  finalize_probe_timer_table();
  finalize_timer();
}

/********************************************************************************
 * Tests.
 ********************************************************************************/



//void probe_request( probe_timer_entry *entry, int event, uint64_t *dpid, uint16_t port_no );

//void init_probe_timer_table( void );
//void finalize_probe_timer_table( void );
static void
test_init_and_finalize_probe_timer_table() {
  swap_original( add_timer_event_callback );
  swap_original( delete_timer_event );

  struct itimerspec interval;
  interval.it_interval.tv_sec = 0;
  interval.it_interval.tv_nsec = 500000000;
  interval.it_value.tv_sec = 0;
  interval.it_value.tv_nsec = 0;

  expect_memory( mock_add_timer_event_callback, interval, &interval, sizeof(interval) );
  expect_not_value( mock_add_timer_event_callback, callback, NULL );
  expect_value( mock_add_timer_event_callback, user_data, NULL );
  will_return( mock_add_timer_event_callback, true );
  init_probe_timer_table();

  expect_not_value( mock_delete_timer_event, callback, NULL );
  expect_value( mock_delete_timer_event, user_data, NULL );
  will_return( mock_delete_timer_event, true );
  finalize_probe_timer_table();

  revert_original( delete_timer_event );
  revert_original( add_timer_event_callback );
}


//probe_timer_entry *allocate_probe_timer_entry( const uint64_t *datapath_id, uint16_t port_no, const uint8_t *mac );
//void free_probe_timer_entry( probe_timer_entry *free_entry );
static void
test_allocate_and_free_probe_timer_entry() {
  uint64_t dpid = 0x1;
  uint8_t mac[ETH_ADDRLEN] = { 0x01,0x02,0x03,0x04,0x05,0x06 };
  probe_timer_entry* e = allocate_probe_timer_entry( &dpid, 1, mac );
  assert_true( e != NULL );
  assert_int_equal( e->datapath_id, dpid );
  assert_int_equal( e->port_no, 1 );
  assert_memory_equal( e->mac, mac, ETH_ADDRLEN );
  assert_int_equal( e->retry_count, 0 );
  assert_int_equal( e->state, PROBE_TIMER_STATE_INACTIVE );
  assert_false( e->link_up );
  assert_false( e->dirty );

  free_probe_timer_entry( e );
}

// TODO void insert_probe_timer_entry( probe_timer_entry *entry );
// TODO probe_timer_entry *delete_probe_timer_entry( const uint64_t *datapath_id, uint16_t port_no );
// TODO probe_timer_entry *lookup_probe_timer_entry( const uint64_t *datapath_id, uint16_t port_no );

/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
      unit_test( test_init_and_finalize_probe_timer_table ),
      unit_test_setup_teardown( test_allocate_and_free_probe_timer_entry, setup, teardown ),
  };

  setup_leak_detector();
  return run_tests( tests );
}

