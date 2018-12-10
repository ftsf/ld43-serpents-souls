import nico
import nico/vec
import utils
import sequtils
import cards
import gui
import times

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

Site Attachments:
  Each site can have zero to 2 attachments
  These can be positive or negative effects

  eg.
  * Disabled for one turn
  * Plagued: one unit becomes sick each turn until the site it demolished


Destiny Deck
  Random Event -> Demand -> Reward / Punishment

  How does it affect multiple cities?
  Only hometown? All cities?

  eg.
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
const ageColors = [15,17,18]
const ageCardCount = [5,5,5]
const flashMod = 20
const flashCmp = 5

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
    age: int
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
    screenPos: Vec2i
    used: bool
    units: seq[Unit]
    disabled: int
    blocked: int

  Town = ref object of RootObj
    pos: Vec2i
    name: string
    size: int
    width: int
    height: int
    actions: int
    startingActions: int
    sites: seq[Site]
    rebellion: int
    team: int
    isHometown: bool
    serpentSouls: int
    serpentSacrificesMade: int
    nRebelsKilled: int
    nHealed: int

  Army = ref object of RootObj
    pos: Vec2i
    units: seq[Unit]
    team: int
    source: Town
    dest: Town
    moved: bool

  DestinyCardSettings = ref object of CardSettings
    age: int
    omen: bool
    count: int
    event: string
    demand: string
    gain: string
    penalty: string
    sicknessSpreads: bool
    rebelsMove: bool
    rebellionIncreases: bool
    checkDemand: proc(c: Card, town: Town): bool
    onStartTurn: proc(c: Card, town: Town)
    onEndTurn: proc(c: Card, town: Town)
    onStartNextTurn: proc(c: Card, town: Town)

  TurnPhase = enum
    phaseStartOfTurn = "Start of Turn"
    phaseTurn = "Turn"
    phaseCombat = "Combat Phase"
    phaseEndOfTurn = "End of Turn"

type InputKind = enum
  SelectSite
  SelectSiteToBuild
  Relocate
  PlaceUnit
  MoveArmy
  SelectUnit
  ViewDestiny
  RearrangeDestiny

# PREPROCS
proc move*(self: Unit, to: Site) =
  if site != nil:
    site.units.delete(site.units.find(self))
  to.units.add(self)
  site = to

proc setKind*(self: Unit, newKind: UnitKind) =
  if self.kind != newKind:
    var oldKind = self.kind
    self.kind = newKind
    self.flash = 5
    if oldKind == Sick and newKind == Follower:
      site.town.nHealed += 1
    if oldKind == Sick and newKind == Follower:
      site.town.nHealed += 1

proc randomSite(town: Town, match: proc(x: Site): bool = nil): Site =
  var count = 0
  for site in town.sites:
    if match == nil or match(site):
      count += 1
  if count == 0:
    return nil
  let r = rnd(count - 1)
  count = 0
  for site in town.sites:
    if match == nil or match(site):
      if r == count:
        return site
      count += 1

proc randomUnit(town: Town, match: proc(x: Unit): bool): Unit =
  var count = 0
  for site in town.sites:
    for unit in site.units:
      if match(unit):
        count += 1
  if count == 0:
    return nil
  let r = rnd(count - 1)
  count = 0
  for site in town.sites:
    for unit in site.units:
      if match(unit):
        if r == count:
          return unit
        count += 1

proc gameInit()
proc dialogYesNo(text: string, onYes: proc() = nil, onNo: proc() = nil)
#proc dialog(text: string, confirmText: string, onConfirm: proc() = nil)
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
var focusFollowsMouse: bool
var actionFlash: int
var rebellionFlash: int
var turnPhase: TurnPhase
var phaseTimer: float32

var particles: seq[Particle]
var time: float32
var turn: int
var frame: uint32
var selectedSite: Site
var homeTown: Town
var homeTotem: Site
var currentTown: Town
var currentArmy: Army
var placingUnits: seq[Unit]
var placingUnitSource: Site
var inputMode: InputKind
var selectedUnit: Unit
var hoverUnit: Unit
var lastClickPos: Vec2i
var lastClickTime: float32
var buildPreview: SiteSettings
var forcedLabour = false
var towns: seq[Town]
var armies: seq[Army]
var pulling: bool
var hoverChangeTime: float32
var hoverSite: Site
var hoveringOverEndTurn: bool
var hoveringOverAbility: bool
var destinyPile: Pile
var destinyDiscardPile: Pile
var cardHand: Pile
var currentDestiny: Card
var showCircleMenu: bool
var age = 1

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
    rebellionFlash = 5
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
        rebellionFlash = 5
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
    site.used = false
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

let siteHealer = SiteSettings(name: "Healer's Tent", actionsToBuild: 1, spr: 11, abilities: @[
  SiteAbility(name: "Heal Sick", desc: "Convert a Sick into a Follower\nReduce Rebellion", nFollowers: 5, startOfTurn: true, nSick: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Sick:
        u.setKind(Follower)
        site.town.rebellion = max(0, site.town.rebellion - 1)
        break
  ),
  SiteAbility(name: "Heal Sick", desc: "Convert a Sick into a Follower\nReduce Rebellion", nFollowers: 3, nSick: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Sick:
        u.setKind(Follower)
        site.town.rebellion = max(0, site.town.rebellion - 1)
        break
  ),
  SiteAbility(name: "Heal 2 Sick", desc: "Convert two Sick into Followers\nReduce Rebellion", nShamans: 1, nSick: 1, nActions: 1, action: proc(site: Site) =
    var i = 0;
    for u in site.units:
      if u.kind == Sick:
        u.setKind(Follower)
        site.town.rebellion = max(0, site.town.rebellion - 1)
        i += 1
        if i == 2:
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
    rebellionFlash = 5
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
        rebellionFlash = 5
        homeTown.serpentSacrificesMade += 1
        u.hp = 0
  ),
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()

  )
])

