import nico
import utils
import strutils

{.this:self.}

type
  GuiDirection* = enum
    gTopToBottom
    gBottomToTop
    gLeftToRight
    gRightoLeft
  GuiEventKind = enum
    gRepaint
    gMouseDown
    gMouseUp
    gMouseMove
    gKeyDown
  GuiEvent = object
    kind: GuiEventKind
    x,y: int
    button: int
    keycode: Keycode
  GuiArea* = ref object
    id: int
    minX*,minY*,maxX*,maxY*: int
    cursorX*,cursorY*: int
    direction*: GuiDirection
  Gui* = ref object
    e: GuiEvent
    element*: int
    normalColor*: int
    hoverColor*: int
    activeColor*: int
    downColor*: int
    hintColor*: int
    onColor*: int
    textColor*: int
    disabledColor*: int
    backgroundColor*: int
    buttonBackgroundColor*: int
    buttonBackgroundColorDisabled*: int
    hoverElement*: int
    activeHoverElement*: int
    activeElement*: int
    downElement*: int
    wasMouseDown: bool
    areas: seq[GuiArea]
    area*: GuiArea
    activeAreaId: int
    hSpacing*,vSpacing*: int
    hPadding*,vPadding*: int
    center*: bool
    hExpand*: bool
    vExpand*: bool
    modalArea*: int
    nextAreaId: int
    hintHotkey*: Keycode
    hintOnly*: bool
  GuiButton* = tuple
    text: string
    action: proc()
  GuiDialog* = object
    text: string
    buttons: seq[GuiButton]

var G*: Gui = new(Gui)
var lastMouseX,lastMouseY: int
var frame: int

proc box*(self: Gui, x,y,w,h: int)

proc pointInRect(px,py, x,y,w,h: int): bool =
  return px >= x and px <= x + w - 1 and py >= y and py <= y + h - 1

proc advance(self: Gui, w,h: int) =
  assert(area != nil)
  case area.direction:
  of gLeftToRight:
    area.cursorX += w + hSpacing
    if area.cursorX >= area.maxX:
      area.cursorX = area.minX
      area.cursorY += h + vSpacing
  of gRightoLeft:
    area.cursorX -= w + hSpacing
    if area.cursorX <= area.minX:
      area.cursorX = area.maxX
      area.cursorY += h + vSpacing
  of gTopToBottom:
    area.cursorY += h + vSpacing
    if area.cursorY >= area.maxY:
      area.cursorY = area.minY
      area.cursorX += w + hSpacing
  of gBottomToTop:
    area.cursorY -= h + vSpacing
    if area.cursorY <= area.minY:
      area.cursorY = area.maxY
      area.cursorX += w + hSpacing

proc cursor(self: Gui, w, h: int): (int,int) =
  assert(area != nil)
  result[0] = if area.direction == gRightoLeft: area.cursorX - w else: area.cursorX
  result[1] = if area.direction == gBottomToTop: area.cursorY - h else: area.cursorY

proc label*(self: Gui, text: string, x,y,w,h: int, box: bool = false) =
  element += 1
  if e.kind == gRepaint:
    if box:
      self.box(x,y,w,h)
    setColor(textColor)
    let nLines = text.countLines()
    richPrint(text, x + (if center: w div 2 else: 0), y + (if center: h div 2 - (fontHeight() * nLines) div 2 else: 0), if center: taCenter else: taLeft)

  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x, y, w, h):
      hoverElement = element
      activeHoverElement = 0

proc label*(self: Gui, text: string, w, h: int, box: bool = false) =
  let (x,y) = self.cursor(w,h)
  label(text, x, y, w, h, box)
  advance(w,h)

proc label*(self: Gui, text: string, box: bool = false) =
  assert(area != nil)
  var w = 0
  var h = 0
  for line in text.splitLines():
    var lineW = textWidth(line)
    if lineW > w:
      w = lineW
    h += fontHeight()
  w = if hExpand: area.maxX - area.minX else: w + (if box: hPadding * 2 else: 0)
  h = if vExpand: area.maxY - area.minY else: h + (if box: vPadding * 2 else: 0)
  label(text, w, h, box)

proc labelStep*(self: Gui, text: string, x,y,w,h: int, step: int, box: bool = false) =
  element += 1
  if e.kind == gRepaint:
    if box:
      self.box(x,y,w,h)
    setColor(textColor)
    let nLines = text.countLines()
    richPrint(text, x + (if center: w div 2 else: 0), y + (if center: h div 2 - (fontHeight() * nLines) div 2 else: 0), if center: taCenter else: taLeft, false, step)

  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x, y, w, h):
      hoverElement = element
      activeHoverElement = 0

proc labelStep*(self: Gui, text: string, w, h: int, step: int, box: bool = false) =
  let (x,y) = self.cursor(w,h)
  labelStep(text, x, y, w, h, step, box)
  advance(w,h)

