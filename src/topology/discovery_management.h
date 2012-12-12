/*
 * discovery_management.h
 *
 *  Created on: 2012/11/19
 *      Author: y-higuchi
 */

#ifndef DISCOVERY_MANAGEMENT_H_
#define DISCOVERY_MANAGEMENT_H_

#include "lldp.h"

typedef struct discovery_management_options {
  lldp_options lldp;
  bool always_enabled;
} discovery_management_options;

bool init_discovery_management( discovery_management_options new_options );
void finalize_discovery_management( void );

bool start_discovery_management( void );
void stop_discovery_management( void );


/**
 * Enable discovery.
 */
void enable_discovery( void );
void disable_discovery( void );

// TODO Future work: port masking API etc.


extern bool ( *send_probe )( const uint8_t *mac, uint64_t dpid, uint16_t port_no );


#endif /* DISCOVERY_MANAGEMENT_H_ */
