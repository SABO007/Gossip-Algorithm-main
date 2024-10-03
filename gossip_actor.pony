// use "collections"

// actor GossipActor
//   let _id: USize
//   let _master: Main tag
//   var _heard: Bool = false

//   new create(id: USize, master: Main tag) =>
//     _id = id
//     _master = master

//   be receive(neighbors: Array[GossipActor tag] val, next_index: USize) =>
//     if not _heard then
//       _heard = true
//       _master.notify(_id)  // Notify master that this actor heard the rumor

//       try
//         let next = neighbors(next_index)?
//         _master.gossip(neighbors, next)
//       else
//         // If next_index is out of bounds, try to use the first actor
//         try
//           _master.gossip(neighbors, neighbors(0)?)
//         else
//           // If there are no actors in the array, we can't continue gossiping
//           _master.notify(_id, "No actors available for gossiping")
//         end
//       end
//     end