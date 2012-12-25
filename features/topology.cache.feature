Feature: topology 

  As a developer using Trema
  I want to develop topology aware application.


  Scenario: cache_ready handler
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology.ofa", :packet_in => "filter", :state_notify => "topology.ofa"
      filter :lldp => "topology.ofa", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        def topology_ready
          send_rebuild_cache_request
        end
        
        def cache_ready c
          info "cache_ready"
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`    
      And wait until "topology" is up
      Then the file "../../tmp/log/TestController.log" should contain "cache_ready"


  Scenario: get cache without rebuilding
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      vswitch("topology2") { datapath_id "0x2" }
      
      link "topology1", "topology2"
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology.ofa", :packet_in => "filter", :state_notify => "topology.ofa"
      filter :lldp => "topology.ofa", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        oneshot_timer_event :delayed_event, 4
        
        def delayed_event
          send_rebuild_cache_request false
        end
        
        def cache_ready c
          info c.to_s
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      And *** sleep 4 ***
      Then the file "../../tmp/log/TestController.log" should contain:
        """
        [Topology Cache]
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Switch 0x1 - [[:status, 1], [:up, true]]
         Port 0x1:1 - 
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
         Links_in
          <= 0x2:1
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
         Links_out
          => 0x2:1
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Switch 0x2 - [[:status, 1], [:up, true]]
         Port 0x2:1 - 
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
         Links_in
          <= 0x1:1
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
         Links_out
          => 0x1:1
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port 0x1:1 - [
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port 0x2:1 - [
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link (0x1:1)->(0x2:1) - [[:status, 1], [:unstable, false], [:up, true]]
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link (0x2:1)->(0x1:1) - [[:status, 1], [:unstable, false], [:up, true]]
        """


 