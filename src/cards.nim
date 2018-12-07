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

  CardMove = ref object
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

  Pile* = ref object
    kind*: PileKind
    pos*: Vec2i
    label*: string
    cards: Deque[Card]

var cardMoves: seq[CardMove]

method play*(self: CardSettings, c: Card) {.base.} =
  discard

method draw*(self: CardSettings, c: Card) {.base.} =
  discard

proc newCard*(settings: CardSettings): Card =
  result = new(Card)
  result.settings = settings

proc newPile*(label: string): Pile =
  result = new(Pile)
  result.label = label
  result.cards = initDeque[Card]()

proc drawCard*(self: Pile): Card =
  if cards.len == 0:
    return nil
  return cards.popLast()

proc addCard*(self: Pile, c: Card) =
  cards.addLast(c)

proc shuffle*(self: Pile) =
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

proc updateCards*(dt: float32) =
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

proc drawCards*() =
  for cm in cardMoves:
    cm.c.settings.draw(cm.c)

iterator cards*(self: Pile): Card =
  for c in self.cards:
    yield c
