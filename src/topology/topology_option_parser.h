/*
 * topology_option_parser.h
 *
 *  Created on: 2012/12/05
 *      Author: y-higuchi
 */

#ifndef TOPOLOGY_OPTION_PARSER_H_
#define TOPOLOGY_OPTION_PARSER_H_

#include "service_management.h"
#include "discovery_management.h"

typedef struct {
  service_management_options service;
  discovery_management_options discovery;
} topology_options;

void
parse_options( topology_options *options, int *argc, char **argv[] );

#endif /* TOPOLOGY_OPTION_PARSER_H_ */
