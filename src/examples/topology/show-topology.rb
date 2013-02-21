require "trema/topology"


class ShowTopology < Controller
  include Topology


  oneshot_timer_event :timed_out, 10
  oneshot_timer_event :on_start, 0
  def on_start
    send_all_link_status_request
  end


  def all_link_status_reply link_status
    dpids = Hash.new
    links = Hash.new

    debug "topology: entries #{link_status.size}"

    link_status.each do | link_hash |
      link = Link[link_hash]
      if link.up? then
        dpids[link.from_dpid] = nil
        dpids[link.to_dpid] = nil

        dpid_pair = [link.from_dpid, link.to_dpid]

        links[ [dpid_pair.max, dpid_pair.min] ] = nil
      else
        debug "link down"
      end
    end

    dpids.keys.each do | dpid |
      puts "vswitch {"
      puts %Q(  datapath_id "0x#{dpid.to_s(16)}")
      puts "}\n\n"
    end

    links.keys.each do | dpid0, dpid1 |
      puts %Q(link "0x#{dpid0.to_s(16)}", "0x#{dpid1.to_s(16)}")
    end

    shutdown!
  end


  def timed_out
    error "timed out."
    shutdown!
  end
end
