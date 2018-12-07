proc easeInQuad*(t: float32): float32 =
  return t*t

proc easeOutQuad*(t: float32): float32 =
  return t*(2-t)

proc easeInOutQuad*(t: float32): float32 =
  return if t < 0.5: 2*t*t else: -1+(4-2*t)*t

proc easeInCubic*(t: float32): float32 =
  return t*t*t

proc easeOutCubic*(t: float32): float32 =
  return (-t)*t*t+1
