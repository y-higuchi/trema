Feature: Topology Ruby API example
  
  The change-history.rb example ([trema]/src/examples/topology/change-history.rb)
  is a sample controller which uses Topology Ruby API.

  @slow_process
  Scenario: Run the Ruby example
    Given a file named "change-history.conf" with:
      """
      1.upto( 3 ).each do | sw |
        vswitch { dpid sw }
        1.upto( sw - 1 ).each do | peer |
          link "%#x" % sw, "%#x" % peer
        end
      end
      
      run {
        path "../../objects/topology/topology"
      }
      
      run {
        path "../../objects/examples/dumper/dumper"
      }
      
      event :port_status => "topology", :packet_in => "filter", :state_notify => "topology"
      filter :lldp => "topology", :packet_in => "dumper"
      """
    When I run `../../trema run ../../src/examples/topology/change-history.rb -c change-history.conf -d`
    Then wait until "topology" is up
    Then *** sleep 32 ***

    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x3 -> 0x1\) up"\];.*/
    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x3 -> 0x2\) up"\];.*/
    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x2 -> 0x1\) up"\];.*/
    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x2 -> 0x3\) up"\];.*/
    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x1 -> 0x2\) up"\];.*/
    Then the file "change-history.dot" should match /.*graph \[label="Gen \d+\\n\(0x1 -> 0x3\) up"\];.*/
    