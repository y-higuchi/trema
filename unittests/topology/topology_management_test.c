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

#include "topology_management.h"


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

const char* OFA_SERVICE_NAME = "test_topo_mgmt.ofa";

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

//bool init_topology_management( void );
//void finalize_topology_management( void );
//bool start_topology_management( void );
//void stop_topology_management( void );
static void
test_init_start_stop_finalize_topology_management() {
  assert_true( init_topology_management() );
  assert_true( start_topology_management() );
  stop_topology_management();
  finalize_topology_management();
}


/********************************************************************************
 * Run tests.
 ********************************************************************************/

int
main() {
  const UnitTest tests[] = {
      unit_test_setup_teardown( test_init_start_stop_finalize_topology_management, setup, teardown ),
      // TODO test for set_switch_ready_handler( handle_switch_ready, NULL );
      // TODO test for set_switch_disconnected_handler( handle_switch_disconnected, NULL );
      // TODO test for set_features_reply_handler( handle_switch_features_reply, NULL );
      // TODO test for set_port_status_handler( handle_port_status, NULL );
  };

  setup_leak_detector();
  return run_tests( tests );
}

