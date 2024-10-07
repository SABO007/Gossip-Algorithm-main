use "time"
use "collections"
use "random"
use "files"
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
  let _output_file: File

  new create(env: Env) =>
    _env = env
    rand = Rand(Time.nanos())
    _actors = recover val Array[Actor tag] end
    _active_count = 0
    _total_actors = 10
    _topology = "full"
    _algorithm = "gossip"
    _start_time = 0
    _convergence_achieved = false
    
    let auth = FileAuth(env.root)
    let path = FilePath(auth, "output.txt")
    _output_file = File(path)
    _output_file.set_length(0) 

    if env.args.size() < 4 then
      _output_file.print("Usage: project2 numNodes topology algorithm")
    else
      _total_actors = try env.args(1)?.usize()? else 2500 end
      _topology = try env.args(2)? else "full" end
      _algorithm = try env.args(3)? else "gossip" end

      _output_file.print("Debug: Initializing with " + _total_actors.string() + " " + _topology + " " + _algorithm)

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

      _output_file.print("Debug: Actors created")

      // Build topology
      build_topology()
        _output_file.print("Debug: Topology built")

        // Start the algorithm
        _start_time = Time.millis()
        _output_file.print("Debug: Starting algorithm")
        try
            if _algorithm == "gossip" then
            (_actors(0)? as GossipActor).start_gossip()
            else
            (_actors(0)? as PushSumActor).start_push_sum()
            end
        else
            _output_file.print("Failed to start algorithm: No actors available")
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
        _output_file.print("Timeout: Not all actors converged. " + _active_count.string() + "/" + _total_actors.string() + " actors converged.")
        _output_file.print("Exiting program due to timeout")
        _output_file.flush()
        _timers.dispose()
        _output_file.dispose()
        @exit[None](I32(1))
        end

    be shutdown() =>
    for a in _actors.values() do
      match a
      | let ga: GossipActor => ga.stop()
      | let psa: PushSumActor => psa.stop()
      end
    end
    _timers.dispose()
    _output_file.flush()
    _output_file.dispose()
    @exit[None](I32(0))


    be notify_convergence(n: U64) =>
        if (n == 1) or (n == 2) then
            _active_count = _active_count + 1
            _output_file.print("Actor converged. " + _active_count.string() + "/" + _total_actors.string() + " actors have converged.")
            if (_active_count == _total_actors) and (not _convergence_achieved) then
                _convergence_achieved = true
                let end_time = Time.millis()
                let elapsed = end_time - _start_time
                _output_file.print("All actors have converged. Convergence achieved in " + elapsed.string() + " milliseconds")
                _output_file.print("Exiting program")
                _env.out.print("Convergence achieved in " + elapsed.string() + " milliseconds")
                _output_file.flush()
                shutdown()
            end
        end

  be print_debug(msg: String) =>
    if not _convergence_achieved then
      _output_file.print(msg)
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