import heapqueue, tables, hashes, math

proc dijkstra*[G,N,D,M](graph: G, start: N, maxCost: D, mover: M, reality = true): Table[N,tuple[dist: D, prev: (bool,N)]] =

  var distprev = initTable[N,tuple[dist: D, prev: (bool,N)]]()

  var emptyN: N

  var Q = newHeapQueue[(N,D)]()

  for n in graph:
    if n != start:
      distprev[n] = (99999, (false, emptyN))
    else:
      distprev[n] = (0, (false, emptyN))
    Q.push((n, distprev[n].dist))

  var i = 0
  while Q.len > 0:
    let ud = Q.pop()
    let u = ud[0]
    for v in graph.neighbors(mover, u, reality):
      var found = false
      for i in 0..<Q.len:
        if Q[i][0] == v:
          found = true
          break
      if not found:
        continue
      let alt = distprev[u].dist + graph.cost(u,v,mover,reality)
      if alt < distprev[v].dist and alt <= maxCost:
        distprev[v].dist = alt
        distprev[v].prev = (true,u)
        for i in 0..<Q.len:
          if Q[i][0] == v:
            Q.del(i)
            Q.push((v, alt))
            break
    i += 1

  return distprev
