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
    gClick
  GuiEvent = object
    kind: GuiEventKind
    x,y: int
    button: int
  Gui* = ref object
    e: GuiEvent
    element*: int
    normalColor*: int
    hoverColor*: int
    activeColor*: int
    downColor*: int
    onColor*: int
    textColor*: int
    disabledColor*: int
    backgroundColor*: int
    buttonBackgroundColor*: int
    buttonBackgroundColorDisabled*: int
    hoverElement*: int
    activeElement*: int
    downElement*: int
    wasMouseDown: bool
    cursorX,cursorY: int
    minX,minY,maxX,maxY: int
    direction: GuiDirection
    areaActive: bool
    activeArea: int
    hSpacing*,vSpacing*: int
    hPadding*,vPadding*: int
    center*: bool
    hExpand*: bool
    vExpand*: bool
    modalArea*: int

var G*: Gui = new(Gui)
var lastMouseX,lastMouseY: int

proc pointInRect(px,py, x,y,w,h: int): bool =
  return px >= x and px <= x + w and py >= y and py <= y + h

proc advance(self: Gui, w,h: int) =
  if direction == gLeftToRight:
    cursorX += w + hSpacing
    if cursorX >= maxX:
      cursorX = minX
      cursorY += h + vSpacing
  elif direction == gRightoLeft:
    cursorX -= w + hSpacing
    if cursorX <= minX:
      cursorX = maxX
      cursorY += h + vSpacing
  elif direction == gTopToBottom:
    cursorY += h + vSpacing
    if cursorY >= maxY:
      cursorY = minY
      cursorX += w + hSpacing
  elif direction == gBottomToTop:
    cursorY -= h + vSpacing
    if cursorY <= minY:
      cursorY = maxY
      cursorX += w + hSpacing

proc cursor(self: Gui, w, h: int): (int,int) =
  result[0] = if direction == gRightoLeft: cursorX - w else: cursorX
  result[1] = if direction == gBottomToTop: cursorY - h else: cursorY

proc label*(self: Gui, text: string, x,y,w,h: int) =
  element += 1
  if e.kind == gRepaint:
    setColor(textColor)
    let nLines = text.countLines()
    richPrint(text, x + (if center: w div 2 else: hPadding), y + (if center: h div 2 - (fontHeight() * nLines) div 2 else: vPadding), if center: taCenter else: taLeft)

  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x, y, w, h):
      hoverElement = element

proc label*(self: Gui, text: string, w, h: int) =
  let (x,y) = self.cursor(w,h)
  label(text, x, y, w, h)
  advance(w,h)

proc label*(self: Gui, text: string) =
  let w = if hExpand: maxX - minX else: textWidth(text) + hPadding * 2
  let h = if vExpand: maxY - minY else: fontHeight() * text.countLines() + vPadding * 2
  label(text, w, h)

proc drawGuiString(self: Gui, text: string, x,y,w,h: int, enabled: bool) =
    setColor(if enabled: textColor else: disabledColor)
    let nLines = text.countLines()
    richPrint(text, x + (if center: w div 2 else: hPadding), y + (if center: h div 2 - (fontHeight() * nLines) div 2 else: vPadding), if center: taCenter else: taLeft)

proc button*(self: Gui, draw: proc(x,y,w,h: int, enabled: bool), x,y,w,h: int, enabled: bool = true): bool =
  element += 1
  if e.kind == gRepaint:
    setColor(if enabled == false: buttonBackgroundColorDisabled elif downElement == element: downColor else: buttonBackgroundColor)
    rrectfill(x,y,x+w,y+h)

    if enabled and activeElement == element:
      setColor(activeColor)
    elif enabled and hoverElement == element:
      setColor(hoverColor)
    else:
      setColor(normalColor)
    rrect(x,y,x+w,y+h)

    draw(x + hPadding, y + vPadding, w - hPadding * 2, h - vPadding * 2, enabled)

  if modalArea != 0 and activeArea != modalArea:
    return

  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x, y, w, h):
      hoverElement = element

  if enabled == false:
    return false

  if e.kind == gMouseDown:
    if pointInRect(e.x, e.y, x, y, w, h):
      downElement = element
  elif e.kind == gMouseUp:
    if pointInRect(e.x, e.y, x, y, w, h):
      if downElement == element:
        activeElement = element
        return true
  return false

