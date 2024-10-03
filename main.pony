// use "time"
// use "collections"
// use "random"

// actor Main
//   let _env: Env
//   let _actors: Array[GossipActor tag] val
//   var _heard_count: USize = 0
//   let _total_actors: USize = 10
//   let _rand: Rand
//   let _timers: Timers = Timers

//   new create(env: Env) =>
//     _env = env
//     _rand = Rand(Time.nanos())

//     // Create the actors and store them in an immutable array
//     _actors = recover val
//       let arr = Array[GossipActor tag](_total_actors)
//       for i in Range(0, _total_actors) do
//         arr.push(GossipActor.create(i, this))
//       end
//       arr
//     end

//     // Start the gossip with the first actor
//     try
//       gossip(_actors, _actors(0)?)
//     else
//       _env.out.print("Failed to start gossip: No actors available")
//     end

//     // Set a timer to stop the program after 5 seconds
//     let timer = Timer(Notify(this), 5_000_000_000)
//     _timers(consume timer)

//   be gossip(neighbors: Array[GossipActor tag] val, next: GossipActor tag) =>
//     let next_index = _rand.int[USize](_total_actors)
//     next.receive(neighbors, next_index)

//   be notify(id: USize, msg: String = "") =>
//     _heard_count = _heard_count + 1
//     if msg == "" then
//       _env.out.print("Actor " + id.string() + " heard the rumor")
//     else
//       _env.out.print("Actor " + id.string() + ": " + msg)
//     end
    
//     if _heard_count == _total_actors then
//       _env.out.print("All actors have heard the rumor!")
//       _timers.dispose()
//     end

//   be _timeout() =>
//     _env.out.print("Time's up! " + _heard_count.string() + " out of " + _total_actors.string() + " actors heard the rumor.")
//     _timers.dispose()

// class Notify is TimerNotify
//   let _main: Main tag

//   new iso create(main: Main tag) =>
//     _main = main

//   fun ref apply(timer: Timer, count: U64): Bool =>
//     _main._timeout()
//     false