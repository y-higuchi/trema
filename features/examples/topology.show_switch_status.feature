Feature: show_switch_status example.
  
  show_switch_status is a simple usage example of topology C API.
  
  show_switch_status command will query for all the switch and port information 
  that the topology daemon hold and print them to standard output.

  @slow_process
  Scenario: [C API] Show switch and port information obtained from topology.
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0xe0" }
      vhost ("host1") {
        ip "192.168.0.1"
        netmask "255.255.0.0"
        mac "00:00:00:01:00:01"
      }
      
      vhost ("host2") {
        ip "192.168.0.2"
        netmask "255.255.0.0"
        mac "00:00:00:01:00:02"
      }
      
      link "topology1", "host1"
      link "topology1", "host2"
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      run {
        path "../../objects/examples/dumper/dumper"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "dumper"
      """
    And I run `trema run -c topology.conf -d`
    And wait until "topology" is up
    And *** sleep 16 ***
    When I run `trema run ../../objects/examples/topology/show_switch_status`
    Then the output should contain:
      """
      Switch status
        dpid : 0xe0, status : up
      """
    And the output should contain:
      """
      Port status
      """
    And the output should match /dpid : 0xe0, port : 1\(.+\), status : up, external : true/
    And the output should match /dpid : 0xe0, port : 2\(.+\), status : up, external : true/
