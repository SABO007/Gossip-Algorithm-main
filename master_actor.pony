use "time"
use "collections"
use "random"
use @exit[None](status: I32)

actor Main
    let _env: Env
    var _actors: Array[Actor tag] val
    var _active_count: USize
    var _total_actors: USize
    var _topology: String
    var _algorithm: String
    var rand: Rand iso
    var _start_time: U64
    let _timeout: U64 = 900_000
    let _timers: Timers = Timers
    var _convergence_achieved: Bool = false 

    new create(env: Env) =>
      _env = env
      _env.out.print("Debug: Program started")
      rand = Rand(Time.nanos())
      _actors = recover val Array[Actor tag] end
      _active_count = 0
      _total_actors = 10
      _topology = "full"
      _algorithm = "gossip"
      _start_time = 0
      _convergence_achieved = false

    if env.args.size() < 4 then
      _env.out.print("Usage: project2 numNodes topology algorithm")
    else
      _total_actors = try env.args(1)?.usize()? else 2500 end
      _topology = try env.args(2)? else "full" end
      _algorithm = try env.args(3)? else "gossip" end

      _env.out.print("Debug: Initializing with " + _total_actors.string() + " " + _topology + " " + _algorithm)

      _actors = recover val
        let arr = Array[Actor tag](_total_actors)
        for i in Range(0, _total_actors) do
          if _algorithm == "gossip" then
            arr.push(create_gossip_actor(i))
          else
            arr.push(create_push_sum_actor(i))
          end
        end
        arr
      end

      _env.out.print("Debug: Actors created")

      // Build topology
      build_topology()
      _env.out.print("Debug: Topology built")

      // Start the algorithm
      _start_time = Time.millis()
      _env.out.print("Debug: Starting algorithm")
      try
        if _algorithm == "gossip" then
          (_actors(0)? as GossipActor).start_gossip()
        else
          (_actors(0)? as PushSumActor).start_push_sum()
        end
      else
        _env.out.print("Failed to start algorithm: No actors available")
      end

      _set_timeout()
    end

  fun ref create_gossip_actor(id: USize): GossipActor =>
    GossipActor.create(id, this, recover Rand(Time.nanos()) end)

  fun ref create_push_sum_actor(id: USize): PushSumActor =>
  PushSumActor.create(id, this, recover Rand(Time.nanos()) end)

  fun ref build_topology() =>
    match _topology
    | "full" => build_full_network()
    | "3D" => 
      try
        build_3d_grid()?
      else
        _env.out.print("Error building 3D grid")
      end
    | "line" => 
      try
        build_line()?
      else
        _env.out.print("Error building line")
      end
    | "imp3D" => 
      try
        build_imperfect_3d_grid()?
      else
        _env.out.print("Error building imperfect 3D grid")
      end
    else
      _env.out.print("Invalid topology")
    end

  fun ref build_full_network() =>
    for actor_ref in _actors.values() do
      actor_ref.set_neighbors(_actors)
    end

  fun ref build_line()? =>
    for i in Range(0, _total_actors) do
      let neighbors = recover val
        let arr = Array[Actor tag]
        if i > 0 then arr.push(_actors(i-1)?) end
        if i < (_total_actors-1) then arr.push(_actors(i+1)?) end
        arr
      end
      _actors(i)?.set_neighbors(neighbors)
    end

  fun ref build_3d_grid()? =>
    let size = (_total_actors.f64().pow(1.0/3.0).ceil()).usize()
    let total_size = size * size * size

    for i in Range(0, _total_actors) do
      let neighbors = recover val
        let arr = Array[Actor tag]
        let x = i % size
        let y = (i / size) % size
        let z = i / (size * size)

        if x > 0 then
          arr.push(_actors(i-1)?)
        end
        if (x < (size-1)) and ((i+1) < _total_actors) then
          arr.push(_actors(i+1)?)
        end

        if y > 0 then
          arr.push(_actors(i-size)?)
        end
        if (y < (size-1)) and ((i+size) < _total_actors) then
          arr.push(_actors(i+size)?)
        end

        if z > 0 then
          arr.push(_actors(i-(size*size))?)
        end
        if (z < (size-1)) and ((i+(size*size)) < _total_actors) then
          arr.push(_actors(i+(size*size))?)
        end

        arr
      end
      _actors(i)?.set_neighbors(neighbors)
    end
    _env.out.print("Debug: 3D grid built with cube size " + size.string() + "x" + size.string() + "x" + size.string())

  fun ref build_imperfect_3d_grid()? =>
    build_3d_grid()?
    for actor_ref in _actors.values() do
      let random_neighbor = _actors(rand.int[USize](_total_actors))?
      actor_ref.add_neighbor(random_neighbor)
    end
    _env.out.print("Debug: Imperfect 3D grid built with additional random connections")


  fun ref _set_timeout() =>
    let timer = Timer(object iso
      let main: Main = this
      fun ref apply(timer: Timer, count: U64): Bool =>
        main.check_timeout()
        true
      fun ref cancel(timer: Timer) => None
    end, 1_000_000_000, 1_000_000_000) // Check every second
    _timers(consume timer)

     be check_timeout() =>
    if (Time.millis() - _start_time) > _timeout then
      _env.out.print("Timeout: Not all actors converged. " + _active_count.string() + "/" + _total_actors.string() + " actors converged.")
      _env.exitcode(1)
      // Break execution after timeout
      _env.out.print("Exiting program due to timeout")
      _timers.dispose()
    end

    be shutdown() =>
      for a in _actors.values() do
        match a
        | let ga: GossipActor => ga.stop()
        | let psa: PushSumActor => psa.stop()
        end
      end
      _timers.dispose()
      _env.out.flush()
      @exit[None](I32(0))

    be notify_convergence(n: U64) =>
  if (n == 1) or (n == 2) then
    _active_count = _active_count + 1
    _env.out.print("Actor converged. " + _active_count.string() + "/" + _total_actors.string() + " actors have converged.")
    if (_active_count == _total_actors) and (not _convergence_achieved) then
      _convergence_achieved = true
      let end_time = Time.millis()
      let elapsed = end_time - _start_time
      _env.out.print("All actors have converged. Convergence achieved in " + elapsed.string() + " milliseconds")
      shutdown()
    end
  end



  be print_debug(msg: String) =>
    if not _convergence_achieved then
      _env.out.print(msg)
    end

  be schedule_spread(gossip_actor: GossipActor) =>
  if not _convergence_achieved then
    let timer = Timer(object iso
      let gossip_actor': GossipActor = gossip_actor
      fun ref apply(timer: Timer, count: U64): Bool =>
        gossip_actor'.spread_again()
        false
      fun ref cancel(timer: Timer) => None
    end, 100_000_000) // 100ms
    _timers(consume timer)
  end


