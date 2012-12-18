Feature: topology help

  As a Trema user
  I want to see the usage of topology.


  Scenario: topology --help
    When I run `../../objects/topology/topology --help`
    Then the output should contain:
      """
      topology manager
      Usage: topology [OPTION]...

        -w, --liveness_wait=SEC         subscriber liveness check interval
        -e, --liveness_limit=COUNT      set liveness check error threshold
        -a, --always_run_discovery      discovery will always be enabled
        -m, --lldp_mac_dst=MAC_ADDR     destination Mac address for sending LLDP
        -i, --lldp_over_ip              send LLDP messages over IP
        -o, --lldp_ip_src=IP_ADDR       source IP address for sending LLDP over IP
        -r, --lldp_ip_dst=IP_ADDR       destination IP address for sending LLDP over IP
        -n, --name=SERVICE_NAME         service name
        -d, --daemonize                 run in the background
        -l, --logging_level=LEVEL       set logging level
        -g, --syslog                    output log messages to syslog
        -f, --logging_facility=FACILITY set syslog facility
        -h, --help                      display this help and exit
      """


  Scenario: topology -h
    When I run `../../objects/topology/topology -h`
    Then the output should contain:
      """
      topology manager
      Usage: topology [OPTION]...

        -w, --liveness_wait=SEC         subscriber liveness check interval
        -e, --liveness_limit=COUNT      set liveness check error threshold
        -a, --always_run_discovery      discovery will always be enabled
        -m, --lldp_mac_dst=MAC_ADDR     destination Mac address for sending LLDP
        -i, --lldp_over_ip              send LLDP messages over IP
        -o, --lldp_ip_src=IP_ADDR       source IP address for sending LLDP over IP
        -r, --lldp_ip_dst=IP_ADDR       destination IP address for sending LLDP over IP
        -n, --name=SERVICE_NAME         service name
        -d, --daemonize                 run in the background
        -l, --logging_level=LEVEL       set logging level
        -g, --syslog                    output log messages to syslog
        -f, --logging_facility=FACILITY set syslog facility
        -h, --help                      display this help and exit
      """
