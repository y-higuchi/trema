Feature: topology Ruby API

  As a developer using Trema
  I want to develop topology aware application.


  Scenario: Receive topology_ready message
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        def topology_ready
          info "topology_ready"
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      Then the file "../../tmp/log/TestController.log" should contain "topology_ready"


  Scenario: Receive topology_discovery_ready message
    Given a file named "topology.conf" with:
      """
      vswitch("topology1") { datapath_id "0x1" }
      
      run {
        path "../../objects/topology/topology"
        options "--always_run_discovery"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        def topology_ready
          enable_topology_discovery
        end
        def topology_discovery_ready
          info "topology_discovery_ready"
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      Then the file "../../tmp/log/TestController.log" should contain "topology_discovery_ready"


  Scenario: Receive switch, port, link update notifications
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
      filter :lldp => "topology", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        def switch_status_updated sw
          info Switch[ sw ].to_s
        end
        
        def port_status_updated p
          info Port[ p ].to_s
        end
        
        def link_status_updated l
          info Link[ l ].to_s
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      And *** sleep 4 ***
      Then the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x1 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x2 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x1:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x2:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x1:1)->(0x2:1) - {status:1, unstable:false, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x2:1)->(0x1:1) - {status:1, unstable:false, up:true}
        """


  Scenario: Receive get all switch, port, link status with block
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
      filter :lldp => "topology", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        oneshot_timer_event :show_topology, 4
        
        def show_topology
          send_all_switch_status_request do |sw|
            sw.each { |each| info Switch[ each ].to_s }
          end
          send_all_port_status_request do |ports|
            ports.each { |each| info Port[ each ].to_s }
          end
          send_all_link_status_request do |links|
            links.each { |each| info Link[ each ].to_s }
          end
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      And *** sleep 4 ***
      Then the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x1 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x2 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x1:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x2:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x1:1)->(0x2:1) - {status:1, unstable:false, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x2:1)->(0x1:1) - {status:1, unstable:false, up:true}
        """


  Scenario: Receive get all switch, port, link status with handler
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
      filter :lldp => "topology", :packet_in => "TestTopology"
      """
    And a file named "TestTopology.rb" with:
      """
      require "trema/topology"
      require "trema/topology/topology_cache"
      
      class TestController < Controller
        include Topology
      
        oneshot_timer_event :show_topology, 4
        
        def show_topology
          send_all_switch_status_request
          send_all_port_status_request
          send_all_link_status_request
        end
        
        def all_switch_status_reply sw
          sw.each { |each| info Switch[ each ].to_s }
        end
        
        def all_port_status_reply ports
          ports.each { |each| info Port[ each ].to_s }
        end
        
        def all_link_status_reply links
          links.each { |each| info Link[ each ].to_s }
        end
      end
      """
      And I run `trema run TestTopology.rb -c topology.conf -d`
      And wait until "topology" is up
      And *** sleep 4 ***
      Then the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x1 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Switch: 0x2 - {status:1, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x1:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Port: 0x2:1 - {
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x1:1)->(0x2:1) - {status:1, unstable:false, up:true}
        """
      And the file "../../tmp/log/TestController.log" should contain:
        """
        Link: (0x2:1)->(0x1:1) - {status:1, unstable:false, up:true}
        """

