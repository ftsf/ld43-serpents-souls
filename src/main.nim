import nico
import nico/vec
import utils
import sequtils
import cards
import gui

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
 - Occupy by force, or by manipulation

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

Destiny Deck
  Random Event -> Demand -> Reward / Punishment

  How does it affect multiple cities?
  Only hometown? All cities?

  eg.
  Lots of sacrifice one follower -> no gain / light penalty

  Sacrifice one follower -> nada / a follower becomes sick
  Sacrifice one follower -> nada / all newborns will be sick
  Sacrifice one follower -> nada / one home is disabled
  Sacrifice one follower -> nada / only one relocate
  Sacrifice one follower -> nada / one less action
  Sacrifice one follower -> nada / a follower becomes sick
  Sacrifice one follower -> nada / a follower becomes sick
  Sacrifice one follower -> nada / spawn a rebel

  A few medium difficulty with slight gains, heavy penalty

  Sacrifice two followers -> 1 extra action next turn / a home is destroyed
  Sacrifice three followers -> five new followers
  5 Sick people arrive -> Heal 5 Sick people -> 2 new followers / 5 followers become sick
  Temple flooded -> Sacrifice 3 people -> nada / Temple remains flooded

  A few hard difficulty with big gains, slight penalty

"""

# CONSTANTS

const teamColors = [7,18,28]
const teamColors2 = [4,15,3]

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
    Sick

  Unit = ref object of RootObj
    kind: UnitKind
    site: Site
    sourceSite: Site
    team: int
    pos: Vec2f
    flash: int
    hp: int
    usedAbility: bool
    souls: int
    abilities: seq[ShamanAbility]

  SiteAbility = object
    name: string
    ignore: bool
    desc: string
    nFollowers: int
    nShamans: int
    nSoldiers: int
    nSick: int
    nRebels: int
    nActions: int
    multiUse: bool
    startOfTurn: bool
    action: proc(site: Site)

  ShamanAbility = object
    name: string
    desc: string
    nActions: int
    nFollowers: int
    nSick: int
    nShamans: int
    nSoldiers: int
    nRebels: int
    nSouls: int
    multiUse: bool
    startOfTurn: bool
    action: proc(unit: Unit, site: Site)

  SiteSettings = ref object
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
    isHometown: bool
    serpentSouls: int
    serpentSacrificesMade: int

  Army = ref object of RootObj
    pos: Vec2i
    units: seq[Unit]
    team: int
    source: Town
    dest: Town
    moved: bool

  DestinyCardSettings = ref object of CardSettings
    event: string
    requirement: string
    gain: string
    penalty: string
    onStartTurn: proc(c: Card)
    onEndTurn: proc(c: Card)

  TurnPhase = enum
    phaseStartOfTurn
    phaseTurn
    phaseCombat
    phaseEndOfTurn

type InputKind = enum
  SelectSite
  SelectSiteToBuild
  Relocate
  PlaceUnit
  MoveArmy
  SelectUnit

# PREPROCS
proc gameInit()
proc dialogYesNo(text: string, onYes: proc() = nil, onNo: proc() = nil)
proc expand(self: Town)
proc newSite(town: Town, siteSettings: SiteSettings, x, y: int): Site {.discardable.}
proc newParticle*(pos: Vec2f, vel: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int)
proc newParticleText*(pos: Vec2f, vel: Vec2f, ttl: float32, text: string, color1,color2: int)
proc newUnit(kind: UnitKind, site: Site): Unit

proc removeFollower(self: Site) =
  for i,u in units:
    if u.kind == Follower:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      return

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

proc getSickCount(self: Site): int =
  var count = 0
  for i,u in units:
    if u.kind == Sick:
      count += 1
  return count

proc getFollowerCount(self: Town): int =
  var count = 0
  for s in sites:
    for i,u in s.units:
      if u.kind == Follower:
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

proc getSickCount(self: Town): int =
  var count = 0
  for s in sites:
    for i,u in s.units:
      if u.kind == Sick:
        count += 1
  return count

# GLOBALS
var turnPhase: TurnPhase
var particles: seq[Particle]
var time: float32
var turn: int
var frame: uint32
var selectedSite: Site
var homeTown: Town
var currentTown: Town
var currentArmy: Army
var placingUnits: seq[Unit]
var placingUnitSource: Site
var inputMode: InputKind
var selectedUnit: Unit
var hoverUnit: Unit
var buildPreview: SiteSettings
var forcedLabour = false
var towns: seq[Town]
var armies: seq[Army]
var pulling: bool
var hoverChangeTime: float32
var hoverSite: Site
var destinyPile: Pile
var destinyDiscardPile: Pile
var currentDestiny: Card

var mainMenu: bool

var areYouSure: bool
var areYouSureMessage: string
var areYouSureYes: proc()
var areYouSureNo: proc()

var onSelectUnit: proc(unit: Unit) = nil

var undoStack: seq[Town]

# CONSTANTS 2

let shamanAbilities = @[
  ShamanAbility(name: "Sacrifice Follower", desc: "Sacrifice Follower\nto gain a soul", nActions: 0, nFollowers: 1, nSouls: 1, action: proc(unit: Unit, site: Site) =
    site.removeFollower()
    site.town.rebellion += 1
    unit.souls += 1
  ),
  ShamanAbility(name: "Convert", desc: "Gain a follower on Site", nActions: 1, nSouls: 2, action: proc(unit: Unit, site: Site) =
    site.units.add(newUnit(Follower, site))
  ),
  ShamanAbility(name: "Cleansing", desc: "Kill all Followers and Sick\non Site. Rebellion x2", nActions: 2, nSouls: 3, action: proc(unit: Unit, site: Site) =
    for u in site.units:
      if u.kind == Follower or u.kind == Rebel or u.kind == Sick:
        unit.souls += 1
        unit.site.town.rebellion += 2
        u.hp = 0
  ),
  ShamanAbility(name: "Refresh Site", desc: "Allow a site to be used again", nActions: 1, nSouls: 3, action: proc(unit: Unit, site: Site) =
    site.used = false
  ),
  ShamanAbility(name: "Round up", desc: "Relocate up to 3 Rebels from Site", nActions: 1, nRebels: 1, nSouls: 3, action: proc(unit: Unit, site: Site) =
    var count = 0
    placingUnits = @[]
    for i,u in site.units:
      if u.kind == Rebel:
        placingUnits.add(u)
        inputMode = PlaceUnit
        site.units.delete(i)
        count += 1
        if count >= 3:
          break
  ),
  ShamanAbility(name: "Fireball", desc: "Kills half of the Soldiers\non Site (rounded up)", nSoldiers: 1, nActions: 2, nSouls: 4, action: proc(unit: Unit, site: Site) =
    var nSoldiers = 0
    for u in site.units:
      if u.kind == Soldier:
        nSoldiers += 1
    var toKill = (nSoldiers + 2 - 1) div 2
    for i in 0..<toKill:
      site.removeSoldier()
  ),
]

let siteEmpty = SiteSettings(name: "", spr: -1, abilities: @[
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


let abilityDemolish = SiteAbility(name: "Demolish", nFollowers: 3, nActions: 1, ignore: true, action: proc(site: Site) =
  dialogYesNo("Are you sure you want to demolish this <21>" & site.settings.name & "</>?", proc() =
    site.settings = siteEmpty
  , proc() =
    currentTown.actions += 1
    site.used = false
  )
)

let siteSquare = SiteSettings(name: "Village Center", spr: 8, abilities: @[
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()
  )
])

let siteMedic = SiteSettings(name: "Healer's Tent", actionsToBuild: 1, spr: 11, abilities: @[
  SiteAbility(name: "Heal Sick", desc: "Convert a Sick into a Follower\nReduce rebellion.", nFollowers: 3, nSick: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Sick:
        u.kind = Follower
        u.flash = 5
        site.town.rebellion = max(site.town.rebellion - 1, 0)
        break
  ),
  SiteAbility(name: "Heal Sick", desc: "Convert a Sick into a Follower\nReduce rebellion.", nShamans: 1, nSick: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Sick:
        u.kind = Follower
        u.flash = 5
        site.town.rebellion = max(site.town.rebellion - 1, 0)
        break
  ),
  abilityDemolish,
])

let siteSerpent = SiteSettings(name: "Serpent Totem", spr: 0, abilities: @[
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a follower and let their\nsoul flow into the Serpent", nFollowers: 2, nActions: 0, multiUse: true, action: proc(site: Site) =
    # kill 1 follower, capture one soul
    site.removeFollower()
    homeTown.serpentSouls += 1
    site.town.rebellion += 1
    homeTown.serpentSacrificesMade += 1
  ),
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a Shaman, all their souls\nwill flow into the Serpent", nFollowers: 1, nShamans: 1, multiUse: true, nActions: 0, action: proc(site: Site) =
    # kill 1 shaman, capture their souls
    # TODO: select shaman
    for u in site.units:
      if u.kind == Shaman:
        homeTown.serpentSouls += 1
        homeTown.serpentSouls += u.souls
        site.town.rebellion += 1
        homeTown.serpentSacrificesMade += 1
        u.hp = 0
  ),
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()

  )
])

let siteChurch = SiteSettings(name: "Temple", desc: "Control the people", spr: 2, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Recruit", desc: "Gain 1 follower on any site", nFollowers: 3, nActions: 0, action: proc(site: Site) =
    # gain 1 follower
    inputMode = PlaceUnit
    placingUnits = @[newUnit(Follower, site)]
  ),
  SiteAbility(name: "Re-educate", desc: "Convert Rebels into Followers", nFollowers: 5, nRebels: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Rebel:
        u.kind = Follower
        u.flash = 5
  ),
  SiteAbility(name: "Pacify", desc: "Reduce rebellion for each\nfollower in the Temple", nFollowers: 5, nActions: 2, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        site.town.rebellion -= 1
    if site.town.rebellion < 0:
      site.town.rebellion = 0
  ),
  abilityDemolish,
])

let siteBarracks = SiteSettings(name: "Barracks", desc: "Train soldiers", spr: 3, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train", desc: "Convert a Follower\ninto a Soldier", nFollowers: 1, startOfTurn: true, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.kind = Soldier
        u.flash = 5
        break
  ),
  SiteAbility(name: "Train", desc: "Convert a Follower\ninto a Soldier", nFollowers: 1, nSoldiers: 3, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.kind = Soldier
        u.flash = 5
        break
  ),
  abilityDemolish,
])

let siteAltar = SiteSettings(name: "Altar", desc: "Kill Followers for Actions", spr: 4, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Motivate", desc: "Sacrifice a follower at\nAltar for an extra action", nFollowers: 2, nActions: 0, action: proc(site: Site) =
    # kill 1 follower, gain 1 action
    site.removeFollower()
    site.town.actions += 1
    site.town.rebellion += 1
  ),
  abilityDemolish,
])

let siteGuild = SiteSettings(name: "Shaman Hut", desc: "Train powerful Shaman", spr: 5, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train Shaman", desc: "Convert a Follower into a Shaman", nFollowers: 1, nShamans: 1, nActions: 2, action: proc(site: Site) =
    # turn a follower into a Shaman
    for u in site.units:
      if u.kind == Follower:
        u.kind = Shaman
        u.flash = 5
        break
  ),
  SiteAbility(name: "Train Shaman", desc: "Convert 5 Followers into a Shaman", nFollowers: 5, nShamans: 0, nActions: 2, action: proc(site: Site) =
    for i in 0..<4:
      site.removeFollower()
    for u in site.units:
      if u.kind == Follower:
        u.kind = Shaman
        u.flash = 5
        break
  ),
  abilityDemolish,
])

let siteSeer = SiteSettings(name: "Seer Hut", desc: "Explore Destiny", spr: 9, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Peek", desc: "Look at the Next 2 Destiny", nShamans: 1, nActions: 1, action: proc(site: Site) =
  ),
  SiteAbility(name: "Delve", desc: "Rearrange the Next 5 Destiny", nShamans: 1, nActions: 3, action: proc(site: Site) =
  ),
  SiteAbility(name: "Avert", desc: "Bury the Next Destiny", nShamans: 1, nActions: 2, action: proc(site: Site) =
  ),
  abilityDemolish,
])

let siteHouse = SiteSettings(name: "Home", desc: "A place of reproduction", spr: 1, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Reproduce", nFollowers: 2, nActions: 0, startOfTurn: true, action: proc(site: Site) =
    site.units.insert(newUnit(Follower, site), 0)
  ),
  abilityDemolish,
])

let siteObstacle = SiteSettings(name: "Hovel", desc: "A filty obstacle", spr: 7, actionsToBuild: 0, abilities: @[
  SiteAbility(name: "Sow Rebellion", desc: "creates rebels", startOfTurn: true, action: proc(site: Site) =
    if site.town.team != 0:
      site.town.rebellion += 1
  ),
  SiteAbility(name: "Demolish", desc: "clear space, increase rebellion by 3", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        site.town.rebellion += 3
        break
  ),
])

let siteRebelBase = SiteSettings(name: "Rebel Base", spr: 10, actionsToBuild: 0, abilities: @[
  SiteAbility(name: "Spawn Rebel", startOfTurn: true, action: proc(site: Site) =
    site.units.add(newUnit(Rebel, site))
  ),
  SiteAbility(name: "Demolish", desc: "clear space, increase rebellion by 3", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        site.town.rebellion += 3
        break
  ),
])

let siteWatchtower = SiteSettings(name: "Watchtower", desc: "Reduce Rebellion", spr: 6, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Supress Rebellion", desc: "Remove one Rebellion", nSoldiers: 3, nActions: 0, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - 1, 0)
  ),
  SiteAbility(name: "Supress Rebellion", desc: "Remove one Rebellion\nper Soldier", nSoldiers: 1, nActions: 1, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - site.getSoldierCount(), 0)
  ),
  SiteAbility(name: "Snipe Rebel", desc: "Remove one Rebel", nSoldiers: 1, nActions: 1, action: proc(site: Site) =
    inputMode = SelectUnit
    onSelectUnit = proc(unit: Unit) =
      if unit.kind == Rebel:
        unit.hp = 0
        inputMode = SelectSite
        onSelectUnit = nil

  ),
  abilityDemolish,
])

let destinySacrifice1Sick = DestinyCardSettings(
  name: "Sacrifice",
  requirement: "Sacrifice one follower",
  gain: "",
  penalty: "One follower becomes sick",
  onEndTurn: proc(c: Card) =
    if homeTown.serpentSacrificesMade < 1:
      echo "making one follower sick"
    else:
      echo "sacrifice was made"
  )


let destinySettings = @[
  destinySacrifice1Sick,
]

let buildMenu: seq[SiteSettings] = @[
  siteHouse,
  siteAltar,
  siteGuild,
  siteChurch,
  siteBarracks,
  siteWatchtower,
  siteMedic,
  siteSeer,
]

# PROCS

proc newUnit(kind: UnitKind, site: Site): Unit =
  result = new(Unit)
  result.souls = 1
  if kind == Shaman:
    result.abilities = @[shamanAbilities[0]]
  result.site = site
  result.kind = kind
  result.flash = 5
  result.hp = 1
  result.usedAbility = false

proc dialogYesNo(text: string, onYes: proc() = nil, onNo: proc() = nil) =
  areYouSure = true
  areYouSureMessage = text
  areYouSureYes = onYes
  areYouSureNo = onNo

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
    if kind == Shaman and usedAbility == false:
      pal(1,8)
    else:
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
  elif kind == Sick:
    spr(6, x, y)

  pal()

  if kind == Shaman:
    for i in 0..<souls:
      let angle = (TAU / (souls).float32) * i.float32 + time
      if usedAbility:
        setColor(21)
      else:
        setColor(8)
      circfill(x + 4 + cos(angle) * 5, y + 4 + sin(angle) * 5, 1)

proc check(self: SiteAbility, site: Site): bool =
  if placingUnits.len > 0:
    return false
  if startOfTurn and turnPhase != phaseStartOfTurn:
    return false
  if multiUse == false and site.used:
    return false
  if nActions > site.town.actions:
    return false
  if nFollowers > site.getFollowerCount:
    return false
  if nShamans > site.getShamanCount:
    return false
  if nSoldiers > site.getSoldierCount:
    return false
  if nSick > site.getSickCount:
    return false
  if nRebels > site.getRebelCount:
    return false
  return true

proc draw(self: Site, x,y: int) =

  var available = false
  for a in settings.abilities:
    if a.startOfTurn == false and a.ignore == false and a.check(self):
      available = true

  setColor(1)
  rrectfill(x, y, x + 48, y + 48)

  if settings.spr > -1:
    setSpritesheet(1)
    spr(settings.spr, x + 8, y + 1)

  setColor(if self.used or available == false: 24 else: 8)
  if self == selectedSite:
    rrect(x-1, y-1, x + 49, y + 49)
    rect(x, y, x + 48, y + 48)
    rect(x+1, y+1, x + 48 - 1, y + 48 - 1)
    pset(x+2, y+2)
    pset(x+48-2, y+2)
    pset(x+48-2, y+48-2)
    pset(x+2, y+48-2)
  else:
    rrect(x, y, x + 48, y + 48)

  setColor(7)

  var yi = y + 4

  #if settings.spr == 0 or true:
  #  for line in settings.name.split(" "):
  #    printc(line, x + 25, yi)
  #    yi += 10

  setSpritesheet(0)

  var xi = x + 6
  yi = y + 29
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



proc check(self: ShamanAbility, unit: Unit): bool =
  if unit.usedAbility and multiUse == false:
    return false
  if nActions > unit.site.town.actions:
    return false
  if nSouls > unit.souls:
    return false
  if nFollowers > unit.site.getFollowerCount:
    return false
  if nRebels > unit.site.getRebelCount:
    return false
  if nSick > unit.site.getSickCount:
    return false
  return true

proc draw(self: SiteAbility, sx, sy, w, h: int, enabled: bool, site: Site) =
  setSpritesheet(0)
  var x = sx
  var y = sy
  if startOfTurn:
    setColor(25)
    richPrint("Start of turn: " & name, x, y)
  elif not enabled:
    setColor(25)
    richPrint("<27>(" & $nActions & ")</> " & name, x, y)
  else:
    setColor(22)
    richPrint("<8>(" & $nActions & ")</> " & name, x, y)
  y += 10
  x = sx
  var j = 0
  let followerCount = site.getFollowerCount
  let shamanCount = site.getShamanCount
  let rebelCount = site.getRebelCount
  let soldierCount = site.getSoldierCount
  let sickCount = site.getSickCount

  for i in 0..<nFollowers:
    if i >= followerCount:
      pal(1,27)
    spr(1, x, y)
    pal()
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nShamans:
    if i >= shamanCount:
      pal(1,27)
    spr(2, x, y)
    pal()
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nRebels:
    if i >= rebelCount:
      pal(1,27)
    spr(3, x, y)
    pal()
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nSoldiers:
    if i >= soldierCount:
      pal(1,27)
    spr(4, x, y)
    pal()
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  for i in 0..<nSick:
    if i >= sickCount:
      pal(1,27)
    spr(6, x, y)
    pal()
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0

  if multiUse:
    setColor(8)
    print("multi-use", x + 5, y)

  y += 10
  x = sx
  setColor(23)
  for line in desc.split("\n"):
    print(line, x, y)
    y += 10

proc draw(self: ShamanAbility, sx, sy, w, h: int, enabled: bool, unit: Unit) =
  var y = sy
  var x = sx
  if startOfTurn:
    setColor(25)
    richPrint("(start turn)</> " & name, 10, y)
  elif not enabled:
    setColor(25)
    richPrint("<27>(" & $nActions & ")</> " & name & (if multiUse: " <27>multi-use" else: ""), x, y)
  else:
    setColor(22)
    richPrint("<8>(" & $nActions & ")</> " & name & (if multiUse: " <8>multi-use" else: ""), x, y)
  y += 10

  x = sx

  var j = 0
  for i in 0..<nSouls:
    spr(7, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
  x += 3
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
  for i in 0..<nSick:
    spr(6, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0

  y += 10

  x = sx
  setColor(23)
  richPrint(desc, x, y)

proc draw(self: Town) =
  let cx = screenWidth div 2 - width * 25
  let cy = screenHeight div 2 - height * 25
  for y in 0..<height:
    for x in 0..<width:
      let site = sites[width * y + x]
      if site != nil:
        site.draw(cx + x * 52, cy + y * 52)

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


proc startTurn() =
  turnPhase = phaseStartOfTurn

  undoStack = @[]
  turn += 1

  # draw one destiny card
  currentDestiny = destinyPile.drawCard()

  # start of turn actions
  for town in towns:
    for site in town.sites:
      site.used = false
      for u in site.units:
        u.site = site
        u.sourceSite = site
      for ab in site.settings.abilities:
        if ab.startOfTurn:
          if ab.check(site):
            ab.action(site)

proc endTurn() =
  turnPhase = phaseEndOfTurn

  undoStack = @[]

  if homeTown.serpentSouls >= 100:
    dialogYesNo("THE SERPENT GOD HAS BEEN SUMMONED!") do:
      gameInit()
    return

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
    for town in towns:
      for site in town.sites:
        if site.settings != siteRebelBase:
          var nRebels = 0;
          for u in site.units:
            if u.kind == Rebel:
              nRebels += 1
          if nRebels >= 5:
            if site.settings != siteEmpty:
              site.settings = siteEmpty
            else:
              site.settings = siteRebelBase

    town.rebellion = clamp(town.rebellion + town.getRebelCount(), 0, town.sites.len * 5)

    # for every 5 rebellion, make a new rebel
    let newRebels = clamp(town.rebellion div 5, 0, 3 + town.size)
    for i in 0..<newRebels:
      # pick a random site and spawn a rebel
      let r = rnd(town.sites.high)
      for k,site in town.sites:
        if k == r:
          site.units.add(newUnit(Rebel, site))
          town.rebellion -= 2

    town.rebellion = clamp(town.rebellion, 0, town.sites.len * 5)

    #spread sickness
    var nSick = town.getSickCount()
    for i in 0..<nSick:
      # convert a follower or soldier to sick
      let site = rnd(town.sites)
      if site.units.len > 0:
        let unit = rnd(site.units)
        if unit.kind == Sick:
          unit.hp = 0
        elif unit.kind == Follower or unit.kind == Rebel:
          unit.kind = Sick
          unit.flash = 5

    # cap site
    for site in town.sites:
      if site.units.len > 15:
        site.units.setLen(15)

  startTurn()

  turnPhase = phaseTurn


proc tryEndTurn() =
  if homeTown.serpentSacrificesMade == 0:
    dialogYesNo("Are you sure?\n<27>The Serpent God has not received her offering") do:
      endTurn()
  else:
    endTurn()

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
  site.used = false
  site.units = @[]
  town.sites[town.width * y + x] = site
  return site

proc gameInit() =
  loadSpritesheet(0, "spritesheet.png", 8, 8)
  loadSpritesheet(1, "tileset.png", 32, 32)
  loadSpritesheet(2, "tilesetWorld.png", 8, 8)

  turnPhase = phaseTurn

  loadMap(0, "map.json")
  setMap(0)

  particles = @[]
  towns = @[]
  armies = @[]
  destinyPile = newPile("Destiny")
  destinyDiscardPile = newPile("Destiny Discard")

  for i in 0..<10:
    destinyPile.addCard(newCard(destinySacrifice1Sick))

  turn = 1
  time = 0.0
  frame = 0

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
            townSerpent.units.add(newUnit(Follower, townSerpent))
          for i in 0..<1:
            townSerpent.units.add(newUnit(Shaman, townSerpent))
          selectedSite = townserpent
          var townHouse = newSite(town, siteHouse, 0, 1)
          for i in 0..<2:
            townHouse.units.add(newUnit(Follower, townHouse))
          currentTown = town
          currentTown.isHometown = true
          homeTown = currentTown
          currentTown.actions = 3

        for i,site in town.sites.mpairs:
          if site == nil:
            if town == currentTown:
              site = newSite(town, siteEmpty, i mod town.width, i div town.width)
            else:
              site = newSite(town, siteObstacle, i mod town.width, i div town.width)

        towns.add(town)

proc saveUndo() =
  when not defined(js):
    var undoTown: Town
    deepCopy(undoTown, currentTown)
    undoStack.add(undoTown)

proc undo() =
  if currentTown != nil and undoStack.len > 0:
    var oldCurrentTown = currentTown
    currentTown = undoStack[undoStack.high]
    currentArmy = nil
    placingUnits = @[]
    selectedSite = nil
    selectedUnit = nil
    hoverUnit = nil
    hoverSite = nil
    undoStack.delete(undoStack.high)
    inputMode = SelectSite
    if currentTown.isHometown:
      homeTown = currentTown
    towns[towns.find(oldCurrentTown)] = currentTown

proc gameGui() =
  G.normalColor = 15
  G.buttonBackgroundColor = 31
  G.buttonBackgroundColorDisabled = 1
  G.hoverColor = 22
  G.activeColor = 21
  G.textColor = 22
  G.downColor = 1
  G.disabledColor = 25
  G.backgroundColor = 1
  G.hSpacing = 3
  G.vSpacing = 3
  G.hPadding = 4
  G.vPadding = 4

  if mainMenu:
    G.areaBegin(screenWidth div 2 - 100, screenHeight div 2 - 70, 200, 175, gTopToBottom, true, true)
    G.hExpand = true
    G.center = true
    G.label("<21>Serpent's Souls</>")
    G.label("A game by <8>Impbox</> for <27>LD43</>")
    if G.button("Continue"):
      mainMenu = false
    G.empty(5,5)
    if G.button("Save"):
      mainMenu = false
    if G.button("Load"):
      mainMenu = false
    G.empty(5,5)
    if G.button("Restart"):
      mainMenu = false
      gameInit()
    if G.button("Quit"):
      shutdown()
    G.center = false
    G.hExpand = false
    G.areaEnd()

  if areYouSure:
    G.areaBegin(screenWidth div 2 - 200, screenHeight div 2 - 30, 400, 70, gTopToBottom, true, true)
    G.label(areYouSureMessage)
    if G.button("Yes"):
      if areYouSureYes != nil:
        areYouSureYes()
      areYouSure = false
    if G.button("No"):
      if areYouSureNo != nil:
        areYouSureNo()
      areYouSure = false
    G.areaEnd()

  # town info
  G.areaBegin(screenWidth div 4 + 4, 10, screenWidth div 2 - 8, 50, gTopToBottom, true)
  G.center = false
  if currentTown != nil:
    G.label(currentTown.name)
    G.label("Actions: <8>(" & $currentTown.actions & ")</>")
    G.label("Rebellion: <27>" & $currentTown.rebellion & "</>")
  G.areaEnd()

  # right bar
  G.areaBegin(screenWidth - 160, 3, 160 - 3, screenHeight - 36, gTopToBottom, true)
  G.center = true
  G.hExpand = true

  var hoveringOverAbility = false

  if inputMode == SelectSiteToBuild:
    G.label("Select new Site to Build")
    for building in buildMenu:
      if G.button("<8>(" & $building.actionsToBuild & ")</> " & building.name & "\n" & building.desc, currentTown.actions >= building.actionsToBuild):
        currentTown.actions -= building.actionsToBuild
        selectedSite.settings = building
        selectedSite.used = false
        inputMode = SelectSite
        if forcedLabour:
          selectedSite.removeFollower()
          currentTown.rebellion += 1
          break
    G.empty(10,10)
    if G.button("Cancel building"):
      inputMode = SelectSite
      selectedSite.used = false

  elif selectedUnit != nil:
    G.label("Shaman")
    if selectedUnit.usedAbility:
      G.label("Already used this turn")

    G.center = false
    var i = 0
    for a in selectedUnit.abilities:
      let ret = G.button(148, 50, a.check(selectedUnit)) do(x,y,w,h: int, enabled: bool):
        a.draw(x,y,w,h,enabled,selectedUnit)
      if ret:
        a.action(selectedUnit, selectedSite)
        if not a.multiUse:
          selectedUnit.usedAbility = true
      if G.hoverElement == G.element:
        hoveringOverAbility = true
      i += 1
    if i < 4:
      if G.button("Learn new ability", 148, 50):
        discard

    G.hExpand = false

  elif selectedSite != nil:
    if selectedSite.settings.name == "":
      G.label("Empty Site")
    else:
      if selectedSite.used:
        setColor(22)
      else:
        setColor(8)
      G.label(selectedSite.settings.name)

      setColor(22)

    if selectedSite.used:
      G.label("Already used this turn")

    setSpritesheet(1)
    if selectedSite.settings.spr != -1:
      G.sprite(selectedSite.settings.spr)

    G.center = false
    for k,a in selectedSite.settings.abilities:
      let ret = G.button(148, 50, a.check(selectedSite)) do(x,y,w,h: int, enabled: bool):
        a.draw(x,y,w,h,enabled,selectedSite)
      if ret:
        inputMode = SelectSite
        a.action(selectedSite)
        if not a.multiUse:
          selectedSite.used = true
        currentTown.actions -= a.nActions
      if G.hoverElement == G.element:
        hoveringOverAbility = true


  G.hExpand = false
  G.areaEnd()

  # bottom bar
  G.areaBegin(0, screenHeight - 30, screenWidth, 28, gRightoLeft)
  G.center = true

  if inputMode == SelectSite:
    if G.button("End Turn", 64, 28):
      tryEndTurn()
  else:
    G.empty(64, 28)

  if inputMode == Relocate:
    var unitsMoved = 0
    for site in currentTown.sites:
      for u in site.units:
        if u.site != u.sourceSite:
          unitsMoved += 1
    if G.button(if hoveringOverAbility and frame mod 60 < 30: "<27>This will end your relocation</>" elif unitsMoved == 0: "Cancel relocate" else: "Complete relocate", 148, 28, placingUnits.len == 0):
      inputMode = SelectSite
      if unitsMoved == 0:
        currentTown.actions += 1
  else:
    if G.button((if currentTown.actions >= 1: "<8>" else: "<27>") & "(1)</> Relocate\n<24>Move any number of units", 128, 28, currentTown.actions >= 1):
      saveUndo()
      inputMode = Relocate
      placingUnits = @[]
      currentTown.actions -= 1
      for site in currentTown.sites:
        for u in site.units:
          u.site = site
          u.sourceSite = site
  G.areaEnd()

proc gameUpdate(dt: float32) =
  G.update(gameGui, dt)

  if(btnp(pcBack)):
    mainMenu = not mainMenu

  if G.activeElement != 0 or G.hoverElement != 0 or G.modalArea != 0:
    return

  if mousebtnp(2):
    undo()
    return

  time += dt
  var lastHoverUnit = hoverUnit
  var lastHoverSite = hoverSite
  hoverUnit = nil
  hoverSite = nil
  var (mx,my) = mouse()

  if currentTown != nil:
    for site in currentTown.sites:
      for u in site.units:
        if u.hp <= 0:
          newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)

  for town in towns:
    for site in town.sites:
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

  if hoverUnit != lastHoverUnit or hoverSite != lastHoverSite:
    hoverChangeTime = time

  if inputMode == SelectUnit:
    if mousebtnp(0):
      if hoverUnit != nil:
        onSelectUnit(hoverUnit)
        return

  if inputMode == Relocate or inputMode == PlaceUnit:
    if mousebtnp(0):
      if hoverUnit != nil or placingUnits.len == 0 and inputMode == Relocate:
        pulling = true
      else:
        pulling = false

    if mousebtnpr(0,15):
      if pulling:
        # grab unit
        if hoverUnit != nil and hoverSite != nil:
          if hoverUnit.kind == Rebel or hoverUnit.kind == Neutral:
            return
          placingUnits.add(hoverUnit)
          placingUnitSource = hoverSite
          selectedSite = hoverSite
          hoverUnit.site = nil
          let i = placingUnitSource.units.find(hoverUnit)
          if i != -1:
            placingUnitSource.units.delete(i)
          return
      else:
        if hoverSite != nil:
          # place unit
          if placingUnits.len > 0:
            var u = placingUnits[placingUnits.high]
            placingUnits.delete(placingUnits.high)
            hoverSite.units.add(u)
            u.site = hoverSite
            selectedSite = hoverSite
            if placingUnits.len == 0 and inputMode == PlaceUnit:
              inputMode = SelectSite

  if btnpr(pcStart, 30):
    tryEndTurn()
    return

  if mousebtnp(0):
    var (mx,my) = mouse()
    # check which thing they clicked on
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
              undoStack = @[]
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
          # pick up army
          if abs(tx - currentTown.pos.x) <= 1 and abs(ty - currentTown.pos.y) <= 1 and (tx == currentTown.pos.x and ty == currentTown.pos.y) == false:
            var army: Army = nil
            for i, army in armies:
              if army.pos.x == tx and army.pos.y == ty:
                if army.team == 1:
                  placingUnits = army.units
                  armies.delete(i)
                  return
        else:
          # place army
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
            else:
              army.units.add(placingUnits)
              army.moved = true
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
      elif inputMode == SelectSite:
        if selectedUnit != nil:
          # shaman ability select
          let ay = (my - 25) div 50
          echo "ShamanAbility: ", ay
          if ay < shamanAbilities.len:
            let ability = shamanAbilities[ay]
            echo "ability: ", ability.name
            # check if we meet the requirements
            if ability.check(selectedUnit):
              saveUndo()
              ability.action(selectedUnit, selectedUnit.site)
              selectedUnit.site.town.actions -= ability.nActions
              if ability.multiUse == false:
                selectedUnit.usedAbility = true
            return
        else:
          # ability select
          let ay = (my - 25) div 50
          if ay < selectedSite.settings.abilities.len:
            let ability = selectedSite.settings.abilities[ay]
            if ability.startOfTurn:
              return
            if ability.check(selectedSite):
              saveUndo()
              currentTown.actions -= ability.nActions
              if not ability.multiUse:
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

  setCamera()
  G.draw(gameGui)

  # cursor
  block drawCursor:
    let (mx,my) = mouse()
    if hoverChangeTime < time - 0.3:
      setColor(21)
      setOutlineColor(1)
      if hoverUnit == nil and hoverSite != nil:
        printOutlineC($hoverSite.settings.name, mx, my - 15)
      elif hoverUnit != nil:
        printOutlineC($hoverUnit.kind, mx, my - 15)
    setSpritesheet(0)
    if inputMode == SelectUnit:
      spr(33, mx - 4, my - 4)
    elif inputMode == Relocate or inputMode == PlaceUnit:
      spr(32, mx, my)
    else:
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

srand()

nico.run(gameInit, gameUpdate, gameDraw)
