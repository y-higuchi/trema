require "trema/topology"
require "trema/topology/topology_cache"


# Controller which keeps printing Switch and Link change event as graphviz dot file.
# It will shutdown itself if there was no Switch or Link event for 60 seconds.
#
class ChangeHistory < Controller
  include Topology

  # TODO Add option to specify idle check interval.
  periodic_timer_event :shutdown_on_idle, 60

  oneshot_timer_event :on_start, 0
  def on_start
    enable_topology_discovery
    send_rebuild_cache_request

    # TODO Add option to specify file from command line.
    @dotfile = File.open( "change-history.dot", "w" )

    # digraph {
    puts_dotfile "digraph {"
    at_exit do
      # } for digraph
      puts_dotfile "}"
    end
  end


  def cache_ready g
    @generation = 0

    # Initially color everything as updated (green)
    g.switches.each do | _, sw |
      sw[:color] = "green"
    end
    g.links.each do | _, lnk |
      lnk[:color] = "green"
    end

    puts_dotfile to_dot_subgraph( g, @generation, "initial" )
  end


  def switch_status_updated sw_attr
    if not instance_variable_defined?(:@generation) then
      return nil
    end

    @generation += 1
    sw_attr[:generation] = @generation

    g = get_cache
    remove_old_colors( g, @generation )

    if sw_attr[:up] then
      sw_attr[:color] = "green"
      update_cache_by_switch_hash sw_attr
      sublabel = "0x#{sw_attr[:dpid].to_s(16)} up"
      puts_dotfile to_dot_subgraph( g, @generation, sublabel )
    else
      g.switches[ sw_attr[:dpid] ][:color] = "red" if g.switches[ sw_attr[:dpid] ]
      sublabel = "0x#{sw_attr[:dpid].to_s(16)} down"
      puts_dotfile to_dot_subgraph( g, @generation, sublabel )
      # update to new state. (switch instance will be removed)
      update_cache_by_switch_hash sw_attr
    end

  end


  def link_status_updated link_attr
    if not instance_variable_defined?(:@generation) then
      return nil
    end
    link = Link[link_attr]

    @generation += 1
    link[:generation] = @generation

    g = get_cache
    remove_old_colors( g, @generation )

    if link.up? then
      link[:color] = "green"
      update_cache_by_link_hash link
      sublabel = "(0x#{link.from_dpid.to_s(16)} -> 0x#{link.to_dpid.to_s(16)}) up"
      puts_dotfile to_dot_subgraph( g, @generation, sublabel )
    else
      g.links[ link.key ][:color] = "red" if g.links[ link.key ]
      sublabel = "(0x#{link.from_dpid.to_s(16)} -> 0x#{link.to_dpid.to_s(16)}) down"
      puts_dotfile to_dot_subgraph( g, @generation, sublabel )
      # update to new state. (link instance will be removed)
      update_cache_by_link_hash link
    end
  end


  def shutdown_on_idle
    @last_generation ||= -1
    if @last_generation == @generation then
      shutdown!
    else
      @last_generation = @generation
    end
  end


  def remove_old_colors( g, generation )
    g.switches.each do | _, sw |
      sw[:generation] ||= 0
      sw.delete(:color) if sw[:generation] != generation
    end
    g.links.each do | _, lnk |
      lnk[:generation] ||= 0
      lnk.delete(:color) if lnk[:generation] != generation
    end
  end


  def to_dot_subgraph( g, generation, sublabel="" )
    s = "  subgraph cluster#{generation} {\n"
    s << %Q(    graph [label="Gen #{generation}\\n#{sublabel}"];\n)
    # // switches
    g.switches.each do | _, sw |
      dot_attrs = %Q(label="0x#{sw.dpid.to_s(16)}")
      if sw.member?(:color) then
        dot_attrs << ", " unless dot_attrs.empty?
        dot_attrs << %Q(color="#{sw[:color]}")
      end
      s << %Q(    "0x#{sw.dpid.to_s(16)}_#{generation}" [#{dot_attrs}];\n)
    end
    # // links
    g.links.each do | _, lnk |
      dot_attrs = ""
      if lnk.member?(:color) then
        dot_attrs << ", " unless dot_attrs.empty?
        dot_attrs << %Q(color="#{lnk[:color]}")
      end
      s << %Q(    "0x#{lnk.from_dpid.to_s(16)}_#{generation}" -> "0x#{lnk.to_dpid.to_s(16)}_#{generation}" [#{dot_attrs}];\n)
    end
    # } for subgraph
    s << "  }\n"
    return s
  end


  def puts_dotfile s
    begin
      @dotfile.puts s
      @dotfile.flush
    rescue
      error "Failed to write dotfile (#{$!.inspect})\n\t#{$!.backtrace.join("\n\t") }"
      STDERR.puts "Failed to write dotfile."
      shutdown!
    end
  end
end


