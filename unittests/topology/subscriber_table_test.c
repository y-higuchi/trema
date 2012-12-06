/*
 * subscriber_table_test.c
 *
 *  Created on: 2012/11/22
 *      Author: y-higuchi
 */

#include <assert.h>

#include "checks.h"
#include "cmockery_trema.h"
#include "trema.h"
#include "subscriber_table.h"


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

static void
setup() {
  init_subscriber_table();
}

static void
teardown() {
  finalize_subscriber_table();
}

/********************************************************************************
 * Tests.
 ********************************************************************************/

//void init_subscriber_table( void );
//void finalize_subscriber_table( void );
static void
test_init_and_finalize_subscriber_table() {
  init_subscriber_table();
  finalize_subscriber_table();
}

//bool insert_subscriber_entry( const char *name );
//void delete_subscriber_entry( subscriber_entry *entry );
//subscriber_entry *lookup_subscriber_entry( const char *name );
static void
test_insert_subscriber_entry_and_lookup_and_then_delete() {
  assert_true( insert_subscriber_entry("subscriber1") );

  subscriber_entry* e = lookup_subscriber_entry("subscriber1");
  assert_true( e != NULL );
  assert_string_equal( e->name, "subscriber1" );

  delete_subscriber_entry( e );

  e = lookup_subscriber_entry("subscriber1");
  assert_true( e == NULL );
}

//double insert

//void foreach_subscriber( void function( subscriber_entry *entry, void *user_data ), void *user_data );
static void
helper_subscriber_walker( subscriber_entry* entry, void* user ) {
  const char* name = entry->name;
  check_expected( name );
  check_expected( user );
}
static void
helper_delete_subscriber( subscriber_entry* entry, void* user ) {
  UNUSED( user );
  delete_subscriber_entry( entry );
}
static void
test_foreach_subscriber() {
  assert_true( insert_subscriber_entry("subscriber1") );
  assert_true( insert_subscriber_entry("subscriber2") );
  assert_true( insert_subscriber_entry("subscriber3") );
  assert_true( insert_subscriber_entry("subscriber4") );
  assert_true( insert_subscriber_entry("subscriber5") );

  void* user = (void*)0x1234;

  expect_value_count( helper_subscriber_walker, user, user, 5 );
  expect_memory_count( helper_subscriber_walker, name, "subscriber", strlen("subscriber"), 5 );
  foreach_subscriber( helper_subscriber_walker, user );

  foreach_subscriber( helper_delete_subscriber, NULL );
}

/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
      unit_test( test_init_and_finalize_subscriber_table ),
      unit_test_setup_teardown( test_insert_subscriber_entry_and_lookup_and_then_delete, setup, teardown ),
      unit_test_setup_teardown( test_foreach_subscriber, setup, teardown ),
  };
  setup_leak_detector();
  return run_tests( tests );
}

