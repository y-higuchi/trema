/*
 * discovery_management.h
 *
 *  Created on: 2012/11/19
 *      Author: y-higuchi
 */

#ifndef DISCOVERY_MANAGEMENT_H_
#define DISCOVERY_MANAGEMENT_H_

#include <stdbool.h>
#include <stdint.h>

typedef struct discovery_management_options {
  bool lldp_over_ip;
  uint32_t lldp_ip_src;
  uint32_t lldp_ip_dst;
} discovery_management_options;

void init_discovery_management( discovery_management_options new_options );
void finalize_discovery_management();


/**
 * Enable discovery.
 * TODO Service management should handle if there are any user requesting discovery service.
 */
void enable_discovery();
void disable_discovery();

// TODO local api to set discovery config.

// TODO Future work port masking etc.

#endif /* DISCOVERY_MANAGEMENT_H_ */
