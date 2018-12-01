import nico
import nico/vec
import utils
import sequtils

import strutils

{.this:self.}

# README

discard """

Sacrifices must be made

serpent's Souls

Summon The Serpent

Inspirations:
  * Robin Hobb
  * Trudi Canavan
  * Time Barons
  * Advance Wars/Fire Emblem

Recruit people to your cause
Sacrifice them to the serpent statue
Once enough souls have been sacrificed the serpent will come to life (under the command of the last person sacrificed)
Aim is to save your town which is at war

2D advanced wars style game
Manage your small town with the serpent statue
Small number of followers

Being attacked by a much larger empire
Recruit an army
Capture nearby towns

 * Followers
 * Mages -> expensive, magical shield and fireballs, very powerful, until they run out of mana, can suck souls from enemies at close range
 * Soldiers -> strong vs mages, archers at close range
 * Archers -> strong vs soldiers
 * Town (each town has a number of sites)
   * Sites (sites store units and have actions with requirements)
    * Town Square (3 actions, sacrifice 10 followers to upgrade town)
    * serpent Square (only in capital, like town square) (sacrifice followers to serpent statue, needs 100 sacrifices to summon serpent god, sacrifice mages to extract all their souls)
    * Mage's Guild (convert followers to mages, 5 years)
    * Barracks (convert followers to soldiers, 1 year)
    * Archery (convert followers to archers, 1 year)
    * Church (with 3 followers, gain 1 follower)
    * Parade Grounds (send units to battle)
    * Mason (with 5 followers, 1 action to build a new site, with 3 followers, 1 action to build a new site, but lose one follower)

  World map
    tile grid with towns and obstacles, show armies (collections of units)
  Town map
    grid of sites
  Battle map
    tile grid with units and obstacles

  All turn based

  Each turn you can move all your units in a battle
  Move each army in the world
  Do 3 actions in each Town
    Relocate all units
    Gain a follower on any site
    Use site abilities
    Build a site (optionally replace an existing site)
    Upgrade town (3x3) x 3 actions -> (5x3) x4 actions -> (5x4) x 5 actions

"""

# CONSTANTS

const teamColors = [7,18,8]
const teamColors2 = [4,15,13]

const townNames = @[
  "Atencia",
  "Unria",
  "Aiquimuri",
  "Epiro",
  "Arairim",
  "Jeninga",
  "Linaflor",
  "Cabretillar",
  "Escochado",
  "Nemtora",
  "Pamayo",
  "Guadaruro",
  "Triguez",
  "Delguez",
  "Aldehuaia",
  "Moguel",
  "Quicas",
  "Araluyo",
  "Feisina",
  "Ibizia",
  "Lobuco",
  "Haciebun",
  "Nacutora",
  "San Corayu",
  "Bambapata",
  "Mala",
  "Acetista",
  "Tutina",
  "Castedon",
  "Veipana",
  "Montechuy",
  "Batabillo",
  "Dounia",
  "Marorem",
  "Quillos",
  "Cauquehaique",
  "Tebiro",
  "San Colicio",
  "Chicho",
  "La Rinca",
  "San Jolores",
  "Joacedes",
]

# TYPES
type
  Particle = object
    pos: Vec2f
    vel: Vec2f
    ttl: float32
    maxTtl: float32
    sheet: int
    startSpr,endSpr: int
    text: string
    color1,color2: int

  UnitKind = enum
    Follower
    Shaman
    Rebel
    Soldier
    Neutral

  Unit = ref object of RootObj
    kind: UnitKind
    pos: Vec2f
    souls: int
    flash: int
    hp: int
    usedAbility: bool

  SiteAbility = object
    name: string
    desc: string
    nFollowers: int
    nShamans: int
    nSoldiers: int
    nRebels: int
    nActions: int
    multiUse: bool
    startOfTurn: bool
    action: proc(site: Site)

  ShamanAbility = object
    name: string
    desc: string
    nActions: int
    multiUse: bool
    startOfTurn: bool
    action: proc(unit: Unit, site: Site)

  SiteSettings = object
    name: string
    desc: string
    spr: int
    actionsToBuild: int
    abilities: seq[SiteAbility]

  Site = ref object of RootObj
    settings: SiteSettings
    town: Town
    pos: Vec2i
    used: bool
    units: seq[Unit]

  Town = ref object of RootObj
    pos: Vec2i
    name: string
    size: int
    width: int
    height: int
    actions: int
    sites: seq[Site]
    rebellion: int
    team: int

  Army = ref object of RootObj
    pos: Vec2i
    units: seq[Unit]
    team: int
    source: Town
    dest: Town
    moved: bool

type InputKind = enum
  SelectSite
  SelectSiteToBuild
  Relocate
  PlaceUnit
  MoveArmy

# PREPROCS
proc expand(self: Town)
proc newSite(town: Town, siteSettings: SiteSettings, x, y: int): Site {.discardable.}
proc newParticle*(pos: Vec2f, vel: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int)
proc newParticleText*(pos: Vec2f, vel: Vec2f, ttl: float32, text: string, color1,color2: int)

