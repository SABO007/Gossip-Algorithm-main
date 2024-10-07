use "time"
use "collections"
use "random"
use "files"

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