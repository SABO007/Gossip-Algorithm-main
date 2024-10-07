use "time"
use "collections"
use "random"

actor GossipActor is Actor
  let _id: USize
  let _master: Main tag
  let _rand: Rand iso
  var _heard_count: USize = 0
  var _neighbors: Array[Actor tag] val = recover val Array[Actor tag] end
  var _last_spread_time: U64 = 0
  let _spread_interval: U64 = 100

  new create(id: USize, master: Main tag, rand: Rand iso) =>
    _id = id
    _master = master
    _rand = consume rand

  be set_neighbors(neighbors: Array[Actor tag] val) =>
    _neighbors = neighbors

  be add_neighbor(neighbor: Actor tag) =>
    let new_neighbors = recover val
      let arr = Array[Actor tag](_neighbors.size() + 1)
      for n in _neighbors.values() do
        arr.push(n)
      end
      arr.push(neighbor)
      arr
    end
    _neighbors = new_neighbors

  be start_gossip() =>
    receive_rumor()

  be receive_rumor() =>
    _heard_count = _heard_count + 1
    _master.print_debug("Debug: Actor " + _id.string() + " heard rumor " + _heard_count.string() + " times")
    
    if _heard_count == 1 then
      spread_rumor()
    elseif _heard_count == 10 then 
      _master.notify_convergence(1)
    else
      spread_rumor()
    end
  
  be stop() =>
  _heard_count = 10

  fun ref spread_rumor() =>
    let current_time = Time.millis()
    if (current_time - _last_spread_time) >= _spread_interval then
      _last_spread_time = current_time
      if _neighbors.size() > 0 then
        let next_index: USize = _rand.int[USize](_neighbors.size())
        try
          (_neighbors(next_index)? as GossipActor).receive_rumor()
        end
      end
    end
    
    if _heard_count < 10 then
      _master.schedule_spread(this)
    end

  be spread_again() =>
    spread_rumor()