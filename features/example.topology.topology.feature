Feature: topology help

  As a Trema user
  I want to control multiple openflow switches using topology application
  So that I can show topology


  @slow_process
  Scenario: Four openflow switches, four servers
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      vswitch("topology2") { datapath_id "0x2" }
      vswitch("topology3") { datapath_id "0x3" }
      vswitch("topology4") { datapath_id "0x4" }
      
      link "topology1", "topology2"
      link "topology1", "topology3"
      link "topology1", "topology4"
      link "topology2", "topology3"
      link "topology2", "topology4"
      link "topology3", "topology4"
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      run {
        path "../../objects/examples/dumper/dumper"
      }
      
      event :port_status => "topology.ofa", :packet_in => "filter", :state_notify => "topology.ofa"
      filter :lldp => "topology.ofa", :packet_in => "dumper"
      """
      And I run `trema run -c topology.conf -d`
      And wait until "dumper" is up
      And wait until "topology" is up
      And *** sleep 5 ***
      Given env TREMA_HOME is set
      And I run `../../objects/examples/topology/show_topology`
    Then the output should contain:
      """
      vswitch {
        datapath_id "0x2"
      }
      
      vswitch {
        datapath_id "0x3"
      }
      
      vswitch {
        datapath_id "0x1"
      }
      
      vswitch {
        datapath_id "0x4"
      }
      
      link "0x2", "0x1"
      link "0x3", "0x2"
      link "0x3", "0x1"
      link "0x4", "0x2"
      link "0x4", "0x3"
      link "0x4", "0x1"
      """


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