proc labelStep*(self: Gui, text: string, step: int, box: bool = false) =
  assert(area != nil)
  var w = 0
  var h = 0
  for line in text.splitLines():
    var lineW = textWidth(line)
    if lineW > w:
      w = lineW
    h += fontHeight()
  w = if hExpand: area.maxX - area.minX else: w + (if box: hPadding * 2 else: 0)
  h = if vExpand: area.maxY - area.minY else: h + (if box: vPadding * 2 else: 0)
  labelStep(text, w, h, step, box)

proc drawGuiString(self: Gui, text: string, x,y,w,h: int, enabled: bool) =
  setColor(if enabled: textColor else: disabledColor)
  let nLines = text.countLines()
  richPrint(text, x + (if center: w div 2 else: hPadding), y + (if center: h div 2 - (fontHeight() * nLines) div 2 else: vPadding), if center: taCenter else: taLeft)

proc button*(self: Gui, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: proc(x,y,w,h: int, enabled: bool)): bool =
  element += 1
  let hintBlocked = (hintOnly and hintHotkey != hotkey)
  if e.kind == gRepaint:
    setColor(if enabled == false or hintBlocked: buttonBackgroundColorDisabled elif downElement == element: downColor else: buttonBackgroundColor)
    rrectfill(x,y,x+w,y+h)

    if hotkey != K_UNKNOWN and hotkey == hintHotkey and frame mod 60 < 30:
      setColor(hintColor)
      rrect(x-1,y-1,x+w+1,y+h+1)

    if enabled and activeElement == element:
      setColor(activeColor)
    elif enabled and not hintBlocked and hoverElement == element:
      setColor(hoverColor)
    else:
      setColor(normalColor)
    rrect(x,y,x+w,y+h)

    draw(x + hPadding, y + vPadding, w - hPadding * 2, h - vPadding * 2, enabled)

  if modalArea != 0:
    # check that we're underneath the modal area
    var inModalArea = false
    for a in areas:
      if a.id == modalArea:
        inModalArea = true
        break
    if not inModalArea:
      return

  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x, y, w, h):
      hoverElement = element
      activeHoverElement = if enabled and not hintBlocked: element else: 0

  if enabled == false or hintBlocked:
    return false

  if e.kind == gMouseDown:
    if pointInRect(e.x, e.y, x, y, w, h):
      downElement = element

  elif e.kind == gKeyDown and hotkey != K_UNKNOWN and keyp(hotkey):
    if downElement != element:
      downElement = element
    else:
      activeElement = element
      downElement = 0
      return true

  elif e.kind == gMouseUp:
    if pointInRect(e.x, e.y, x, y, w, h):
      if downElement == element:
        activeElement = element
        downElement = 0
        return true

  return false

proc button*(self: Gui, text: string, x,y,w,h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool =
  return button(x,y,w,h,enabled,hotkey,proc(x,y,w,h: int, enabled: bool) = drawGuiString(self,text,x,y,w,h,enabled))

proc button*(self: Gui, text: string, x,y,w,h: int, enabled: bool = true): bool =
  return button(x,y,w,h,enabled,K_UNKNOWN,proc(x,y,w,h: int, enabled: bool) = drawGuiString(self,text,x,y,w,h,enabled))

proc button*(self: Gui, text: string, w, h: int, enabled: bool = true, hotkey = K_UNKNOWN): bool =
  let (x,y) = self.cursor(w,h)
  let ret = button(text, x, y, w, h, enabled, hotkey)
  advance(w,h)
  return ret

proc button*(self: Gui, w,h: int, enabled: bool = true, hotkey = K_UNKNOWN, draw: proc(x,y,w,h:int, enabled: bool)): bool =
  let (x,y) = self.cursor(w,h)
  let ret = button(x, y, w, h, enabled, hotkey, draw)
  advance(w,h)
  return ret

proc button*(self: Gui, w,h: int, enabled: bool = true, draw: proc(x,y,w,h:int, enabled: bool)): bool =
  let (x,y) = self.cursor(w,h)
  let ret = button(x, y, w, h, enabled, K_UNKNOWN, draw)
  advance(w,h)
  return ret

proc button*(self: Gui, text: string, enabled: bool = true, keycode: Keycode): bool =
  assert(area != nil)
  let w = if hExpand: area.maxX - area.minX else: textWidth(text) + hPadding * 2
  let h = if vExpand: area.maxY - area.minY else: fontHeight() * text.countLines() + vPadding * 2
  return button(text, w, h, enabled, keycode)

proc button*(self: Gui, text: string, enabled: bool = true): bool =
  assert(area != nil)
  let w = if hExpand: area.maxX - area.minX else: textWidth(text) + hPadding * 2
  let h = if vExpand: area.maxY - area.minY else: fontHeight() * text.countLines() + vPadding * 2
  return button(text, w, h, enabled)

proc box*(self: Gui, x,y,w,h: int) =
  element += 1
  if e.kind == gRepaint:
    setColor(backgroundColor)
    rrectfill(x,y,x+w-1,y+h-1)
    setColor(normalColor)
    rrect(x,y,x+w-1,y+h-1)
  elif e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x,y,w,h):
      hoverElement = element
      activeHoverElement = 0