proc newUnit(unitKind: UnitKind): Unit =
  result = new(Unit)
  result.kind = unitKind
  result.souls = 1
  result.flash = 5
  result.hp = 1
  result.usedAbility = false

proc removeFollower(self: Site) =
  for i,u in units:
    if u.kind == Follower:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      break

proc removeShaman(self: Site): Unit =
  for i,u in units:
    if u.kind == Shaman:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      return u
  return nil

proc removeRebel(self: Site): Unit {.discardable.} =
  for i,u in units:
    if u.kind == Rebel:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      return u
  return nil

proc removeSoldier(self: Site): Unit {.discardable.} =
  for i,u in units:
    if u.kind == Soldier:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      return u
  return nil

proc getFollowerCount(self: Site): int =
  var count = 0
  for i,u in units:
    if u.kind == Follower:
      count += 1
  return count

proc getShamanCount(self: Site): int =
  var count = 0
  for i,u in units:
    if u.kind == Shaman:
      count += 1
  return count

proc getRebelCount(self: Site): int =
  var count = 0
  for i,u in units:
    if u.kind == Rebel:
      count += 1
  return count

proc getSoldierCount(self: Site): int =
  var count = 0
  for i,u in units:
    if u.kind == Soldier:
      count += 1
  return count

proc getSoldierCount(self: Town): int =
  var count = 0
  for s in sites:
    for i,u in s.units:
      if u.kind == Soldier:
        count += 1
  return count

proc getRebelCount(self: Town): int =
  var count = 0
  for s in sites:
    for i,u in s.units:
      if u.kind == Rebel:
        count += 1
  return count

# GLOBALS
var particles: seq[Particle]
var time: float32
var frame: uint32
var selectedSite: Site
var currentTown: Town
var currentArmy: Army
var placingUnits: seq[Unit]
var placingUnitSource: Site
var serpentSouls = 0
var inputMode: InputKind
var selectedUnit: Unit
var hoverUnit: Unit
var unitsMoved = 0
var buildPreview: SiteSettings
var forcedLabour = false
var towns: seq[Town]
var armies: seq[Army]
var pulling: bool

# CONSTANTS 2

let shamanAbilities = @[
  ShamanAbility(name: "Fireball", desc: "Kill all Followers and Rebels on Site", nActions: 2, action: proc(unit: Unit, site: Site) =
    echo "fireball!"
    for u in site.units:
      if u.kind == Follower or u.kind == Rebel:
        unit.souls += 1
        u.hp = 0
  ),
]

let siteEmpty = SiteSettings(name: "", abilities: @[
  SiteAbility(name: "Build Site", desc: "Choose a new site to place", nFollowers: 3, nActions: 0, action: proc(site: Site) =
    # open list of sites to build (do we have a hand?)
    # select one, build it
    forcedLabour = false
    inputMode = SelectSiteToBuild
  ),
  SiteAbility(name: "Build Site (forced labour)", desc: "Choose a new site to place\nbut lose a follower", nFollowers: 2, nActions: 0, action: proc(site: Site) =
    inputMode = SelectSiteToBuild
    forcedLabour = true
  ),
])


let siteSquare = SiteSettings(name: "Village Center", spr: 0, abilities: @[
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()
  )
])

let siteSerpent = SiteSettings(name: "Serpent Totem", spr: 1, abilities: @[
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a follower and let their\nsoul flow into the Serpent", nFollowers: 2, nActions: 0, multiUse: true, action: proc(site: Site) =
    # kill 1 follower, capture one soul
    site.removeFollower()
    serpentSouls += 1
    site.town.rebellion += 1
  ),
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a Shaman and release\nall their captured Souls", nFollowers: 1, nShamans: 1, multiUse: true, nActions: 0, action: proc(site: Site) =
    # kill 1 shaman, capture their souls
    let mage = site.removeShaman()
    serpentSouls += 1
    serpentSouls += mage.souls
    site.town.rebellion += 1
  ),
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()

  )
])

let siteChurch = SiteSettings(name: "Temple", desc: "Control the people", actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Recruit", desc: "Gain 1 follower on any site", nFollowers: 3, nActions: 0, action: proc(site: Site) =
    # gain 1 follower
    inputMode = PlaceUnit
    placingUnits = @[newUnit(Follower)]
  ),
  SiteAbility(name: "Re-educate", desc: "Convert Rebels into Followers", nFollowers: 3, nRebels: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Rebel:
        u.kind = Follower
        u.flash = 5
  ),
  SiteAbility(name: "Pacify", desc: "Reduce rebellion for each\nfollower in the Temple", nFollowers: 3, nActions: 2, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        site.town.rebellion -= 1
    if site.town.rebellion < 0:
      site.town.rebellion = 0
  ),
])

let siteBarracks = SiteSettings(name: "Barracks", desc: "Train soldiers", actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train", desc: "Convert a Follower into a Soldier", nFollowers: 1, startOfTurn: true, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.kind = Soldier
        u.flash = 5
        break
  ),
  SiteAbility(name: "Train", desc: "Convert a Follower into a Soldier", nFollowers: 1, nActions: 1, multiUse: true, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.kind = Soldier
        u.flash = 5
        break
  ),
])