proc button*(self: Gui, text: string, x,y,w,h: int, enabled: bool = true): bool =
  return button(proc(x,y,w,h: int, enabled: bool) = drawGuiString(self,text,x,y,w,h,enabled),x,y,w,h,enabled)

proc button*(self: Gui, text: string, w, h: int, enabled: bool = true): bool =
  let (x,y) = self.cursor(w,h)
  let ret = button(text, x, y, w, h, enabled)
  advance(w,h)
  return ret

proc button*(self: Gui, w,h: int, enabled: bool, draw: proc(x,y,w,h:int, enabled: bool)): bool =
  let (x,y) = self.cursor(w,h)
  let ret = button(draw, x, y, w, h, enabled)
  advance(w,h)
  return ret

proc button*(self: Gui, text: string, enabled: bool = true): bool =
  let w = if hExpand: maxX - minX else: textWidth(text) + hPadding * 2
  let h = if vExpand: maxY - minY else: fontHeight() * text.countLines() + vPadding * 2
  return button(text, w, h, enabled)

proc box*(self: Gui, x,y,w,h: int) =
  element += 1
  if e.kind == gRepaint:
    setColor(backgroundColor)
    rrectfill(x,y,x+w-1,y+h-1)
    setColor(normalColor)
    rrect(x,y,x+w-1,y+h-1)
  if e.kind == gMouseMove:
    if pointInRect(e.x, e.y, x,y,w,h):
      hoverElement = element

proc sprite*(self: Gui, spr: int, x,y,w,h: int) =
  spr(spr, x, y)

proc sprite*(self: Gui, spr: int, w,h: int) =
  let (x,y) = self.cursor(w,h)
  let (tw,th) = spriteSize()
  spr(spr, if center: x + w div 2 - tw div 2 else: x, if center: y + h div 2 - th div 2 else: y)
  advance(w,h)

proc sprite*(self: Gui, spr: int) =
  let (tw,th) = spriteSize()
  let w = if hExpand: maxX - minX else: tw
  let h = if vExpand: maxY - minY else: th
  sprite(spr, w, h)

proc empty*(self: Gui, w, h: int) =
  advance(w,h)

proc areaBegin*(self: Gui, x,y,w,h: int, direction: GuiDirection = gTopToBottom, box: bool = false, modal: bool = false) =
  if areaActive:
    echo "ERROR: areaBegin called when area already active"
    return

  activeArea += 1
  areaActive = true

  if modal:
    modalArea = activeArea

  minX = x + (if box: hPadding else: 0)
  minY = y + (if box: vPadding else: 0)
  maxX = x + w - 1 - (if box: hPadding else: 0)
  maxY = y + h - 1 - (if box: vPadding else: 0)
  self.direction = direction
  if direction == gLeftToRight:
    cursorX = minX + hSpacing
    cursorY = minY
  elif direction == gRightoLeft:
    cursorX = maxX - hSpacing
    cursorY = minY
  elif direction == gTopToBottom:
    cursorX = minX
    cursorY = minY + vSpacing
  elif direction == gBottomToTop:
    cursorY = maxY - vSpacing
    cursorX = minX

  if box:
    self.box(x,y,w,h)

proc areaEnd*(self: Gui) =
  if areaActive == false:
    echo "ERROR: areaEnd called when area not active"
  areaActive = false

proc draw*(self: Gui, onGui: proc()) =
  element = 0
  e.kind = gRepaint
  onGui()
  if areaActive == true:
    echo "ERROR: area was not ended correctly"

proc update*(self: Gui, onGui: proc(), dt: float32) =
  activeArea = 0
  modalArea = 0
  activeElement = 0
  element = 0
  let (mx,my) = mouse()
  if mx != lastMouseX or my != lastMouseY:
    hoverElement = 0
    e.kind = gMouseMove
    e.x = mx
    e.y = my
    onGui()
  lastMouseX = mx
  lastMouseY = my
  if mousebtnp(0):
    e.kind = gMouseDown
    e.x = mx
    e.y = my
    onGui()
    wasMouseDown = true
  if not mousebtn(0) and wasMouseDown:
    e.kind = gMouseUp
    onGui()
    wasMouseDown = false
    downElement = 0
