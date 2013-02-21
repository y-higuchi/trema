require "trema/topology"


class ShowSwitchStatus < Controller
  include Topology


  oneshot_timer_event :timed_out, 15
  oneshot_timer_event :on_start, 0
  def on_start
    send_all_switch_status_request
  end

  def all_switch_status_reply sw_status
    puts "Switch status"
    sw_status.each do | sw_hash |
      sw = Topology::Switch[ sw_hash ]

      status_str = "unknown"
      if sw.up? then
        status_str = "up"
      else
        status_str = "down"
      end
      puts "  dpid : 0x#{sw.dpid.to_s(16)}, status : #{status_str}"
    end

    send_all_port_status_request
  end

  def all_port_status_reply port_status
    puts "Port status"
    port_status.each do | port_hash |
      port = Port[ port_hash ]
      status_str = "unknown"
      if port.up? then
        status_str = "up"
      else
        status_str = "down"
      end
      
      puts "  dpid : 0x#{port.dpid.to_s(16)}, port : #{port.portno.to_s}(#{port.name}), status : #{status_str}, external : #{port.external?.to_s}"
    end

    shutdown!
  end


  def timed_out
    error "timed out."
    shutdown!
  end
end