let siteAltar = SiteSettings(name: "Altar", desc: "Motivate followers", actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Motivate", desc: "Sacrifice a follower\nat Altar for an\nextra action", nFollowers: 2, nActions: 0, action: proc(site: Site) =
    # kill 1 follower, gain 1 action
    site.removeFollower()
    site.town.actions += 1
    site.town.rebellion += 1
  ),
])

let siteGuild = SiteSettings(name: "Training Hut", desc: "Train powerful Shaman", actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train Shaman", desc: "Convert a Follower into a Shaman", nFollowers: 1, nShamans: 1, nActions: 2, action: proc(site: Site) =
    # turn a follower into a Shaman
    for u in site.units:
      if u.kind == Follower:
        u.kind = Shaman
        u.flash = 5
        break
  ),
  SiteAbility(name: "Train Shaman", desc: "Convert a Follower into a Shaman", nFollowers: 5, nShamans: 0, nActions: 2, action: proc(site: Site) =
    for i in 0..<4:
      site.removeFollower()
    for u in site.units:
      if u.kind == Follower:
        u.kind = Shaman
        u.flash = 5
        break
  ),
])

let siteHouse = SiteSettings(name: "Home", desc: "A place of reproduction", spr: 2, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Reproduce", nFollowers: 2, nActions: 0, startOfTurn: true, action: proc(site: Site) =
    site.units.insert(newUnit(Follower), 0)
  ),
  SiteAbility(name: "Demolish", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        break
  ),
])

let siteObstacle = SiteSettings(name: "Slum", desc: "A filty obstacle", spr: 0, actionsToBuild: 0, abilities: @[
  SiteAbility(name: "Sow Rebellion", desc: "creates rebels", startOfTurn: true, action: proc(site: Site) =
    if site.town.team != 0:
      site.town.rebellion += 1
  ),
  SiteAbility(name: "Demolish", desc: "clear space, increase rebellion", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        site.town.rebellion += 1
        break
  ),
])

let siteWatchtower = SiteSettings(name: "Watchtower", desc: "Supress Rebellion", spr: 0, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Supress Rebellion", nFollowers: 1, nActions: 0, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - 1, 0)
  ),
  SiteAbility(name: "Demolish", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        break
  ),
])

let buildMenu: seq[SiteSettings] = @[
  siteHouse,
  siteAltar,
  siteGuild,
  siteChurch,
  siteBarracks,
  siteWatchtower,
]

# PROCS

proc newParticle*(pos: Vec2f, vel: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int) =
  particles.add(Particle(pos: pos, vel: vel, ttl: ttl, maxTtl: ttl, sheet: sheet, startSpr: startSpr, endSpr: endSpr))

proc newParticleText*(pos: Vec2f, vel: Vec2f, ttl: float32, text: string, color1,color2: int) =
  particles.add(Particle(pos: pos, vel: vel, ttl: ttl, maxTtl: ttl, text: text, color1: color1, color2: color2))




proc draw(self: Unit, x,y: int) =
  let (cx,cy) = getCamera()
  let targetPos = vec2f(x,y)
  if particles.len == 0:
    pos = lerp(pos, targetPos, 0.5)
    if (pos - targetPos).magnitude < 0.5:
      pos = targetPos

  if selectedUnit == self:
    pal(1,21)
  elif hoverUnit == self:
    pal(1,22)

  if pos == targetPos and flash > 0 and frame mod 4 < 2:
    pal(1, 21)
    flash -= 1

  let x = pos.x
  let y = pos.y

  if kind == Follower:
    spr(1, x, y)
  elif kind == Shaman:
    spr(2, x, y)
  elif kind == Rebel:
    spr(3, x, y)
  elif kind == Soldier:
    spr(4, x, y)
  elif kind == Neutral:
    spr(5, x, y)

  pal()



proc draw(self: Site, x,y: int) =
  setColor(31)
  rectfill(x, y, x + 48, y + 48)

  #setSpritesheet(1)
  #spr(settings.spr, x + 8, y + 8)

  setColor(if self.used: 23 elif self == selectedSite: 21 else: 7)
  if self == selectedSite:
    rect(x-1, y-1, x + 49, y + 49)
  rect(x, y, x + 48, y + 48)
  setColor(7)
  var yi = y + 4

  if settings.spr == 0 or true:
    for line in settings.name.split(" "):
      printc(line, x + 25, yi)
      yi += 10

  setSpritesheet(0)

  var xi = x + 6
  yi = y + 24
  var row = 0
  for u in units:
    u.draw(xi,yi)
    xi += 7
    if xi > x + 48 - 10:
      row += 1
      if row mod 2 == 0:
        xi = x + 6
      else:
        xi = x + 4
      yi += 5

