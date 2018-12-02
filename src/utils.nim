import nico
import strutils

type TextAlign* = enum
  taLeft
  taRight
  taCenter

var outlineColor: int = 0

proc setOutlineColor*(oc: int) =
  outlineColor = oc

proc printOutlineC*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  printc(text, x-scale, y, scale)
  printc(text, x+scale, y, scale)
  printc(text, x, y-scale, scale)
  printc(text, x, y+scale, scale)
  printc(text, x+scale, y+scale, scale)
  printc(text, x-scale, y-scale, scale)
  printc(text, x+scale, y-scale, scale)
  printc(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printc(text, x, y, scale)

proc printOutlineR*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  printr(text, x-scale, y, scale)
  printr(text, x+scale, y, scale)
  printr(text, x, y-scale, scale)
  printr(text, x, y+scale, scale)
  printr(text, x+scale, y+scale, scale)
  printr(text, x-scale, y-scale, scale)
  printr(text, x+scale, y-scale, scale)
  printr(text, x-scale, y+scale, scale)
  setColor(oldColor)
  printr(text, x, y, scale)

proc printOutline*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(outlineColor)
  print(text, x-scale, y, scale)
  print(text, x+scale, y, scale)
  print(text, x, y-scale, scale)
  print(text, x, y+scale, scale)
  print(text, x+scale, y+scale, scale)
  print(text, x-scale, y-scale, scale)
  print(text, x+scale, y-scale, scale)
  print(text, x-scale, y+scale, scale)
  setColor(oldColor)
  print(text, x, y, scale)

proc printShadow*(text: string, x, y: cint, scale: cint = 1) =
  let oldColor = getColor()
  setColor(0)
  print(text, x-scale, y, scale)
  setColor(oldColor)
  print(text, x, y, scale)

proc richPrintLength*(text: string): int =
  var i = 0
  while i < text.len:
    let c = text[i]
    if i + 2 < text.high and c == '<' and (text[i+2] == '>' or text[i+3] == '>'):
      i += (if text[i+2] == '>': 3 else: 4)
      continue
    i += 1
    result += glyphWidth(c)

proc richPrint*(text: string, x,y: int, align: TextAlign = taLeft, shadow: bool = false, step = -1) =
  ## prints but handles color codes <0>black <8>red etc <-> to return to normal

  var sx = x
  var x = x
  var y = y

  for text in text.split('\n'):
    let tlen = richPrintLength(text)

    let startColor = getColor()
    var i = 0
    var j = 0
    while i < text.len:
      if step != -1 and j >= step:
        break

      let c = text[i]
      if i + 2 < text.high and c == '<' and (text[i+2] == '>' or text[i+3] == '>'):
        let colStr = if text[i+2] == '>': text[i+1..i+1] else: text[i+1..i+2]
        let col = try: parseInt(colStr) except ValueError: startColor
        setColor(col)
        i += (if text[i+2] == '>': 3 else: 4)
        continue
      if shadow:
        printShadow($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
      else:
        print($c, x - (if align == taRight: tlen elif align == taCenter: tlen div 2 else: 0), y)
      x += glyphWidth(c)
      i += 1
      if c != ' ':
        j += 1
    setColor(startColor)
    y += fontHeight()
    x = sx

iterator safeIter*[T](a: seq[T]): T =
  let length = a.len
  for i in 0..<length:
    yield a[i]
