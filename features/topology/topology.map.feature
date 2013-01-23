Feature: topology map Ruby API
  
  As a developer using Trema
  I want to develop topology aware application.

  Scenario: map_ready handler
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "MapReadyTestTopology"
      """
    And a file named "MapReadyTestTopology.rb" with:
      """
      require "trema/topology/map_api"
      
      class MapReadyTestTopology < Controller
        include TopologyMap
      
        oneshot_timer_event :test_start, 0
        
        def test_start
          send_rebuild_map_request
        end
        
        def map_ready c
          info "map_ready"
        end
      end
      """
    When I run `trema run MapReadyTestTopology.rb -c topology.conf -d`
    And wait until "topology" is up
    And *** sleep 1 ***
    Then the file "../../tmp/log/MapReadyTestTopology.log" should contain "map_ready"

  Scenario: map_ready handler (block)
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "MapReadyTestTopologyB"
      """
    And a file named "MapReadyTestTopologyB.rb" with:
      """
      require "trema/topology/map_api"
      
      class MapReadyTestTopologyB < Controller
        include TopologyMap
      
        oneshot_timer_event :test_start, 0
        
        def test_start
          send_rebuild_map_request { |map|
            info "map_ready_block"
          }
        end
        
        def map_ready c
          info "map_ready_should_not_be_called"
        end
      end
      """
    When I run `trema run MapReadyTestTopologyB.rb -c topology.conf -d`
    And wait until "topology" is up
    And *** sleep 1 ***
    Then the file "../../tmp/log/MapReadyTestTopologyB.log" should contain "map_ready_block"
    And the file "../../tmp/log/MapReadyTestTopologyB.log" should not contain "map_ready_should_not_be_called"

  Scenario: get map without rebuilding
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      vswitch("topology2") { datapath_id "0x2" }
      
      link "topology1", "topology2"
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "RebuildTestController"
      """
    And a file named "RebuildTestController.rb" with:
      """
      require "trema/topology/map_api"
      
      class RebuildTestController < Controller
        include TopologyMap
      
        oneshot_timer_event :delayed_event, 4
        
        def delayed_event
          send_rebuild_map_request false
        end
        
        def map_ready c
          info c.to_s
        end
      end
      """
    When I run `trema run RebuildTestController.rb -c topology.conf -d`
    And wait until "topology" is up
    And *** sleep 4 ***
    Then the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Map:
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Switch: 0x1 - {up:true}
      """
    And the file "../../tmp/log/RebuildTestController.log" should match / Port: 0x1:1 - \{external:false, mac:"[0-9a-f:]+", name:".*", up:true\}/
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
       Links_in
        <= 0x2:1
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
       Links_out
        => 0x2:1
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Switch: 0x2 - {up:true}
      """
    And the file "../../tmp/log/RebuildTestController.log" should match / Port: 0x2:1 - \{external:false, mac:"[0-9a-f:]+", name:".*", up:true\}/
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
       Links_in
        <= 0x1:1
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
       Links_out
        => 0x1:1
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Port: 0x1:1 - {
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Port: 0x2:1 - {
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Link: (0x1:1)->(0x2:1) - {unstable:false, up:true}
      """
    And the file "../../tmp/log/RebuildTestController.log" should contain:
      """
      Link: (0x2:1)->(0x1:1) - {unstable:false, up:true}
      """