let siteChurch = SiteSettings(name: "Temple", desc: "Control the people", spr: 2, actionsToBuild: 3, abilities: @[
  SiteAbility(name: "Recruit", desc: "Gain 1 follower on any site", nFollowers: 3, nActions: 0, action: proc(site: Site) =
    # gain 1 follower
    inputMode = PlaceUnit
    placingUnits = @[newUnit(Follower, site)]
  ),
  SiteAbility(name: "Re-educate", desc: "Convert Rebels into Followers", nFollowers: 5, nRebels: 1, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Rebel:
        u.setKind(Follower)
  ),
  SiteAbility(name: "Pacify", desc: "Reduce rebellion by 3", nFollowers: 5, nActions: 2, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - 3, 0)
  ),
  abilityDemolish,
])

let siteBarracks = SiteSettings(name: "Barracks", desc: "Train soldiers", spr: 3, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train", desc: "Convert a Follower\ninto a Soldier", nFollowers: 2, startOfTurn: true, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.setKind(Soldier)
        break
  ),
  SiteAbility(name: "Train", desc: "Convert a Follower\ninto a Soldier", nFollowers: 1, nSoldiers: 3, nActions: 1, action: proc(site: Site) =
    for u in site.units:
      if u.kind == Follower:
        u.setKind(Soldier)
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
    actionFlash += 5
    rebellionFlash = 5
  ),
  abilityDemolish,
])

let siteGuild = SiteSettings(name: "Shaman Hut", desc: "Train powerful Shaman", spr: 5, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Train Shaman", desc: "Convert a Follower into a Shaman", nFollowers: 1, nShamans: 1, nActions: 2, action: proc(site: Site) =
    # turn a follower into a Shaman
    for u in site.units:
      if u.kind == Follower:
        u.setKind(Shaman)
        break
  ),
  SiteAbility(name: "Train Shaman", desc: "Convert 5 Followers into a Shaman", nFollowers: 5, nShamans: 0, nActions: 2, action: proc(site: Site) =
    for i in 0..<4:
      site.removeFollower()
    for u in site.units:
      if u.kind == Follower:
        u.setKind(Shaman)
        u.flash = 5
        break
  ),
  abilityDemolish,
])

let siteSeer = SiteSettings(name: "Seer Hut", desc: "Explore Destiny", spr: 9, actionsToBuild: 2, abilities: @[
  SiteAbility(name: "Peek", desc: "Look at the Next 2 Destiny", nShamans: 1, nActions: 1, action: proc(site: Site) =
    inputMode = ViewDestiny
    for i in 0..<2:
      let c = destinyPile.drawCard()
      if c != nil:
        moveCard(c, cardHand.pos.vec2f + vec2f(0, i.float32 * 62.0), 0.2 * i.float32) do(cm: CardMove):
          cardHand.add(cm.c)
  ),
  SiteAbility(name: "Delve", desc: "Rearrange the Next 5 Destiny", nShamans: 1, nActions: 3, action: proc(site: Site) =
    inputMode = RearrangeDestiny
    for i in 0..<5:
      let c = destinyPile.drawCard()
      if c != nil:
        moveCard(c, cardHand.pos.vec2f + vec2f(0, i.float32 * 62.0), 0.2 * i.float32) do(cm: CardMove):
          cardHand.add(cm.c)
  ),
  SiteAbility(name: "Avert", desc: "Draw a new Destiny", nShamans: 1, nActions: 2, action: proc(site: Site) =
    var c = destinyPile.drawCard()
    if c != nil:
      moveCard(currentDestiny, destinyDiscardPile.pos.vec2f, 0) do(cm: CardMove):
        destinyDiscardPile.add(cm.c)
      moveCard(c, currentDestiny.pos, 0.2) do(cm: CardMove):
        currentDestiny = cm.c
      currentDestiny = nil
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
      rebellionFlash = 5

  ),
  SiteAbility(name: "Demolish", desc: "clear space, increase rebellion by 3", nFollowers: 3, nActions: 1, action: proc(site: Site) =
    for i, s in site.town.sites:
      if s == site:
        var newSite = newSite(site.town, siteEmpty, i mod site.town.width, i div site.town.width)
        site.town.sites[i] = newSite
        newSite.units = site.units
        selectedSite = newSite
        site.town.rebellion += 3
        rebellionFlash = 5
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
        rebellionFlash = 5
        break
  ),
])

