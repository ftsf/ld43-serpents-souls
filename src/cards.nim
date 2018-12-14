import nico
import nico/vec
import deques
import tween
import sequtils

{.this:self.}

type
  CardSettings* = ref object of RootObj
    name*: string
    desc*: string

  Card* = ref object
    settings*: CardSettings
    pos*: Vec2f
    faceDown*: bool

  CardMove* = ref object
    c*: Card
    delay*: float32
    source*: Vec2f
    dest*: Vec2f
    time*: float32
    alpha*: float32
    onComplete*: proc(cm: CardMove)

  PileKind* = enum
    pkAllFaceDown
    pkTopFaceUp
    pkAllFaceUp
    pkAllFaceOpen
    pkHidden

  Pile* = ref object
    kind*: PileKind
    pos*: Vec2i
    label*: string
    cards*: Deque[Card]

var cardMoves: seq[CardMove]

method play*(self: CardSettings, c: Card) {.base.} =
  discard

method draw*(self: CardSettings, c: Card, pos: Vec2f) {.base.} =
  discard

method drawBack*(self: CardSettings, c: Card, pos: Vec2f) {.base.} =
  discard

proc newCard*(settings: CardSettings): Card =
  result = new(Card)
  result.settings = settings

proc newPile*(label: string, kind: PileKind): Pile =
  result = new(Pile)
  result.label = label
  result.cards = initDeque[Card]()
  result.kind = kind

proc drawCard*(self: Pile): Card =
  if cards.len == 0:
    return nil
  return cards.popLast()

proc peek*(self: Pile): Card =
  if cards.len == 0:
    return nil
  return self.cards[self.cards.len - 1]

proc add*(self: Pile, c: Card) =
  cards.addLast(c)

proc addBottom*(self: Pile, c: Card) =
  cards.addFirst(c)

proc shuffle*(self: Pile) =
  if self.cards.len == 0:
    return
  var stacks: array[3,Deque[Card]]
  var nStacks = 3
  for i in 0..<nStacks:
    stacks[i] = initDeque[Card]()

  var stack = 0
  while cards.len > 0:
    let c = cards.popLast()
    c.faceDown = true
    stacks[stack].addLast(c)
    stack += rnd(2)
    stack = stack mod nStacks

  for i in 0..<nStacks:
    while stacks[i].len > 0:
      cards.addLast(stacks[i].popLast())

proc moveCard*(c: Card, dest: Vec2f, delay: float32, onComplete: proc(cm: CardMove)) =
  var cm = new(CardMove)
  cm.c = c
  cm.delay = delay
  cm.source = c.pos
  cm.dest = dest
  cm.onComplete = onComplete
  cm.time = 0.2
  cm.alpha = 0

  cardMoves.add(cm)

proc updateCards*(dt: float32): bool =
  for i in 0..<cardMoves.len:
    let cm = cardMoves[i]
    if cm.delay > 0:
      cm.delay -= dt
    else:
      cm.alpha += dt / cm.time
      let t = cm.alpha
      if t >= 1.0:
        cm.c.pos = cm.dest
        cm.onComplete(cm)
      else:
        cm.c.pos = lerp(cm.source, cm.dest, easeInOutQuad(t))
  cardMoves.keepItIf(it.alpha < 1.0)
  return cardMoves.len > 0

proc cardsMoving*(): bool =
  return cardMoves.len > 0

proc draw*(self: Card) =
  if settings == nil:
    raise newException(Exception, "Can't draw card with no settings")
  settings.draw(self, self.pos)

proc draw*(self: Card, pos: Vec2f) =
  if settings == nil:
    raise newException(Exception, "Can't draw card with no settings")
  self.pos = pos
  settings.draw(self, pos)

proc drawBack*(self: Card, pos: Vec2f) =
  self.pos = pos
  settings.drawBack(self, pos)

proc draw*(self: Pile) =
  if kind != pkHidden:
    setColor(0)
    rrectfill(pos.x - 3, pos.y - 2 , pos.x + 165 + 2, pos.y + 80 + 2)
  var y = pos.y
  for i,c in cards:
    if kind == pkHidden:
      c.pos = vec2f(pos.x, pos.y)
    elif kind == pkAllFaceUp or kind == pkAllFaceOpen or (kind == pkTopFaceUp and i == cards.len - 1):
      c.draw(vec2f(pos.x, y))
      y += (if kind == pkAllFaceOpen: 60 else: -2)
    else:
      c.drawBack(vec2f(pos.x, y))
      y += -2

proc drawCards*() =
  for cm in cardMoves:
    cm.c.draw()

proc len*(self: Pile): int =
  self.cards.len

proc clear*(self: Pile) =
  self.cards.clear()

iterator items*(self: Pile): Card =
  for c in self.cards:
    yield c