trait Actor
  be set_neighbors(neighbors: Array[Actor tag] val)
  be add_neighbor(neighbor: Actor tag)

actor GossipActor is Actor
  let _id: USize
  let _master: Main tag
  let _rand: Rand iso
  var _heard_count: USize = 0
  var _neighbors: Array[Actor tag] val = recover val Array[Actor tag] end
  var _last_spread_time: U64 = 0
  let _spread_interval: U64 = 100 // milliseconds

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
    elseif _heard_count == 10 then  // Changed back to 10 as per original requirement
      _master.notify_convergence(1)
    else
      spread_rumor()
    end
  
  be stop() =>
  _heard_count = 10 // This will prevent further spreading

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


actor PushSumActor is Actor
  let _id: USize
  let _master: Main tag
  let _rand: Rand iso
  var _s: F64
  var _w: F64
  var _neighbors: Array[Actor tag] val
  var _unchanged_count: USize
  var _last_ratio: F64
  var _converged: Bool
  var _cooldown: USize

  new create(id: USize, master: Main tag, rand: Rand iso) =>
    _id = id
    _master = master
    _rand = consume rand
    _s = id.f64()
    _w = 1.0
    _neighbors = recover val Array[Actor tag] end
    _unchanged_count = 0
    _last_ratio = _s / _w
    _converged = false
    _cooldown = 0

  
  be receive_push_sum(s': F64, w': F64) =>
    let old_ratio = _s / _w
    _s = (_s + s')
    _w = (_w + w')
    let new_ratio = _s / _w

    if (old_ratio - new_ratio).abs() < 1e-10 then
      _unchanged_count = _unchanged_count + 1
      if (_unchanged_count == 3) and (not _converged) then
        _converged = true
        _cooldown = 10
        _master.notify_convergence(2)
      end
    else
      _unchanged_count = 0
    end

    _last_ratio = new_ratio

    if _cooldown > 0 then
      _cooldown = _cooldown - 1
    //   if _cooldown == 0 then`
    //     _master.notify_convergence(2)
    //   end
    end

    send_push_sum()

  be start_push_sum() =>
    send_push_sum()

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

  be stop() =>
    _converged = true
    _cooldown = 0

  fun ref send_push_sum() =>
    if _neighbors.size() > 0 then
      let next_index: USize = _rand.int[USize](_neighbors.size())
      try
        (_neighbors(next_index)? as PushSumActor).receive_push_sum(_s / 2, _w / 2)
      end
      _s = _s / 2
      _w = _w / 2
    end