let siteWatchtower = SiteSettings(name: "Watchtower", desc: "Reduce Rebellion", spr: 6, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Supress Rebellion", desc: "Remove one Rebellion", nSoldiers: 3, nActions: 0, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - 1, 0)
  ),
  SiteAbility(name: "Supress Rebellion", desc: "Remove one Rebellion", nSoldiers: 1, nActions: 1, action: proc(site: Site) =
    site.town.rebellion = max(site.town.rebellion - 1, 0)
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

let destinySettings = @[
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "One follower becomes sick",
    sicknessSpreads: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onEndTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        let u = t.randomUnit() do(x: Unit) -> bool: x.kind == Follower
        if u != nil:
          u.setKind(Sick)
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "All newborns become sick",
    sicknessSpreads: false,
    rebelsMove: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        for site in t.sites:
          for u in site.units:
            if u.kind == Follower and u.age == 0:
              u.setKind(Sick)
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "One less action",
    rebellionIncreases: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        t.actions -= 1
  ),

  DestinyCardSettings(
    age: 2,
    count: 5,
    demand: "Sacrifice two followers",
    gain: "",
    penalty: "All newborns become sick",
    sicknessSpreads: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 2
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 2:
        for site in t.sites:
          for u in site.units:
            if u.kind == Follower and u.age == 0:
              u.setKind(Sick)
              u.flash = 5
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "One home disabled",
    rebelsMove: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onEndTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        let site = t.randomSite() do(site: Site) -> bool: site.settings == siteHouse
        if site != nil:
          echo "found home to disable"
          site.disabled += 1
        else:
          echo "no home found"
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "All homes blocked",
    rebelsMove: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onEndTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        for site in t.sites:
          if site.settings == siteHouse:
            site.blocked += 1
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    demand: "Sacrifice one follower",
    gain: "",
    penalty: "One Rebel appears",
    rebelsMove: true,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 1
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 1:
        let randomSite = rnd(t.sites)
        randomSite.units.add(newUnit(Rebel, randomSite))
  ),
  DestinyCardSettings(
    age: 2,
    count: 5,
    demand: "Sacrifice two followers",
    gain: "",
    penalty: "5 Rebels appear",
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 2
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 2:
        for i in 0..<5:
          let randomSite = rnd(t.sites)
          randomSite.units.add(newUnit(Rebel, randomSite))
  ),
  DestinyCardSettings(
    age: 2,
    count: 5,
    demand: "Sacrifice two followers",
    gain: "Gain an extra action",
    penalty: "A home is demolished",
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 2
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 2:
        var count = 0
        for site in t.sites:
          if site.settings == siteHouse:
            count += 1
        if count > 0:
          let r = rnd(count - 1)
          count = 0
          for site in t.sites:
            if site.settings == siteHouse:
              if r == count:
                site.settings = siteEmpty
                break
              count += 1
      else:
        t.actions += 1
  ),
  DestinyCardSettings(
    age: 1,
    count: 5,
    event: "2 Sick arrive",
    demand: "Heal 1 Sick",
    gain: "Gain 1 Action",
    penalty: "1 Follower becomes Sick",
    checkDemand: proc(c: Card, t: Town): bool =
      return t.nHealed >= 1
    ,onStartTurn: proc(c: Card, t: Town) =
      let randomSite = rnd(t.sites)
      for i in 0..<2:
        randomSite.units.add(newUnit(Sick, randomSite))
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.nHealed < 1:
        let unit = t.randomUnit() do(x: Unit) -> bool: x.kind == Follower
        if unit != nil:
          unit.setKind(Sick)
      else:
        t.actions += 1
  ),
  DestinyCardSettings(
    age: 2,
    count: 2,
    event: "5 Sick arrive",
    demand: "Heal 2 Sick",
    gain: "Gain 1 Action",
    penalty: "2 Followers become Sick",
    checkDemand: proc(c: Card, t: Town): bool =
      return t.nHealed >= 2
    ,onStartTurn: proc(c: Card, t: Town) =
      let randomSite = rnd(t.sites)
      for i in 0..<5:
        randomSite.units.add(newUnit(Sick, randomSite))
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.nHealed < 2:
        for i in 0..<2:
          var count = 0
          for site in t.sites:
            for u in site.units:
              if u.kind == Follower:
                count += 1
          if count > 0:
            let r = rnd(count - 1)
            count = 0
            for site in t.sites:
              for u in site.units:
                if u.kind == Follower:
                  if r == count:
                    u.setKind(Sick)
                    break
                count += 1
      else:
        t.actions += 1
  ),
]

let destinyOmens = @[
  DestinyCardSettings(
    age: 1,
    omen: true,
    count: 1,
    event: "1 Rebel appears",
    demand: "Kill one Rebel",
    penalty: "3 Rebels appear",
    onStartTurn: proc(c: Card, t: Town) =
      let site = rnd(t.sites)
      site.units.add(newUnit(Rebel, site))
    ,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.nRebelsKilled >= 1
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.nRebelsKilled < 1:
        for i in 0..<3:
          let site = rnd(t.sites)
          site.units.add(newUnit(Rebel, site))
  ),
  DestinyCardSettings(
    age: 1,
    omen: true,
    count: 1,
    event: "1 Sick appears",
    demand: "Heal one sick",
    penalty: "5 Sick appear",
    onStartTurn: proc(c: Card, t: Town) =
      let site = rnd(t.sites)
      site.units.add(newUnit(Sick, site))
    ,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.nHealed >= 1
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.nHealed < 1:
        for i in 0..<5:
          let site = rnd(t.sites)
          site.units.add(newUnit(Sick, site))
  ),
  DestinyCardSettings(
    age: 1,
    omen: true,
    count: 1,
    demand: "Sacrifice 3 Followers",
    penalty: "5 Followers become Sick",
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 3
    ,onEndTurn: proc(c: Card, t: Town) =
      for i in 0..<3:
        let u = t.randomUnit() do(x: Unit) -> bool: x.kind == Follower
        if u != nil:
          u.setKind(Sick)
  ),
  DestinyCardSettings(
    age: 2,
    omen: true,
    count: 1,
    event: "5 Rebels appear",
    demand: "Kill 3 Rebels",
    penalty: "Home becomes Rebel Base",
    onStartTurn: proc(c: Card, t: Town) =
      for i in 0..<5:
        let site = rnd(t.sites)
        site.units.add(newUnit(Rebel, site))
    ,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.nRebelsKilled >= 3
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.nRebelsKilled < 3:
        var count = 0
        for site in t.sites:
          if site.settings == siteHouse:
            count += 1
        if count > 0:
          let r = rnd(count)
          count = 0
          for site in t.sites:
            if site.settings == siteHouse:
              if r == count:
                site.settings = siteRebelBase
                break
              count += 1
  ),
  DestinyCardSettings(
    age: 2,
    omen: true,
    count: 1,
    event: "7 Sick appear",
    demand: "Sacrifice 5 Followers",
    penalty: "All Healing Huts Disabled",
    onStartTurn: proc(c: Card, t: Town) =
      for i in 0..<7:
        let site = rnd(t.sites)
        site.units.add(newUnit(Sick, site))
    ,
    checkDemand: proc(c: Card, t: Town): bool =
      return t.serpentSacrificesMade >= 5
    ,onStartNextTurn: proc(c: Card, t: Town) =
      if t.serpentSacrificesMade < 5:
        for site in t.sites:
          if site.settings == siteHealer:
            site.disabled = 1
  ),

]

