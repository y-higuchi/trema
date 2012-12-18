Feature: show topology

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
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "dumper"
      """
      And I run `trema run -c topology.conf -d`
      And wait until "topology" is up
      And *** sleep 4 ***
      And I run `trema run ../../objects/examples/topology/show_topology`
    Then the output should contain:
      """
      vswitch {
        datapath_id "0x2"
      }
      """
    And the output should contain:
      """
      vswitch {
        datapath_id "0x3"
      }
      """
    And the output should contain:
      """
      vswitch {
        datapath_id "0x1"
      }
      """
    And the output should contain:
      """
      vswitch {
        datapath_id "0x4"
      }
      """
    And the output should contain:
      """
      link "0x2", "0x1"
      """
    And the output should contain:
      """
      link "0x3", "0x2"
      """
    And the output should contain:
      """
      link "0x3", "0x1"
      """
    And the output should contain:
      """
      link "0x4", "0x2"
      """
    And the output should contain:
      """
      link "0x4", "0x3"
      """
    And the output should contain:
      """
      link "0x4", "0x1"
      """