proc sprite*(self: Gui, spr: int, x,y,w,h: int) =
  element += 1
  if e.kind == gRepaint:
    spr(spr, x, y)

proc ssprite*(self: Gui, spr: int, x,y,w,h: int, sw,sh: int) =
  element += 1
  if e.kind == gRepaint:
    let (tw,th) = spriteSize()
    spr(spr, if center: x + w div 2 - tw div 2 else: x, if center: y + h div 2 - th div 2 else: y, sw, sh)
  advance(w,h)

proc ssprite*(self: Gui, spr: int, w,h: int, sw,sh: int) =
  element += 1
  if e.kind == gRepaint:
    let (x,y) = self.cursor(w,h)
    let (tw,th) = spriteSize()
    spr(spr, if center: x + w div 2 - tw div 2 else: x, if center: y + h div 2 - th div 2 else: y, sw, sh)
  advance(w,h)

proc sprite*(self: Gui, spr: int, w,h: int) =
  element += 1
  if e.kind == gRepaint:
    let (x,y) = self.cursor(w,h)
    let (tw,th) = spriteSize()
    spr(spr, if center: x + w div 2 - tw div 2 else: x, if center: y + h div 2 - th div 2 else: y)
  advance(w,h)

proc sprite*(self: Gui, spr: int) =
  assert(area != nil)
  let (tw,th) = spriteSize()
  let w = if hExpand: area.maxX - area.minX else: tw
  let h = if vExpand: area.maxY - area.minY else: th
  sprite(spr, w, h)

proc empty*(self: Gui, w, h: int) =
  element += 1
  advance(w,h)

proc beginArea*(self: Gui, x,y,w,h: Pint, direction: GuiDirection = gTopToBottom, box: bool = false, modal: bool = false) =
  area = new(GuiArea)
  area.id = nextAreaId
  area.minX = x + (if box: hPadding else: 0)
  area.minY = y + (if box: vPadding else: 0)
  area.maxX = x + w - 1 - (if box: hPadding else: 0)
  area.maxY = y + h - 1 - (if box: vPadding else: 0)
  area.cursorX = x
  area.cursorY = y

  areas.add(area)

  nextAreaId += 1

  activeAreaId = area.id

  area.direction = direction
  case area.direction:
  of gLeftToRight:
    area.cursorX = area.minX + hSpacing
    area.cursorY = area.minY
  of gRightoLeft:
    area.cursorX = area.maxX - hSpacing
    area.cursorY = area.minY
  of gTopToBottom:
    area.cursorX = area.minX
    area.cursorY = area.minY + vSpacing
  of gBottomToTop:
    area.cursorY = area.maxY - vSpacing
    area.cursorX = area.minX

  if modal:
    modalArea = activeAreaId

  if box:
    self.box(x,y,w,h)

proc endArea*(self: Gui) =
  if areas.len > 0:
    var lastArea = area
    area = nil
    areas.delete(areas.high)
    if areas.len == 0:
      activeAreaId = 0
    else:
      activeAreaId = areas[areas.high].id
      area = areas[areas.high]
      if lastArea.direction == gLeftToRight:
        area.cursorY = lastArea.maxY
      elif lastArea.direction == gTopToBottom:
        area.cursorX = lastArea.maxX

proc beginHorizontal*(self: Gui, height: int, box: bool = false) =
  let area = areas[areas.high]
  beginArea(area.cursorX, area.cursorY, area.maxX - area.cursorX, height, gLeftToRight, box)

proc beginVertical*(self: Gui, width: int, box: bool = false) =
  let area = areas[areas.high]
  beginArea(area.cursorX, area.cursorY, width, area.maxY - area.cursorY, gTopToBottom, box)

proc draw*(self: Gui, onGui: proc()) =
  frame += 1
  element = 0
  e.kind = gRepaint
  onGui()
  if areas.len != 0:
    echo "ERROR: area was not ended correctly"

proc update*(self: Gui, onGui: proc(), dt: float32) =
  activeAreaId = 0
  modalArea = 0
  activeElement = 0
  nextAreaId = 1
  let (mx,my) = mouse()
  var lastCount = 0
  if mx != lastMouseX or my != lastMouseY:
    hoverElement = 0
    activeHoverElement = 0
    e.kind = gMouseMove
    e.x = mx
    e.y = my
    element = 0
    onGui()
    lastCount = element
  lastMouseX = mx
  lastMouseY = my
  if mousebtnp(0):
    e.kind = gMouseDown
    e.x = mx
    e.y = my
    element = 0
    onGui()
    wasMouseDown = true
  if not mousebtn(0) and wasMouseDown:
    e.kind = gMouseUp
    element = 0
    onGui()
    wasMouseDown = false
    downElement = 0
  if anyKeyp():
    e.kind = gKeyDown
    element = 0
    onGui()