let buildMenu: seq[SiteSettings] = @[
  siteHouse,
  siteAltar,
  siteGuild,
  siteChurch,
  siteBarracks,
  siteWatchtower,
  siteHealer,
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
  result.age = 0
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

  if pos == targetPos and flash > 0 and frame mod flashMod < flashCmp:
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
  if site.disabled > 0:
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

  # border
  setColor(if self.disabled > 0: 27 elif self.blocked > 0: 0 elif self.used or available == false: 15 else: 8)
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

proc drawBuildItem(self: SiteSettings, sx, sy, w, h: int, enabled: bool, site: Site, index: int) =
  setSpritesheet(0)
  var x = sx
  var y = sy

  setColor(22)
  richPrint("<21>" & $(index+1) & "</> " & name, x, y)

  y += 10
  x = sx
  var j = 0
  for i in 0..<actionsToBuild:
    if i >= site.town.actions:
      pal(1,27)
    spr(8, x, y)
    pal()
    x += 7

  y += 10
  x = sx
  setColor(23)
  for line in desc.split("\n"):
    print(line, x, y)
    y += 10

proc draw(self: SiteAbility, sx, sy, w, h: int, enabled: bool, site: Site, index: int) =
  setSpritesheet(0)
  var x = sx
  var y = sy
  if startOfTurn:
    setColor(25)
    richPrint("Start of turn: " & name, x, y)
  else:
    setColor(22)
    richPrint("<21>" & $(index+1) & "</> " & name, x, y)

  y += 10
  x = sx
  var j = 0
  let followerCount = site.getFollowerCount
  let shamanCount = site.getShamanCount
  let rebelCount = site.getRebelCount
  let soldierCount = site.getSoldierCount
  let sickCount = site.getSickCount

  for i in 0..<nActions:
    if i >= site.town.actions:
      pal(1,27)
    spr(8, x, y)
    pal()
    x += 7
  if nActions > 0:
    x += 3

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

method draw(self: DestinyCardSettings, c: Card, pos: Vec2f) =
  let passed = currentDestiny == c and checkDemand(c, currentTown)

  G.center = false

  if omen:
    G.normalColor = 27
  else:
    G.normalColor = ageColors[age-1]

  G.beginArea(pos.x, pos.y, 165, 80, gTopToBottom, true)

  #setSpritesheet(0)
  #var x = pos.x + 165 div 2 - age * 8
  #for i in 0..<age:
  #  G.ssprite(56, x, pos.y.int + 40 - 8, 16, 16, 2, 2)
  #  x += 16

  if event != "":
    G.textColor = teamColors[1]
    G.label(event)
    G.textColor = 22

  if demand != "":
    if passed:
      G.label("Demand: <18>" & demand)
    else:
      if currentDestiny == c and hoveringOverEndTurn and frame mod flashMod < flashCmp:
        G.label("Demand: <21>" & demand)
      else:
        G.label("Demand: <27>" & demand)
  if gain != "":
    if passed:
      G.label("And: <21>" & gain)
    else:
      G.label("And: " & gain)
  if penalty != "":
    if passed:
      G.label("Or: <24>" & penalty)
    else:
      G.label("Or: " & penalty)

  if sicknessSpreads:
    G.label("Sickness spreads: <spr(6,5,8)><spr(1,5,8)><spr(12)><spr(6,5,8)><spr(6,5,8)>")
  if rebelsMove:
    G.label("Rebels move: <spr(3)><spr(12)><spr(3)>")
  if rebellionIncreases:
    G.label("Rebellion increases: <spr(3)><spr(13)><spr(10)>")

  G.endArea()

method drawBack(self: DestinyCardSettings, c: Card, pos: Vec2f) =
  G.center = false

  if omen:
    G.normalColor = 27
  else:
    G.normalColor = ageColors[age-1]
  G.beginArea(pos.x, pos.y, 165, 80, gTopToBottom, true)

  setSpritesheet(0)
  var x = pos.x + 165 div 2 - age * 8
  for i in 0..<age:
    G.ssprite(56, x, pos.y.int + 40 - 8, 16, 16, 2, 2)
    x += 16

  G.endArea()


proc draw(self: Town) =
  let cx = screenWidth div 2 - width * 25
  let cy = screenHeight div 2 - height * 25
  for y in 0..<height:
    for x in 0..<width:
      let site = sites[width * y + x]
      if site != nil:
        site.screenPos = vec2i(cx + x * 52, cy + y * 52)
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

proc fillDestiny() =
  let ageDeck = newPile("", pkHidden)
  block dealCards:
    for ds in destinySettings:
      if ds.age == age and ds.omen == false:
        for i in 0..<ds.count:
          ageDeck.add(newCard(ds))

  ageDeck.shuffle()
  ageDeck.shuffle()
  ageDeck.shuffle()

  for i in 0..<ageCardCount[age-1]:
    destinyPile.add(ageDeck.drawCard())

  for c in destinyDiscardPile:
    destinyPile.add(c)

  destinyDiscardPile.clear()

  destinyPile.shuffle()
  destinyPile.shuffle()
  destinyPile.shuffle()

  var omens = newSeq[DestinyCardSettings]()
  for ds in destinyOmens:
    if ds.age == age:
      omens.add(ds)

  for i in 0..<age:
    if omens.len == 0:
      break
    var omen = rnd(omens)
    destinyPile.addBottom(newCard(omen))
    omens.delete(omens.find(omen))

  if age > 1:
    destinyPile.shuffle()

  var top = destinyPile.peek()
  if top != nil:
    while (DestinyCardSettings)(top.settings).omen:
      destinyPile.shuffle()
      top = destinyPile.peek()

proc startTurn() =
  turnPhase = phaseStartOfTurn
  phaseTimer = 0.5

  undoStack = @[]
  turn += 1

  # start of turn actions
  for town in towns:
    if town.team == 1:
      town.actions = 3
      actionFlash = 5
    else:
      town.actions = 0

    for site in town.sites:
      site.used = false
      for u in site.units:
        u.site = site
        u.sourceSite = site
        u.age += 1
      for ab in site.settings.abilities:
        if ab.startOfTurn:
          if ab.check(site):
            ab.action(site)

  if currentDestiny != nil:
    let ds = currentDestiny.settings.DestinyCardSettings
    if ds.onStartNextTurn != nil:
      for town in towns:
        if town.team == 1:
          ds.onStartNextTurn(currentDestiny, town)
    var c = currentDestiny
    moveCard(c, destinyDiscardPile.pos.vec2f, 0) do(cm: CardMove):
      destinyDiscardPile.add(cm.c)
    currentDestiny = nil

  for town in towns:
    town.serpentSacrificesMade = 0
    town.nHealed = 0
    town.nRebelsKilled = 0
    town.startingActions = town.actions

  # draw one destiny card
  var c = destinyPile.drawCard()
  if c == nil:
    age += 1
    if age > 3:
      age = 3
    fillDestiny()

    c = destinyPile.drawCard()

  if c != nil:
    moveCard(c, vec2f(screenWidth div 4 + 10, screenHeight - 82), 0) do(cm: CardMove):
      currentDestiny = c
      let ds = currentDestiny.settings.DestinyCardSettings
      if ds.onStartTurn != nil:
        for town in towns:
          if town.team == 1:
            ds.onStartTurn(currentDestiny, town)

proc endTurn() =
  turnPhase = phaseEndOfTurn

  undoStack = @[]

  if currentDestiny != nil:
    let ds = currentDestiny.settings.DestinyCardSettings
    if ds.sicknessSpreads:
      for town in towns:
        # spread sickness
        var nSick = town.getSickCount()
        if nSick > 0:
          echo town.name, " Sickness spreads: ", nSick
          for i in 0..<nSick:
            # convert a follower or soldier to sick
            let target = town.randomUnit() do(x: Unit) -> bool: x.kind == Follower or x.kind == Soldier
            if target != nil:
                target.setKind(Sick)
    # TODO fix rebels move
    #if ds.rebelsMove:
    #  for town in towns:
    #    for site in town.sites:
    #      var rebels: seq[Unit] = @[]
    #      for u in site.units:
    #        if u.kind == Rebel:
    #          rebels.add(u)
    #      for u in rebels:
    #        u.move(town.randomSite())

  for town in towns:
    # remove statuses
    for site in town.sites:
      if site.disabled > 0:
        site.disabled -= 1
      if site.blocked > 0:
        site.blocked -= 1


  if currentDestiny != nil:
    let ds = currentDestiny.settings.DestinyCardSettings
    if ds.onEndTurn != nil:
      for town in towns:
        if town.team == 1:
          ds.onEndTurn(currentDestiny, town)

  if homeTown.serpentSouls >= 100:
    dialogYesNo("THE SERPENT GOD HAS BEEN SUMMONED!") do:
      gameInit()
    return

  if homeTotem.settings != siteSerpent:
    dialogYesNo("Your cult has been destroyed") do:
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

    for site in town.sites:
      if site.settings != siteRebelBase:
        var nRebels = 0;
        for u in site.units:
          if u.kind == Rebel:
            nRebels += 1
        if nRebels >= 5:
          # if 5 rebels on a site, demolish structure, then build rebel base
          if site.settings != siteEmpty:
            site.settings = siteEmpty
          else:
            site.settings = siteRebelBase

    # for every 2 rebellion, make a new rebel
    let newRebels = clamp(town.rebellion div 5, 0, 3 + town.size)
    for i in 0..<newRebels:
      # pick a random site and spawn a rebel
      let randomSite = rnd(town.sites)
      randomSite.units.add(newUnit(Rebel, randomSite))
      #town.rebellion -= 1

    town.rebellion = clamp(town.rebellion, 0, town.sites.len * 5)

    # cap site
    for site in town.sites:
      if site.units.len > 15:
        site.units.setLen(15)

  phaseTimer = 0.5

proc tryEndTurn() =
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
  srand()

  loadSpritesheet(0, "spritesheet.png", 8, 8)
  loadSpritesheet(1, "tileset.png", 32, 32)
  loadSpritesheet(2, "tilesetWorld.png", 8, 8)

  turnPhase = phaseTurn

  loadMap(0, "map.json")
  setMap(0)

  age = 1
  particles = @[]
  towns = @[]
  armies = @[]
  destinyPile = newPile("Destiny", pkAllFaceDown)
  destinyPile.pos = vec2i(2, screenHeight - 82)
  destinyDiscardPile = newPile("Destiny Discard", pkHidden)
  destinyDiscardPile.pos = vec2i(screenWidth div 4 + 5, screenHeight + 10)
  cardHand = newPile("Hand", pkAllFaceOpen)
  cardHand.pos = vec2i(2,3)

  fillDestiny()

  turn = 0
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
          homeTotem = townSerpent
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

  startTurn()

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

proc startRelocate() =
  saveUndo()
  inputMode = Relocate
  placingUnits = @[]
  currentTown.actions -= 1
  actionFlash += 5
  for site in currentTown.sites:
    for u in site.units:
      u.site = site
      u.sourceSite = site

proc hasMovedUnits(): bool =
  var unitsMoved = 0
  for site in currentTown.sites:
    for u in site.units:
      if u.site != u.sourceSite:
        unitsMoved += 1

  return unitsMoved != 0

proc endRelocate() =
  inputMode = SelectSite

  if not hasMovedUnits():
    currentTown.actions += 1

proc grabUnit(unit: Unit) =
  if unit.site.blocked > 0:
    return
  placingUnits.add(unit)
  sfx(2)
  let site = unit.site
  if site != nil:
    let i = site.units.find(unit)
    if i != -1:
      site.units.delete(i)
  unit.site = nil

proc placeUnit(site: Site) =
  let u = placingUnits[placingUnits.high]
  placingUnits.delete(placingUnits.high)
  site.units.add(u)
  u.site = site
  selectedSite = site
  sfx(0)

proc gameGui() =
  G.normalColor = 15
  G.buttonBackgroundColor = 31
  G.buttonBackgroundColorDisabled = 1
  G.hoverColor = 22
  G.activeColor = 21
  G.textColor = 22
  G.downColor = 15
  G.disabledColor = 25
  G.backgroundColor = 1
  G.hSpacing = 3
  G.vSpacing = 3
  G.hPadding = 4
  G.vPadding = 4

  if mainMenu:
    G.beginArea(screenWidth div 2 - 100, screenHeight div 2 - 70, 200, 175, gTopToBottom, true, true)
    G.hExpand = true
    G.center = true
    G.label("<21>Serpent's Souls</>")
    G.label("A game by <8>Impbox</> for <27>LD43</>")
    if G.button("Continue"):
      mainMenu = false
    G.empty(5,5)
    if G.button("Focus Follows Mouse = " & (if focusFollowsMouse: "On" else: "Off")):
      focusFollowsMouse = not focusFollowsMouse
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
    G.endArea()

  if areYouSure:
    G.beginArea(screenWidth div 2 - 200, screenHeight div 2 - 30, 400, 70, gTopToBottom, true, true)
    G.label(areYouSureMessage)
    G.beginHorizontal(30)
    if G.button("Yes", true, K_1):
      if areYouSureYes != nil:
        areYouSureYes()
      areYouSure = false
    if G.button("No", true, K_2):
      if areYouSureNo != nil:
        areYouSureNo()
      areYouSure = false
    G.endArea()
    G.endArea()

  # right bar
  G.beginArea(screenWidth - 160, 3, 160 - 3, screenHeight - 36, gTopToBottom, true)
  G.center = true
  G.hExpand = true

  hoveringOverAbility = false

  if inputMode == SelectSiteToBuild:
    G.label("Select new Site to Build")
    for i, building in buildMenu:
      let keycode = (K_1.int + i).Keycode
      let ret = G.button(148, 35, currentTown.actions >= building.actionsToBuild, keycode) do(x,y,w,h: int, enabled: bool):
        building.drawBuildItem(x,y,w,h,enabled,selectedSite,i)
      if ret:
        if building.actionsToBuild > 0:
          actionFlash += 5
          currentTown.actions -= building.actionsToBuild

        selectedSite.settings = building
        selectedSite.used = false
        inputMode = SelectSite

        if forcedLabour:
          selectedSite.removeFollower()
          currentTown.rebellion += 1
          rebellionFlash = 5

    G.empty(10,10)
    if G.button("Cancel building", true, K_ESCAPE):
      inputMode = SelectSite
      selectedSite.used = false

  elif selectedUnit != nil:
    G.label("Shaman")
    if selectedUnit.usedAbility:
      G.label("Already used this turn")

    G.center = false
    var i = 0
    for a in selectedUnit.abilities:
      let ret = G.button(148, 50, placingUnits.len == 0 and a.check(selectedUnit)) do(x,y,w,h: int, enabled: bool):
        a.draw(x,y,w,h,enabled,selectedUnit)
      if ret:
        saveUndo()
        a.action(selectedUnit, selectedSite)
        if not a.multiUse:
          selectedUnit.usedAbility = true
      if G.hoverElement == G.element or G.downElement == G.element:
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

    if selectedSite.disabled > 0:
      G.label("<27>Disabled")

    if selectedSite.used:
      G.label("Already used this turn")

    setSpritesheet(1)
    if selectedSite.settings.spr != -1:
      G.sprite(selectedSite.settings.spr)

    G.center = false
    for k,a in selectedSite.settings.abilities:
      let keycode = (K_1.int + k).Keycode
      let ret = G.button(148, 50, selectedSite.disabled == 0 and placingUnits.len == 0 and a.check(selectedSite), keycode) do(x,y,w,h: int, enabled: bool):
        a.draw(x,y,w,h,enabled,selectedSite,k)
      if ret:
        inputMode = SelectSite
        saveUndo()
        a.action(selectedSite)
        if not a.multiUse:
          selectedSite.used = true
        if selectedSite.settings == siteEmpty:
          selectedSite.used = false
        currentTown.actions -= a.nActions
        if a.nActions > 0:
          actionFlash += 5
      if G.hoverElement == G.element or G.downElement == G.element:
        hoveringOverAbility = true


  G.hExpand = false
  G.endArea()

  # bottom bar
  G.beginArea(0, screenHeight - 31, screenWidth, 28, gRightoLeft)
  G.center = true

  hoveringOverEndTurn = false

  if turnPhase == phaseTurn:
    if inputMode == SelectSite or inputMode == Relocate:
      if G.button("<21>E</>nd Turn", 100, 28, placingUnits.len == 0, K_E):
        tryEndTurn()
      if G.hoverElement == G.element or G.downElement == G.element:
        hoveringOverEndTurn = true
    elif inputMode == ViewDestiny:
      if G.button("<21>E</>nd Peeking", 100, 28, placingUnits.len == 0, K_E):
        inputMode = SelectSite
        for i in 0..<cardHand.len:
          var c = cardHand.drawCard()
          moveCard(c, destinyPile.pos.vec2f, 0.2 * i.float32) do(cm: CardMove):
            destinyPile.add(cm.c)
    else:
      G.empty(100, 28)

    if currentTown != nil:
      if inputMode == Relocate:
        if hoveringOverAbility:
          G.buttonBackgroundColor = 27
        if G.button(if (hoveringOverAbility or hoveringOverEndTurn): "<21>This will end your relocation</>" elif not hasMovedUnits(): "Cancel <21>R</>elocate" else: "Complete <21>R</>elocate", 148, 28, placingUnits.len == 0, K_R):
          endRelocate()
        G.buttonBackgroundColor = 31
      elif inputMode == SelectSite:
        if G.button((if currentTown.actions >= 1: "<spr(8)>" else: "<spr(9)>") & " <21>R</>elocate\n<23>Move any number of units", 148, 28, currentTown.actions >= 1, K_R):
          startRelocate()

  else:
    discard G.button(100, 28, false, K_UNKNOWN) do(x,y,w,h: int, enabled: bool):
      pal(29,0)
      spr(48 + ((frame div 5).int mod 4) * 2, x + w div 2 - 8, y, 2, 2)
      pal()
    discard G.button($turnPhase, 148, 28, false)

  G.endArea()

  # town info
  G.beginArea(screenWidth div 4 + 4, 3, screenWidth div 2 - 8, 50, gTopToBottom, true)
  G.center = false
  if currentTown != nil:
    G.vSpacing = 2
    G.vPadding = 0
    G.textColor = 18
    setFont(1)
    G.textColor = teamColors[currentTown.team]
    G.beginHorizontal(20)
    G.label("The Village of " & currentTown.name)
    setFont(0)
    G.textColor = 22
    G.empty(32,0)
    G.label("Age " & $age & "  Day " & $turn & "/" & $ageCardCount[age-1])
    G.endArea()

    if (actionFlash > 0 or (hoveringOverEndTurn and currentTown.actions > 0)) and frame mod flashMod < flashCmp:
      pal(1,21)
      actionFlash -= 1
    var actionsStr = "Actions: "
    for i in 0..<currentTown.actions:
      actionsStr &= "<spr(8)>"
    for i in currentTown.actions..<currentTown.startingActions:
      actionsStr &= "<spr(9)>"
    G.label(actionsStr)
    pal()

    let newRebels = clamp(currentTown.rebellion div 5, 0, 3 + currentTown.size)
    if (rebellionFlash > 0 or (newRebels > 0 and hoveringOverEndTurn)) and frame mod flashMod < flashCmp:
      pal(1,27)
      if rebellionFlash > 0:
        rebellionFlash -= 1

    var rebellionStr = "Rebellion: "
    var rebellionRemaining = currentTown.rebellion
    while rebellionRemaining > 0:
      if rebellionRemaining >= 5:
        rebellionStr &= "<spr(10,4,8)><spr(10,4,8)><spr(10,4,8)><spr(10,4,8)><spr(10,7,8)>"
        rebellionRemaining -= 5
      else:
        rebellionStr &= "<spr(10,6,8)>"
        rebellionRemaining -= 1

    var plusRebellion = currentTown.getRebelCount()
    if plusRebellion > 0:
      rebellionStr &= " +"
    while plusRebellion > 0:
      if plusRebellion >= 5:
        rebellionStr &= "<spr(10,4,8)><spr(10,4,8)><spr(10,4,8)><spr(10,4,8)><spr(10,7,8)>"
        plusRebellion -= 5
      else:
        rebellionStr &= "<spr(10,6,8)>"
        plusRebellion -= 1

    if newRebels > 0:
      rebellionStr &= " <spr(12,7,8)> "
    for i in 0..<newRebels:
      rebellionStr &= "<spr(3,7,8)>"
    G.label(rebellionStr)
    pal()

  G.endArea()

  G.hSpacing = 3
  G.vSpacing = 3
  G.hPadding = 4
  G.vPadding = 4

  # draw cards and piles

  destinyPile.draw()
  destinyDiscardPile.draw()

  if currentDestiny != nil and currentTown != nil:
    currentDestiny.draw()

  if cardHand.len > 0:
    for c in cardHand:
      c.draw()

  drawCards()

proc gameUpdate(dt: float32) =
  time += dt

  if updateCards(dt):
    return

  G.update(gameGui, dt)

  case turnPhase:
    of phaseStartOfTurn:
      if phaseTimer >= 0:
        phaseTimer -= dt
        if phaseTimer < 0:
          turnPhase = phaseTurn
      return
    of phaseEndOfTurn:
      if phaseTimer >= 0:
        phaseTimer -= dt
        if phaseTimer < 0:
          startTurn()
      return
    else:
      discard

  if(btnp(pcBack)):
    mainMenu = not mainMenu

  if G.activeElement != 0 or G.hoverElement != 0 or G.modalArea != 0:
    return

  if mousebtnp(2):
    undo()
    return

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
      for u in site.units:
        if u.hp <= 0:
          if u.kind == Rebel:
            town.nRebelsKilled += 1
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
          if focusFollowsMouse:
            selectedSite = hoverSite
        for u in site.units:
          if mx >= u.pos.x - 1 and mx <= u.pos.x + 7 and my >= u.pos.y - 1 and my <= u.pos.y + 7:
            hoverUnit = u
            break

  if hoverUnit != lastHoverUnit or hoverSite != lastHoverSite:
    hoverChangeTime = time

  var doubleClick = false
  if mousebtnp(0):
    let (mx,my) = mouse()
    let clickPos = vec2i(mx,my)
    if lastClickTime > time - 0.3 and (lastClickPos - clickPos).magnitude < 5:
      doubleClick = true
    lastClickPos = clickPos
    lastClickTime = time

  if inputMode == SelectUnit:
    if mousebtnp(0):
      if hoverUnit != nil:
        onSelectUnit(hoverUnit)
        return

  if inputMode == SelectSite and doubleClick:
    if hoverUnit != nil:
      if currentTown.actions >= 1:
        startRelocate()
        if hoverUnit.kind != Rebel:
          grabUnit(hoverUnit)
      return
    elif hoverSite != nil:
      showCircleMenu = not showCircleMenu
      selectedSite = hoverSite

  if inputMode == Relocate or inputMode == PlaceUnit:
    if inputMode == Relocate and placingUnits.len == 0 and doubleClick and hoverUnit == nil:
      endRelocate()

    if mousebtnp(0):
      if hoverSite != nil:
        selectedSite = hoverSite
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
          grabUnit(hoverUnit)
          return
      else:
        if hoverSite != nil:
          # place unit
          if placingUnits.len > 0:
            placeUnit(hoverSite)
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
                      u.setKind(Rebel)
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
        let nActions = 3
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
        let nActions = 3
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
  vline(screenWidth div 4, 0, screenHeight - 1)

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

    # tooltip
    if hoverChangeTime < time - 0.3:
      setColor(21)
      setOutlineColor(1)
      if hoverUnit == nil and hoverSite != nil:
        printOutlineC($hoverSite.settings.name, mx, my - 15)
      elif hoverUnit != nil:
        printOutlineC($hoverUnit.kind, mx, my - 15)

    # cursor
    pal(29,0)
    setSpritesheet(0)
    if inputMode == SelectUnit:
      spr(33, mx - 4, my - 4)
    elif inputMode == Relocate or inputMode == PlaceUnit:
      spr(32, mx, my)
    else:
      spr(0, mx, my)
    pal()

    # units
    var x = 0
    var y = 0
    for i in countdown(placingUnits.high,0):
      let u = placingUnits[i]
      u.draw(mx + 7 + x, my + 7 + y)
      x += 6
      if x >= 6 * 5:
        x = 0
        y += 8

# INIT
nico.init("impbox", "Serpent's Souls")

loadConfig()
loadPaletteFromGPL("palette.gpl")
loadFont(0, "sins-v2.1.png", """ ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,;:?!-_~+=*%€$£¢<>©®#"'&()[]|`/\@°""")
loadFont(1, "sorrowful-v1.png", """ ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,;:?!-_~#"'&()[]|`/\@°+=*%€$£¢<>©®""")

loadSfx(0, "sfx/drop.ogg")
loadSfx(1, "sfx/move.ogg")
loadSfx(2, "sfx/grab.ogg")

setKeyMap("Left:Left,A;Right:Right,D;Up:Up,W;Down:Down,S;A:Z,1;B:X,2;X:C,3;Y:V,4;L1:B,5;L2:H;R1:M;R2:<;Start:Space,Return;Back:Escape")
nico.createWindow("ld43", 1920 div 3, 1080 div 3, 2)

fps(60)
fixedSize(true)
integerScale(true)

nico.run(gameInit, gameUpdate, gameDraw)
