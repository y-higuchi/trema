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

// TODO local api to set discovery config.

// TODO Future work port masking etc.

#endif /* DISCOVERY_MANAGEMENT_H_ */
