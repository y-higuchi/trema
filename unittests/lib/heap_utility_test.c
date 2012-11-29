/*
 * Unit tests for heap utility functions.
 *
 * Copyright (C) 2008-2012 NEC Corporation
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
#include "checks.h"
#include "cmockery_trema.h"
#include "heap_utility.h"
#include "utility.h"

/******************************************************************************
 * Mocks.
 ******************************************************************************/

static void ( *original_die )( const char *format, ... );

static void
mock_die( const char *format, ... ) {
  char output[ 256 ];
  va_list args;
  va_start( args, format );
  vsprintf( output, format, args );
  va_end( args );
  check_expected( output );

  mock_assert( false, "mock_die", __FILE__, __LINE__ );
}


/******************************************************************************
 * Setup and teardown.
 ******************************************************************************/


static void
setup() {
  original_die = die;
  die = mock_die;
}


static void
teardown() {
  die = original_die;
}


/******************************************************************************
 * Tests.
 ******************************************************************************/

static void
test_compare_heap_uint64_equal() {
  const uint64_t val1 = 64;
  const uint64_t val2 = 64;

  assert_true( compare_heap_uint64( &val1, &val2 ) == 0 );
}


static void
test_compare_heap_uint64_small() {
  const uint64_t val1 = 32;
  const uint64_t val2 = 64;

  assert_true( compare_heap_uint64( &val1, &val2 ) < 0 );
}


static void
test_compare_heap_uint64_large() {
  const uint64_t val1 = 128;
  const uint64_t val2 = 64;

  assert_true( compare_heap_uint64( &val1, &val2 ) > 0 );
}


/******************************************************************************
 * Run tests.
 ******************************************************************************/

int
main() {
  UnitTest tests[] = {
    unit_test_setup_teardown( test_compare_heap_uint64_equal,
                              setup, teardown ),
    unit_test_setup_teardown( test_compare_heap_uint64_small,
                              setup, teardown ),
    unit_test_setup_teardown( test_compare_heap_uint64_large,
                              setup, teardown ),
  };
  return run_tests( tests );
}


/*
 * Local variables:
 * c-basic-offset: 2
 * indent-tabs-mode: nil
 * End:
 */