proc draw(self: SiteAbility, x, y, w, h: int, disabled: bool) =
  var y = y
  var x = x
  hline(0, y - 5, w)
  if startOfTurn:
    setColor(25)
    richPrint("(start turn)</> " & name, 10, y)
  elif disabled:
    setColor(25)
    richPrint("<27>(" & $nActions & ")</> " & name & (if multiUse: " <27>multi-use" else: ""), 10, y)
  else:
    setColor(22)
    richPrint("<8>(" & $nActions & ")</> " & name & (if multiUse: " <8>multi-use" else: ""), 10, y)
  y += 10
  x = 10
  var j = 0
  for i in 0..<nFollowers:
    spr(1, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nShamans:
    spr(2, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nRebels:
    spr(3, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nSoldiers:
    spr(4, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0

  y += 10
  setColor(23)
  for line in desc.split("\n"):
    print(line, 10, y)
    y += 10

proc draw(self: ShamanAbility, x, y, w, h: int, disabled: bool) =
  var y = y
  var x = x
  hline(0, y - 5, w)
  if startOfTurn:
    setColor(25)
    richPrint("(start turn)</> " & name, 10, y)
  elif disabled:
    setColor(25)
    richPrint("<27>(" & $nActions & ")</> " & name & (if multiUse: " <27>multi-use" else: ""), 10, y)
  else:
    setColor(22)
    richPrint("<8>(" & $nActions & ")</> " & name & (if multiUse: " <8>multi-use" else: ""), 10, y)
  y += 10
  x = 10
  setColor(23)
  for line in desc.split("\n"):
    print(line, 10, y)
    y += 10

proc draw(self: Town) =
  let cx = screenWidth div 2 - width * 25
  let cy = screenHeight div 2 - height * 25
  for y in 0..<height:
    for x in 0..<width:
      let site = sites[width * y + x]
      if site == nil:
        setColor(15)
        rect(cx + x * 50, cy + y * 50, cx + x * 50 + 48, cy + y * 50 + 48)
      else:
        site.draw(cx + x * 50, cy + y * 50)

proc expand(self: Town) =
  if size < 2:
    size += 1
  if size == 1:
    width = 5
    height = 3
    var newSites = newSeq[Site](width * height)
    for y in 0..<3:
      for x in 0..<3:
        newSites[y * 5 + x + 1] = sites[y * 3 + x]
    sites = newSites
    for i,site in sites.mpairs:
      if site == nil:
        site = newSite(self, siteEmpty, i mod 5, i div 5)
  elif size == 2:
    width = 5
    height = 4
    sites.setLen(5*4)
    for i,site in sites.mpairs:
      if site == nil:
        site = newSite(self, siteEmpty, i mod 5, i div 5)


proc endTurn() =
  # mark all sites as unused
  # reset actions
  # for every rebel, increase rebellion
  for army in armies:
    army.moved = false

  for town in towns:
    for site in town.sites:
      site.used = false
      for u in site.units:
        u.usedAbility = false
      # kill a rebel for each soldier on site
      var nSoldiers = site.getSoldierCount()
      var nRebels = site.getRebelCount()
      for i in 0..<nSoldiers:
        site.removeRebel()
      for i in 0..<nRebels:
        if site.removeSoldier() == nil:
          site.removeFollower()

    if town.team == 1:
      town.actions = 3 + town.size
    else:
      town.actions = 0

    # for every 5 rebellion, make a rebel from a follower (up to one per site)
    # for every soldier, reduce rebellion by 1

    town.rebellion = clamp(town.rebellion + town.getRebelCount(), 0, town.sites.len * 5)

    # for every 5 rebellion, make a new rebel
    let newRebels = clamp(town.rebellion div 5, 0, 3 + town.size)
    for i in 0..<newRebels:
      # pick a random site and spawn a rebel
      let r = rnd(town.sites.high)
      for k,site in town.sites:
        if k == r:
          site.units.add(newUnit(Rebel))

    for site in town.sites:
      site.used = false
      for ab in site.settings.abilities:
        if ab.startOfTurn:
          if site.getFollowerCount() < ab.nFollowers:
            continue
          if site.getShamanCount() < ab.nShamans:
            continue
          if site.getRebelCount() < ab.nRebels:
            continue
          ab.action(site)

    town.rebellion = clamp(town.rebellion, 0, town.sites.len * 5)

proc newArmy(pos: Vec2i, team: int, units: seq[Unit]): Army =
  var army = new(Army)
  army.pos = pos
  army.team = team
  army.units = units
  return army

proc newTown(name: string, size: int, pos: Vec2i): Town =
  var town = new(Town)
  town.pos = pos
  town.size = size
  town.name = name
  town.actions = 0
  case size:
    of 0:
      town.width = 3
      town.height = 3
    of 1:
      town.width = 5
      town.height = 3
    of 2:
      town.width = 5
      town.height = 4
    else:
      discard
  town.sites = newSeq[Site](town.width * town.height)
  return town

proc newSite(town: Town, siteSettings: SiteSettings, x, y: int): Site {.discardable.} =
  var site = new(Site)
  site.settings = siteSettings
  site.town = town
  town.sites[town.width * y + x] = site
  return site

proc gameInit() =
  loadSpritesheet(0, "spritesheet.png", 8, 8)
  loadSpritesheet(1, "tileset.png", 32, 32)
  loadSpritesheet(2, "tilesetWorld.png", 8, 8)


  loadMap(0, "map.json")
  setMap(0)

  particles = @[]
  towns = @[]
  armies = @[]

  for y in 0..<mapHeight():
    for x in 0..<mapWidth():
      let t = mget(x,y)
      if t in [7.uint8,8,9,10,11,12,13,14,15]:
        mset(x,y,0)
        var town: Town = nil
        if t == 7 or t == 10 or t == 13:
          town = newTown(rnd(townNames), 0, vec2i(x, y))
          var center = newSite(town, siteSquare, 1, 1)
        elif t == 8 or t == 11 or t == 14:
          town = newTown(rnd(townNames), 1, vec2i(x, y))
          var center = newSite(town, siteSquare, 2, 1)
        elif t == 9 or t == 12 or t == 15:
          town = newTown(rnd(townNames), 2, vec2i(x, y))
          var center = newSite(town, siteSquare, 2, 2)

        if t in [7.uint8,8,9]:
          town.team = 0
        elif t in [10.uint8,11,12]:
          town.team = 2
        elif t in [13.uint8,14,15]:
          town.team = 1
          var townSerpent = newSite(town, siteSerpent, 1, 1)
          for i in 0..<5:
            townSerpent.units.add(newUnit(Follower))
          for i in 0..<1:
            townSerpent.units.add(newUnit(Shaman))
          selectedSite = townserpent
          var townHouse = newSite(town, siteHouse, 0, 1)
          for i in 0..<2:
            townHouse.units.add(newUnit(Follower))
          currentTown = town
          currentTown.actions = 3

        for i,site in town.sites.mpairs:
          if site == nil:
            if town == currentTown:
              site = newSite(town, siteEmpty, i mod town.width, i div town.width)
            else:
              site = newSite(town, siteObstacle, i mod town.width, i div town.width)

        towns.add(town)

  serpentSouls = 0


proc gameUpdate(dt: float32) =
  time += dt
  hoverUnit = nil
  var hoverSite: Site = nil
  var (mx,my) = mouse()

  if currentTown != nil:
    for site in currentTown.sites:
      for u in site.units:
        if u.hp <= 0:
          newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      site.units.keepItIf(it.hp > 0)

  if currentTown != nil:
    for i, site in currentTown.sites:
      if site != nil:
        let cx = screenWidth div 2 - currentTown.width * 25
        let cy = screenHeight div 2 - currentTown.height * 25

        let x = i mod currentTown.width
        let y = i div currentTown.width

        if mx >= cx + x * 50 and my >= cy + y * 50 and mx <= cx + x * 50 + 48 and my <= cy + y * 50 + 48:
          hoverSite = site
        for u in site.units:
          if mx >= u.pos.x - 1 and mx <= u.pos.x + 7 and my >= u.pos.y - 1 and my <= u.pos.y + 7:
            hoverUnit = u
            break

  if inputMode == Relocate or inputMode == PlaceUnit:
    if mousebtnp(0):
      if hoverUnit != nil or placingUnits.len == 0 and inputMode == Relocate:
        pulling = true
      else:
        pulling = false

    if mousebtnpr(0,15):
      if pulling:
        if hoverUnit != nil and hoverSite != nil:
          if hoverUnit.kind == Rebel or hoverUnit.kind == Neutral:
            return
          placingUnits.add(hoverUnit)
          placingUnitSource = hoverSite
          let i = hoverSite.units.find(hoverUnit)
          if i != -1:
            hoverSite.units.delete(i)
          return
      else:
        if hoverSite != nil:
          if placingUnits.len > 0:
            var u = placingUnits[placingUnits.high]
            placingUnits.delete(placingUnits.high)
            hoverSite.units.add(u)
            if placingUnits.len == 0 and inputMode == PlaceUnit:
              inputMode = SelectSite

  if btnpr(pcStart, 30):
    if selectedSite != nil:
      selectedSite.units.add(newUnit(Follower))

  if mousebtnp(0):
    var (mx,my) = mouse()
    # check which thing they clicked on
    if my > screenHeight - 30:
      if mx > screenWidth div 4 * 3:
        if inputMode == SelectSite:
          endTurn()
          return
        elif inputMode == SelectSiteToBuild:
          # cancel build
          selectedSite.used = false
          inputMode = SelectSite
          return
      else:
        # bottom bar
        if currentArmy != nil and inputMode == SelectSite and currentArmy.moved == false:
          inputMode = MoveArmy
          return
        elif currentArmy != nil and inputMode == MoveArmy:
          inputMode = SelectSite
          return
        elif currentTown != nil and inputMode == SelectSite:
          if currentTown.actions > 0:
            currentTown.actions -= 1
            inputMode = Relocate
            placingUnits = @[]
            unitsMoved = 0
            return
        elif inputMode == Relocate and placingUnits.len == 0:
          inputMode = SelectSite
          if unitsMoved == 0:
            currentTown.actions += 1
          unitsMoved = 0
          return
    if mx < screenWidth div 4 and (inputMode == SelectSite or inputMode == Relocate or inputMode == MoveArmy):
      # choose town or army on worldMap
      let tx = mx div 8
      let ty = my div 8
      if inputMode == MoveArmy and currentArmy != nil:
        if abs(tx - currentArmy.pos.x) <= 1 and abs(ty - currentArmy.pos.y) <= 1 and (tx == currentArmy.pos.x and ty == currentArmy.pos.y) == false:
          for town in towns:
            if town.pos.x == tx and town.pos.y == ty:
              # move army into town
              currentTown = town
              if currentTown.team != 1:
                for s in currentTown.sites:
                  for u in s.units:
                    if u.kind == Neutral:
                      u.kind = Rebel
                      u.flash = 5
              currentTown.team = 1
              selectedSite = nil
              placingUnits = currentArmy.units
              inputMode = Relocate
              armies.delete(armies.find(currentArmy))
              currentArmy = nil
              return
          currentArmy.pos = vec2i(tx, ty)
          currentArmy.moved = true
          inputMode = SelectSite
          return

      if inputMode == Relocate:
        if placingUnits.len == 0:
          if abs(tx - currentTown.pos.x) <= 1 and abs(ty - currentTown.pos.y) <= 1 and (tx == currentTown.pos.x and ty == currentTown.pos.y) == false:
            var army: Army = nil
            for i, army in armies:
              if army.pos.x == tx and army.pos.y == ty:
                if army.team == 1:
                  placingUnits = army.units
                  armies.delete(i)
                  return
        else:
          if abs(tx - currentTown.pos.x) <= 1 and abs(ty - currentTown.pos.y) <= 1 and (tx == currentTown.pos.x and ty == currentTown.pos.y) == false:
            var army: Army = nil
            for a in armies:
              if a.pos.x == tx and a.pos.y == ty:
                army = a
                break
            if army != nil:
              if army.team != 1:
                return
            if army == nil:
              army = newArmy(vec2i(tx,ty), 1, placingUnits)
              army.source = currentTown
              army.moved = true
              armies.add(army)
              unitsMoved += placingUnits.len
            else:
              army.units.add(placingUnits)
              army.moved = true
              unitsMoved += placingUnits.len
            placingUnits = @[]
            return
      elif inputMode == SelectSite:
        for town in towns:
          if town.pos.x == tx and town.pos.y == ty:
            currentTown = town
            currentArmy = nil
            selectedSite = nil
            break
        for army in armies:
          if army.pos.x == tx and army.pos.y == ty:
            currentArmy = army
            currentTown = nil
            selectedSite = nil
            break

    if mx > screenWidth div 4 * 3 and selectedSite != nil:
      # right bar
      if inputMode == SelectSiteToBuild:
        if selectedSite.settings.name == "":
          # select build preview
          let ty = (my - 40) div 30
          if ty < buildMenu.len:
            var building = buildMenu[ty]
            if building.actionsToBuild <= currentTown.actions:
              currentTown.actions -= building.actionsToBuild
              for i, site in currentTown.sites:
                if site == selectedSite:
                  var oldSite = site
                  var newSite = newSite(currentTown, building, i mod currentTown.width, i div currentTown.width)
                  currentTown.sites[i] = newSite
                  newSite.units = oldSite.units
                  inputMode = SelectSite
                  selectedSite = newSite
                  if forcedLabour:
                    newSite.removeFollower()
                    currentTown.rebellion += 1
                  break
      elif inputMode == SelectSite:
        if selectedUnit != nil:
          # shaman ability select
          let ay = (my - 10) div 50
          echo "ShamanAbility: ", ay
          if ay < shamanAbilities.len:
            let ability = shamanAbilities[ay]
            echo "ability: ", ability.name
            # check if we meet the requirements
            if currentTown.actions < ability.nActions:
              return
            if selectedUnit.usedAbility and ability.multiUse == false:
              return
            currentTown.actions -= ability.nActions
            if ability.multiUse == false:
              selectedUnit.usedAbility = true
            ability.action(selectedUnit, selectedSite)
            return
        else:
          # ability select
          let ay = (my - 10) div 50
          if ay < selectedSite.settings.abilities.len:
            let ability = selectedSite.settings.abilities[ay]
            # check if we meet the requirements
            if currentTown.actions < ability.nActions:
              return
            if selectedSite.getFollowerCount() < ability.nFollowers:
              return
            if selectedSite.getShamanCount() < ability.nShamans:
              return
            if selectedSite.getRebelCount() < ability.nRebels:
              return
            if ability.startOfTurn:
              return
            if selectedSite.used and ability.multiUse == false:
              return
            currentTown.actions -= ability.nActions
            if ability.multiUse == false:
              selectedSite.used = true
            ability.action(selectedSite)
            return

    elif inputMode == SelectSite:
      selectedUnit = nil
      # select shaman
      if hoverUnit != nil and hoverUnit.kind == Shaman:
        selectedUnit = hoverUnit
        if currentTown != nil:
          for site in currentTown.sites:
            if site != nil:
              for u in site.units:
                if u == selectedUnit:
                  selectedSite = site
                  break
        return

    if currentTown != nil:
      # select site
      var sx = screenWidth div 2 - 25 * currentTown.width
      var sy = screenHeight div 2 - 25 * currentTown.height
      mx -= sx
      my -= sy
      let tx = mx div 50
      let ty = my div 50
      if tx >= 0 and tx < currentTown.width and ty >= 0 and ty < currentTown.height:
        var site = currentTown.sites[ty * currentTown.width + tx]
        if site != nil:
          if inputMode == SelectSite:
            selectedSite = site

proc gameDraw() =
  frame += 1
  setCamera()
  setColor(1)
  rectfill(0,0,screenWidth,screenHeight)

  if currentArmy != nil:
    # draw army info
    setColor(3)
    rectfill(screenWidth div 4, 0, screenWidth div 4 * 3, screenHeight - 32)
    setColor(teamColors[currentArmy.team])
    printc("Army", screenWidth div 2, 20)
    var x = screenWidth div 2 - currentArmy.units.len * 9
    var y = screenHeight div 2
    for i, unit in currentArmy.units:
      unit.draw(x, y)
      x += 7
      if (i + 1) mod 10 == 0:
        x = screenWidth div 2 - currentArmy.units.len * 9
        y += 6
      elif (i + 1) mod 5 == 0:
        x += 3

  if currentTown != nil:
    currentTown.draw()

  setCamera()

  block showWorldMap:
    # World Map
    setColor(3)
    rectfill(0,0,screenWidth div 4 - 1, screenHeight - 32)

    setSpritesheet(2)
    mapDraw(0,0,mapWidth(),mapHeight(),0,0)

    for town in towns:
      pal(7, teamColors[town.team])
      spr(7 + town.size, town.pos.x * 8, town.pos.y * 8)
      pal()

      if town == currentTown:
        let nActions = 3 + town.size
        for i in 0..<nActions*2:
          let angle = (TAU / (nActions*2).float32) * i.float32 + time
          setColor(21)
          if i mod 2 == 0:
            if town.actions > i div 2:
              setColor(8)
            else:
              setColor(1)
          circfill(town.pos.x * 8 + 4 + cos(angle) * 8, town.pos.y * 8 + 4 + sin(angle) * 8, 2)
      elif town.team == 1:
        let nActions = 3 + town.size
        for i in 0..<nActions*2:
          let angle = (TAU / (nActions*2).float32) * i.float32
          setColor(21)
          if i mod 2 == 0:
            if town.actions > i div 2:
              setColor(8)
            else:
              setColor(1)
          circfill(town.pos.x * 8 + 4 + cos(angle) * 6, town.pos.y * 8 + 4 + sin(angle) * 6, 2)


      if town.actions > 0:
        setColor(8)
        printc("(" & $town.actions & ")", town.pos.x * 8 + 4, town.pos.y * 8 - 20)

    for army in armies:
      pal(7, teamColors[army.team])
      pal(4, teamColors2[army.team])
      spr(32, army.pos.x * 8, army.pos.y * 8)
      pal()

      if army == currentArmy:
        setColor(21)
        for i in 0..<7:
          let angle = (TAU / 7.0) * i.float32 + time
          circfill(army.pos.x * 8 + 4 + cos(angle) * 8, army.pos.y * 8 + 4 + sin(angle) * 8, 2)

      if army.moved == false:
        setColor(8)
        printc("(1)", army.pos.x * 8 + 4, army.pos.y * 8 - 20)


  setColor(15)
  vline(screenWidth div 4, 0, screenHeight)

  setSpritesheet(0)

  # Site Info
  if inputMode == SelectSiteToBuild:
    var w = screenWidth div 4
    setCamera(-(w * 3), 0)
    setColor(21)
    var y = 10
    printc("Select new Site to Build", w div 2, y)
    y += 30

    # show options for building
    for site in buildMenu:
      setColor(22)
      if currentTown.actions < site.actionsToBuild:
        richPrint("<27>(" & $site.actionsToBuild & ")</> <23>" & site.name, 4, y)
      else:
        richPrint("<8>(" & $site.actionsToBuild & ")</> " & site.name, 4, y)
      y += 10
      setColor(24)
      print(site.desc, 4, y)
      y += 10
      setColor(15)
      hline(0, y - 25, screenWidth div 4)
      hline(0, y + 5, screenWidth div 4)
      y += 10

    y += 20
  elif inputMode == SelectSite and selectedUnit != nil:
    var w = screenWidth div 4
    setCamera(-(w * 3), 0)
    setColor(21)
    var y = 10
    printc("Shaman", w div 2, y)
    y += 10
    printc("Souls: " & $selectedUnit.souls, w div 2, y)

    setColor(15)
    vline(0, 0, screenHeight)
    hline(0, y + 20, w)

    y += 40
    var x = 0

    # draw abilities
    for k,ability in shamanAbilities:
      ability.draw(x, y, w, 50, selectedUnit.usedAbility or currentTown.actions < ability.nActions)
      y += 50

  elif inputMode == SelectSite and selectedSite != nil and currentTown != nil:
    var w = screenWidth div 4
    setCamera(-(w * 3), 0)
    setColor(21)
    var y = 10
    printc(if selectedSite.settings.name == "": "Empty Land" else: selectedSite.settings.name, w div 2, y)

    setColor(15)
    vline(0, 0, screenHeight)
    hline(0, y + 20, w)

    y += 40
    var x = 0

    # draw abilities
    for k,ability in selectedSite.settings.abilities:
      ability.draw(x, y, w, 50, selectedSite.used or ability.nActions > currentTown.actions or ability.nFollowers > selectedSite.getFollowerCount or ability.nShamans > selectedSite.getShamanCount or ability.nSoldiers > selectedSite.getSoldierCount)
      y += 50

  setCamera()

  if currentArmy != nil:
    if inputMode == SelectSite:
      if currentArmy.moved == false:
        setColor(22)
        printc("Move Army", screenWidth div 2, screenHeight - 25)
      else:
        setColor(24)
        printc("Already moved", screenWidth div 2, screenHeight - 25)
    elif inputMode == MoveArmy:
      setColor(22)
      printc("Select Destination", screenWidth div 2, screenHeight - 25)

  elif currentTown != nil:
    setColor(teamColors[currentTown.team])
    printc(currentTown.name, screenWidth div 2, 10)
    setColor(22)
    richPrint("actions: <8>(" & $currentTown.actions & ")", screenWidth div 2, 20, taCenter)
    printc("serpent souls: " & $serpentSouls & "/100", screenWidth div 2, 30)
    richPrint("rebellion: <27>" & $currentTown.rebellion & "</> <27>+" & $currentTown.getRebelCount(), screenWidth div 2, 40, taCenter)

    setColor(15)
    hline(0, screenHeight - 32, screenWidth)

    if inputMode == SelectSite:
      if currentTown.actions > 0:
        setColor(22)
      else:
        setColor(25)
      richPrint("<8>(1)</> Relocate", screenWidth div 2, screenHeight - 30, taCenter)
      setColor(23)
      printc("Relocate any number of units", screenWidth div 2, screenHeight - 20)
    elif inputMode == Relocate and placingUnits.len == 0:
      setColor(22)
      printc("(Done Relocating)", screenWidth div 2, screenHeight - 30)
      setColor(23)
      printc("Click when finished relocating", screenWidth div 2, screenHeight - 20)

  if inputMode == SelectSite:
    var warning = false
    var actionsLeft = 0
    for town in towns:
      if town.team == 1 and town.actions > 0:
        warning = true
        actionsLeft += town.actions
    for army in armies:
      if army.team == 1 and army.moved == false:
        warning = true
        actionsLeft += 1

    if warning:
      setColor(5)
      printc("End Turn (" & $actionsLeft & " actions left)", screenWidth - 70, screenHeight - 20)
    else:
      setColor(22)
      printc("End Turn", screenWidth - 70, screenHeight - 20)
  elif inputMode == SelectSiteToBuild:
    setColor(22)
    printc("Cancel Build", screenWidth - 70, screenHeight - 20)

  # particles
  for p in mitems(particles):
    setSpritesheet(p.sheet)
    if p.text != "":
      setColor(if frame mod 8 < 4: p.color1 else: p.color2)
      printOutlineC(p.text, p.pos.x, p.pos.y)
    else:
      let a = p.ttl / p.maxTtl
      let f = lerp(p.startSpr.float32,p.endSpr.float32,a).int
      spr(f, p.pos.x, p.pos.y)
    p.pos += p.vel
    p.ttl -= 1/30

  particles.keepItIf(it.ttl > 0)

  # cursor

  block drawCursor:
    setSpritesheet(0)
    let (mx,my) = mouse()
    spr(0, mx, my)
    var x = 0
    var y = 0
    for i in countdown(placingUnits.high,0):
      let u = placingUnits[i]
      u.draw(mx + 4 + x, my + 4 + y)
      x += 6
      if x >= 6 * 5:
        x = 0
        y += 8

# INIT
nico.init("impbox", "ld43")

loadConfig()
loadPaletteFromGPL("palette.gpl")
loadFont(0, "sins-v2.1.png", """ ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,;:?!-_~#"'&()[]|`/\@°+=*%€$£¢<>©®""")

setKeyMap("Left:Left,A;Right:Right,D;Up:Up,W;Down:Down,S;A:Z,1;B:X,2;X:C,3;Y:V,4;L1:B,5;L2:H;R1:M;R2:<;Start:Space,Return;Back:Escape")
nico.createWindow("ld43", 1920 div 3, 1080 div 3, 2)

fps(60)
fixedSize(true)
integerScale(true)

nico.run(gameInit, gameUpdate, gameDraw)
