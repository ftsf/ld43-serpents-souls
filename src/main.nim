{.experimental: "codeReordering".}

#import nimprof

import nico
import nico/vec
import utils
import sequtils
import cards
import gui
import times
import algorithm
import streams
import os
import pathfinding
import hashes
import tables

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

const cardWidth = 165
const cardHeight = 80
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
    hasDest: bool
    dest: Vec2f
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
    Cavalry

  Unit = ref object of RootObj
    kind: UnitKind
    site: Site
    sourceSite: Site
    team: int
    age: int
    pos: Vec2f
    moveDist: int
    attackMaxDist: int
    attackMinDist: int
    attackIndirect: bool
    battlePos: Vec2i
    battleMoves: int
    battleAttacks: int
    battleMovesInit: int
    battleAttacksInit: int
    flash: int
    hp: int
    usedAbility: bool
    souls: int
    abilities: seq[ShamanAbility]
    hidden: bool
    revealed: bool

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
    nSoulsToUnlock: int
    requires: seq[ShamanAbility]
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
    damage: int

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

  BattleMoveType = enum
    bmMove
    bmAttack
    bmRetreat

  BattleMove = object
    unit: Unit
    lastPos: Vec2i
    path: seq[Vec2i]
    index: int
    time: float32
    onComplete: proc(unit: Unit)
    moveType: BattleMoveType

  Battle = ref object of RootObj
    teamTurn: int
    pos: Vec2i
    age: int
    width: int
    height: int
    map: seq[int]
    units: seq[Unit]
    moves: seq[BattleMove]
    pauseTimer: float32
    knownTraps: seq[Vec2i]
    unitsToDeploy: seq[Unit]
    completed: bool
    victor: int

  Army = ref object of RootObj
    pos: Vec2i
    units: seq[Unit]
    team: int
    source: Town
    dest: Town
    moved: bool

  DestinyCardSettings = ref object of CardSettings
    tutorial: bool
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
  ChooseAbilityToLearn

# PREPROCS

proc hash*(x: Vec2i): Hash =
  var h: Hash = 0
  h = h !& x.x
  h = h !& x.y
  result = !$h

iterator neighbors*(self: Battle, unit: Unit, node: Vec2i, reality = true): Vec2i =
  for x in -1..1:
    for y in -1..1:
      if x == 0 or y == 0:
        let offset = vec2i(x,y)
        let n = node + offset
        if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
          let t = map[n.y * width + n.x]
          if t != 0 and t != 4:
            if not self.impassable(unit, n, reality):
              yield n

iterator neighborsDiagonal*(self: Battle, unit: Unit, node: Vec2i, reality = true): Vec2i =
  for x in -1..1:
    for y in -1..1:
      if x != 0 and y != 0:
        let offset = vec2i(x,y)
        let n = node + offset
        if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
          let t = map[n.y * width + n.x]
          if t != 0 and t != 4:
            if not self.impassable(unit, n, reality):
              yield n

proc heuristic*(self: Battle, a,b: Vec2i): int =
  return abs(a.x - b.x) + abs(a.y - b.y)

iterator items*(self: Battle): Vec2i =
  for y in 0..<height:
    for x in 0..<width:
      yield vec2i(x,y)

proc cost*(self: Battle, a,b: Vec2i, mover: Unit = nil, reality = true): int =
  let fromt = map[a.y * width + a.x]
  let t = map[b.y * width + b.x]
  if mover != nil and mover.kind == Cavalry:
    result = case t:
      of 0,1: 2 # dirt
      of 2: 999 # rock
      of 3: 4 # forest
      of 4: 999 # water
      of 5: 1 # road
      of 9: 4
      else: 999
  else:
    result = case t:
      of 0,1: 2 # dirt
      of 2: 6 # rock
      of 3: 3 # forest
      of 4: 999 # water
      of 5: 1 # road
      of 9: 2
      else: 999
    if fromt == 2 and t == 2:
      result = 4
  if fromt == 2 and t != 2:
    result -= 1
  if mover.team == 1 and fromt == 3 and t == 3:
    result -= 1
  result = max(result,1)

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
proc newParticleDest*(pos: Vec2f, dest: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int)
proc newParticleText*(pos: Vec2f, vel: Vec2f, ttl: float32, text: string, color1,color2: int)
proc newUnit(kind: UnitKind, site: Site): Unit

proc removeFollower(self: Site): bool =
  for i,u in units:
    if u.kind == Follower:
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      newParticleDest(u.pos, vec2f(screenWidth div 4 + 40, 50), 0.25, 0, 16, 19)
      return true

proc killFollower(self: Site): bool =
  for i,u in units:
    if u.kind == Follower:
      u.site.town.rebellion += 1
      units.delete(i)
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
      newParticleDest(u.pos, vec2f(screenWidth div 4 + 40, 50), 0.25, 0, 16, 19)
      rebellionFlash = 5
      return true

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
var saveExists: bool
var battlesWaging: bool

var pan: Vec2i

var particles: seq[Particle]
var time: float32
var turn: int
var frame: uint32
var selectedSite: Site
var hintSite: Site
var homeTown: Town
var homeTotem: Site
var currentTown: Town
var currentBattle: Battle
var battles: seq[Battle]
var currentArmy: Army
var placingUnits: seq[Unit]
var placingUnitSource: Site
var inputMode: InputKind
var selectedUnit: Unit
var selectedUnitMoves: Table[Vec2i,(int, (bool, Vec2i))]
var selectedUnitAttacks: seq[Vec2i]
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

var mainMenu: bool = true
var optionsMenu: bool = false
var gameStarted = false

var areYouSure: bool
var areYouSureMessage: string
var areYouSureYes: proc()
var areYouSureNo: proc()

var onSelectUnit: proc(unit: Unit) = nil
var selectUnitMinRadius: int
var selectUnitMaxRadius: int

var undoStack: seq[Town]

# CONSTANTS 2

type GuideStep = object
  text: string
  check: proc(): bool
  clickNext: bool

let guide = @[
  GuideStep(text: "The <21>Serpent Totem</> has been completed <21>Great Leader</>!", clickNext: true),
  GuideStep(text: "Now the Serpent demands <27><s>Blood</>\n<21>we must provide it</>!", clickNext: true),
  GuideStep(text: "However, we have few Followers(<spr(1)>), so we must gain more!", clickNext: true),
  GuideStep(text: "Let us build a <21>Home</>\nand have our Followers(<spr(1,5,8)><spr(1,9,8)>) <21>Reproduce</>.", clickNext: true),
  GuideStep(text: "First, Activate the <21>R</>elocate Ability\nThis uses 1 Action (<spr(8)>) and lets us move any number\nof our Units from any Site to any Site.", check: proc(): bool =
    G.hintHotkey = K_R
    return inputMode == Relocate
  ),
  GuideStep(text: "Now pick up 3 Followers <spr(1,5,8)><spr(1,5,8)><spr(1,5,8)> from your Serpent Totem.\nClick on a Unit to pick it up.\nWith a Unit in hand, click on a Site to place it.", check: proc(): bool =
    hintSite = homeTotem
    return inputMode == Relocate and placingUnits.len == 3
  ),
  GuideStep(text: "Place those 3 Followers on an Empty Site", check: proc(): bool =
    hintSite = nil
    for site in homeTown.sites:
      if site.settings == siteEmpty:
        hintSite = site
        for a in site.settings.abilities:
          if a.name == "Build Site" and a.check(site):
            return true
  ),
  GuideStep(text: "Now <21>End Relocation</> to complete this action.", check: proc(): bool =
    G.hintHotkey = K_R
    return inputMode == SelectSite
  ),
  GuideStep(text: "With the <21>Empty Site</> with 3 Followers selected,\nchoose <21>Build Site</> and select <21>Home</>. This also costs 1 Action <spr(8)>", check: proc(): bool =
    var count = 0
    if selectedSite != nil and selectedSite.settings == siteEmpty and selectedSite.units.len >= 3:
      G.hintHotkey = K_1
    else:
      G.hintHotkey = K_UNKNOWN
    for site in homeTown.sites:
      if site.settings == siteHome:
        count += 1
    if count >= 2:
      return true
  ),
  GuideStep(text: "You now have 1 Action left <spr(8)>\nUse it to Relocate Followers back to the Serpent Totem.", check: proc(): bool =
    if inputMode == SelectSite:
      G.hintHotkey = K_R
    else:
      G.hintHotkey = K_UNKNOWN
    var count = 0
    for site in homeTown.sites:
      if site.settings == siteHome:
        count += 1
    if count >= 2:
      return true
  ),
  GuideStep(text: "To satisfy the <27>Demand</8> you must Sacrifice one Follower to\nthe Serpent. Otherwise, you will <27>suffer her wrath</>!", clickNext: true),
  GuideStep(text: "Select the <21>Serpent Totem</> and select\n<21>Sacrifice to Serpent</>, this requires no Actions\nand is <8>multi-use</> (can be used multiple times per turn).\nIt does require 2 Followers (<spr(1)><spr(1)>) to be present.", check: proc(): bool =
    hintSite = homeTotem
    if selectedSite != nil and selectedSite.settings == siteSerpent:
      G.hintHotkey = K_1
    else:
      G.hintHotkey = K_UNKNOWN
    return homeTown.serpentSacrificesMade >= 1
  ),
  GuideStep(text: "The Serpent is now Satisfied for this Turn.\nHowever, Killing a Follower increases <27>Rebellion</> (<spr(10)>).", clickNext: true),
  GuideStep(text: "When <27>Rebellion</> (<spr(10)>) reaches <27>5</>, A <27>Rebel</> (<spr(3)>) will appear.\nRebels will kill Followers at the End of the Turn.", clickNext: true),
  GuideStep(text: "<27>Rebels</> (<spr(3)>) can be killed by <10>Soldiers</> (<spr(4)>).\nYou will need to build a <21>Barracks</> to Train them.", clickNext: true),
  GuideStep(text: "<21>Home</>s require 2 Followers to <21>Reproduce</> at the <21>Start Of Turn</>.\n<21>Relocate</> excess Followers to the <21>Serpent Totem</>,\nwe have other uses for them.", check: proc(): bool =
    hintSite = nil
    if inputMode == SelectSite:
      G.hintHotkey = K_R
    elif inputMode == Relocate:
      G.hintHotkey = K_UNKNOWN
    for site in homeTown.sites:
      if site.settings == siteHome:
        if site.units.len != 2:
          return false
    if selectedSite.settings == siteSerpent and selectedSite.units.len == 4:
      if inputMode != SelectSite:
        G.hintHotkey = K_R
      else:
        return true
  ),
  GuideStep(text: "Select your <21>Shaman</> <spr(2)>", check: proc(): bool =
    selectedUnit != nil and selectedUnit.kind == Shaman
  ),
  GuideStep(text: "Sacrfice a Follower to your Shaman", check: proc(): bool =
    G.hintHotkey = K_1
    for site in homeTown.sites:
      for u in site.units:
        if u.kind == Shaman and u.souls == 2:
          return true
  ),
  GuideStep(text: "This uses your Shaman's Action (<spr(24)>) and gave them a Soul (<spr(7)>).", clickNext: true),
  GuideStep(text: "Souls (<spr(7)>) can be used to learn new <21>Shaman Skills</>.\n", clickNext: true),
  GuideStep(text: "You're out of Actions now, so <21>End the Turn</>.", check: proc(): bool =
    G.hintHotkey = K_E
    if turn == 2:
      return true
  ),
  GuideStep(text: "Each turn, the Serpent will make a <27>Demand</>.\nThis is communicated to you via\nthe <21>Destiny Deck</> at the <21>bottom-left</>.", clickNext: true),
  GuideStep(text: "Ignore the Serpent's Demands at your peril.\nRed Cards are <27>Omens</>, these are difficult challenges.\nBe Prepared!", clickNext: true),
]

var guideMode = false
var guideStep = 0
var guideStepTextStep = 0

# THREE PATHS, HEALER, WARRIOR, ALCHEMIST
# HEALER -> Healer / Recruiter
#  * Convert
#  * Heal
#  * Heal 2
#  * Heal Site
#  * Autoheal
#  * Homes produce twins

# WARRIOR -> Harvester / Battler
#  * Kill Rebel
#  * Round up
#  * Cleanse
#  * Kill half on site

# ALCHEMIST
#  * Refresh site
#  * Gain action
#  * Shield site (protect site from kills)

let shamanAbilities = @[
  ShamanAbility(name: "Sacrifice Follower", desc: "Sacrifice Follower\nto gain a soul", nActions: 0, nFollowers: 1, nSouls: 0, action: proc(unit: Unit, site: Site) =
    if site.killFollower():
      unit.souls += 1
  ),
  # healer
  ShamanAbility(name: "Convert", desc: "Gain a Follower on Site", nActions: 1, nSoulsToUnlock: 2, action: proc(unit: Unit, site: Site) =
    site.units.add(newUnit(Follower, site))
  ),
  ShamanAbility(name: "Heal", desc: "Heal a Follower on Site", nActions: 1, nSick: 1, nSoulsToUnlock: 2, action: proc(unit: Unit, site: Site) =
    for u in site.units:
      if u.kind == Sick:
        u.setKind(Follower)
        break
  ),
  ShamanAbility(name: "Heal 2", desc: "Heal 2 Followers on Site", nActions: 1, nSick: 2, nSoulsToUnlock: 4, action: proc(unit: Unit, site: Site) =
    var i = 0;
    for u in site.units:
      if u.kind == Sick:
        u.setKind(Follower)
        i += 1
        if i == 2:
          break
  ),
  # warrior
  ShamanAbility(name: "Stab", desc: "Kill 1 Rebel on Site", nActions: 1, nRebels: 1, nSoulsToUnlock: 2, action: proc(unit: Unit, site: Site) =
    for u in site.units:
      if u.kind == Rebel:
        u.hp = 0
        unit.souls += 1
        break
  ),
  ShamanAbility(name: "Round up", desc: "Relocate up to 3 Rebels from Site", nActions: 1, nRebels: 1, nSoulsToUnlock: 3, nSouls: 1, action: proc(unit: Unit, site: Site) =
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
  ShamanAbility(name: "Cleansing", desc: "Kill all Followers and Sick\non Site. Rebellion x2", nActions: 2, nSoulsToUnlock: 5, nSouls: 2, action: proc(unit: Unit, site: Site) =
    for u in site.units:
      if u.kind == Follower or u.kind == Rebel or u.kind == Sick:
        unit.souls += 1
        unit.site.town.rebellion += 2
        rebellionFlash = 5
        u.hp = 0
  ),
  ShamanAbility(name: "Fireball", desc: "Kills half of the Soldiers\non Site (rounded up)", nSoldiers: 1, nSoulsToUnlock: 5, nActions: 2, nSouls: 3, action: proc(unit: Unit, site: Site) =
    var nSoldiers = 0
    for u in site.units:
      if u.kind == Soldier:
        nSoldiers += 1
    var toKill = (nSoldiers + 2 - 1) div 2
    for i in 0..<toKill:
      site.removeSoldier()
  ),
  # alchemist
  ShamanAbility(name: "Refresh Site", desc: "Allow a site to be used again", nActions: 1, nSoulsToUnlock: 2, nSouls: 1, action: proc(unit: Unit, site: Site) =
    site.used = false
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
    if site.killFollower():
      homeTown.serpentSouls += 1
      homeTown.serpentSacrificesMade += 1
  ),
  SiteAbility(name: "Sacrifice Shaman", desc: "Kill a Shaman, all their souls\nwill flow into the Serpent", nFollowers: 1, nShamans: 1, multiUse: true, nActions: 0, action: proc(site: Site) =
    inputMode = SelectUnit
    selectUnitMinRadius = 0
    selectUnitMaxRadius = 0
    onSelectUnit = proc(unit: Unit) =
      if unit.kind == Shaman and unit.site == site:
        unit.hp = 0
        homeTown.serpentSouls += 1
        homeTown.serpentSouls += unit.souls
        homeTown.serpentSacrificesMade += 1
        rebellionFlash = 5
        site.town.rebellion += 1
        inputMode = SelectSite
        onSelectUnit = nil
  ),
  SiteAbility(name: "Expand Village", desc: "Expands the village from\n3x3 to 5x3 and 5x3 to 5x4", nFollowers: 10, nActions: 3, action: proc(site: Site) =
    site.town.expand()
  )
])

let siteSerpent2 = SiteSettings(name: "Serpent Totem", spr: 12, abilities: @[
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a follower and let their\nsoul flow into the Serpent", nFollowers: 2, nActions: 0, multiUse: true, action: proc(site: Site) =
    # kill 1 follower, capture one soul
    if site.killFollower():
      homeTown.serpentSouls += 1
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
  SiteAbility(name: "Expand Village", desc: "Expands the village to\n5x3 Sites", nFollowers: 10, nActions: 4, action: proc(site: Site) =
    site.town.expand()
  )
])

let siteSerpent3 = SiteSettings(name: "Serpent Totem", spr: 13, abilities: @[
  SiteAbility(name: "Sacrifice to Serpent", desc: "Kill a follower and let their\nsoul flow into the Serpent", nFollowers: 2, nActions: 0, multiUse: true, action: proc(site: Site) =
    # kill 1 follower, capture one soul
    if site.killFollower():
      homeTown.serpentSouls += 1
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
    if site.killFollower():
      site.town.actions += 1
      actionFlash += 5
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
      discard site.killFollower()
    for u in site.units:
      if u.kind == Follower:
        u.setKind(Shaman)
        u.flash = 5
        break
  ),
  SiteAbility(name: "Clear Skills", desc: "Clear One Shaman's Skills", nShamans: 1, nActions: 1, action: proc(site: Site) =
    inputMode = SelectUnit
    selectUnitMinRadius = 0
    selectUnitMaxRadius = 0
    onSelectUnit = proc(unit: Unit) =
      if unit.kind == Shaman and unit.site == site:
        unit.abilities = @[]
        inputMode = SelectSite
        onSelectUnit = nil
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

let siteHome = SiteSettings(name: "Home", desc: "A place of reproduction", spr: 1, actionsToBuild: 1, abilities: @[
  SiteAbility(name: "Reproduce", nFollowers: 2, nActions: 0, startOfTurn: true, action: proc(site: Site) =
    site.units.insert(newUnit(Follower, site), 0)
  ),
  abilityDemolish,
])

let siteHovel = SiteSettings(name: "Hovel", desc: "A filty obstacle", spr: 7, actionsToBuild: 0, abilities: @[
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
    selectUnitMinRadius = 1
    selectUnitMaxRadius = 1
    onSelectUnit = proc(unit: Unit) =
      if unit.kind == Rebel:
        if abs(unit.site.pos.x - site.pos.x) <= 1 and abs(unit.site.pos.y - site.pos.y) <= 1:
          unit.hp = 0
          inputMode = SelectSite
          onSelectUnit = nil

  ),
  abilityDemolish,
])

let destinySettings = @[
  DestinyCardSettings(
    tutorial: true,
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
        let site = t.randomSite() do(site: Site) -> bool: site.settings == siteHome
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
          if site.settings == siteHome:
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
          if site.settings == siteHome:
            count += 1
        if count > 0:
          let r = rnd(count - 1)
          count = 0
          for site in t.sites:
            if site.settings == siteHome:
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
      if t.serpentSacrificesMade < 3:
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
          if site.settings == siteHome:
            count += 1
        if count > 0:
          let r = rnd(count)
          count = 0
          for site in t.sites:
            if site.settings == siteHome:
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

let siteSettings: seq[SiteSettings] = @[
  siteHome,
  siteAltar,
  siteGuild,
  siteChurch,
  siteBarracks,
  siteWatchtower,
  siteHealer,
  siteSeer,
  siteSerpent,
  siteSerpent2,
  siteSerpent3,
  siteSquare,
  siteHovel,
  siteRebelBase,
  siteEmpty,
]

let buildMenu: seq[SiteSettings] = @[
  siteHome,
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
  result.moveDist = case kind:
    of Cavalry: 8
    of Shaman: 5
    else: 6
  result.attackMaxDist = case kind:
    of Shaman: 3
    else: 1
  result.attackMinDist = case kind:
    of Cavalry: 1
    of Shaman: 2
    else: 1
  result.attackIndirect = case kind:
    of Shaman: true
    else: false
  result.battleMovesInit = case kind:
    of Cavalry: 2
    else: 1
  result.battleAttacksInit = case kind:
    of Soldier,Shaman,Cavalry: 1
    else: 0

proc dialogYesNo(text: string, onYes: proc() = nil, onNo: proc() = nil) =
  areYouSure = true
  areYouSureMessage = text
  areYouSureYes = onYes
  areYouSureNo = onNo

proc newParticle*(pos: Vec2f, vel: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int) =
  particles.add(Particle(pos: pos, vel: vel, ttl: ttl, maxTtl: ttl, sheet: sheet, startSpr: startSpr, endSpr: endSpr))

proc newParticleDest*(pos: Vec2f, dest: Vec2f, ttl: float32, sheet: int, startSpr: int, endSpr: int) =
  particles.add(Particle(pos: pos, hasDest: true, dest: dest, ttl: ttl, maxTtl: ttl, sheet: sheet, startSpr: startSpr, endSpr: endSpr))

proc newParticleText*(pos: Vec2f, vel: Vec2f, ttl: float32, text: string, color1,color2: int) =
  particles.add(Particle(pos: pos, vel: vel, ttl: ttl, maxTtl: ttl, text: text, color1: color1, color2: color2))



proc draw(self: Unit, x,y: int) =
  let (cx,cy) = getCamera()
  let targetPos = vec2f(x,y)
  if particles.len == 0:
    pos = lerp(pos, targetPos, 0.5)
    if (pos - targetPos).magnitude < 1.0:
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

  if not isVisible(1):
    return

  if currentBattle != nil and hidden:
    ditherPatternCheckerboard()

  if kind == Follower:
    spr(1, x, y)
  elif kind == Shaman:
    spr(if team == 1: 14 else: 46, x - 4, y - 4, 2, 2)
  elif kind == Rebel:
    spr(3, x, y)
  elif kind == Soldier:
    spr(if team == 2: 20 else: 4, x, y)
  elif kind == Cavalry:
    spr(if team == 2: 22 else: 23, x, y)
  elif kind == Neutral:
    spr(5, x, y)
  elif kind == Sick:
    spr(6, x, y)

  pal()
  ditherPattern()

  if currentBattle == nil and kind == Shaman:
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

proc `<`*(a,b: (Vec2i,int)): bool =
  return a[1] < b[1]

proc isTrap(self: Battle, unit: Unit, pos: Vec2i, reality = true): bool =
  var count = 0
  for u in units:
    if u.hp > 0 and u.team != unit.team and manhattanDist(pos, u.battlePos) == 1 and u.battleAttacks > 0:
      if reality or u.isVisible(unit.team):
        count += 1
        if count == 2:
          return true
  return false

proc canAttack(self: Battle, unit: Unit, pos: Vec2i): bool =
  return self.canAttackFrom(unit, unit.battlePos, pos)

proc canAttackFrom(self: Battle, unit: Unit, battlePos: Vec2i, pos: Vec2i): bool =
  if pos.x == battlePos.x or pos.y == battlePos.y:
    let d = manhattanDist(battlePos, pos)
    if d >= unit.attackMinDist and d <= unit.attackMaxDist:
      if not unit.attackIndirect:
        # check if there's a clear path
        if pos.x == battlePos.x:
          for y in countupordown(battlePos.y,pos.y):
            if self.occupied(unit, vec2i(pos.x, y), false):
              return false
        elif pos.y == battlePos.y:
          for x in countupordown(battlePos.x,pos.x):
            if self.occupied(unit, vec2i(x, pos.y), false):
              return false
      return true
  return false

proc drawBattle(self: Battle) =
  let cx = screenWidth div 2 - width * 8
  let cy = screenHeight div 2 - height * 8

  var (mx,my) = mouse()
  mx -= cx
  my -= cy
  let mtx = mx div 16
  let mty = my div 16
  let mpos = vec2i(mtx,mty)

  # draw terrain
  setSpritesheet(3)
  for y in 0..<height:
    for x in 0..<width:
      spr(map[y * width + x], cx + x * 16, cy + y * 16)


  if moves.len == 0 and selectedUnit != nil and selectedUnitMoves.hasKey(mpos) and mpos != selectedUnit.battlePos and selectedUnit.battleMoves > 0:
    # draw path to tile under mouse
    var distprev = selectedUnitMoves[mpos]
    var pos = mpos
    if distprev[0] < 999:
      if distprev[0] > selectedUnit.moveDist:
        setColor(27)
      else:
        setColor(21)
      while distprev[1][0]:
        let prev = distprev[1][1]
        let dir = pos - prev

        let steps = self.cost(prev, pos, selectedUnit, false)
        for i in 0..<steps:
          let p = lerp(vec2f(cx + pos.x * 16 + 8, cy + pos.y * 16 + 8), vec2f(cx + prev.x * 16 + 8, cy + prev.y * 16 + 8), i.float32 / steps.float32)
          circ(p.x, p.y, 1)
        distprev = selectedUnitMoves[prev]
        pos = prev

  setSpritesheet(0)
  for trap in knownTraps:
    spr(26, cx + trap.x * 16 + 8 - 4, cy + trap.y * 16 + 8 - 4)

  # draw units
  for u in units:
    u.draw(cx + u.battlePos.x * 16 + 8 - 4, cy + u.battlePos.y * 16 + 8 - 4)
    if u.team == 1 and turnPhase == phaseTurn:
      if u.battleMoves > 0:
        setColor(8)
        circfill(u.pos.x + 1, u.pos.y + 8, 1)
      if u.battleAttacks > 0:
        setColor(27)
        circfill(u.pos.x + 7, u.pos.y + 8, 1)

  if hoverUnit != nil and hoverUnit.team != 1:
    let moves = calculatePossibleMoveAttacks(hoverUnit, false)
    # show enemy unit's possible moves
    setColor(27)
    if frame mod 60 < 30: ditherPatternCheckerboard() else: ditherPatternCheckerboard2()
    for move in moves:
      let x = move[0].x
      let y = move[0].y
      if move[1]:
        circ(cx + x * 16 + 8, cy + y * 16 + 8, 3)
      else:
        rrect(cx + x * 16 + 2, cy + y * 16 + 2, cx + x * 16 + 13, cy + y * 16 + 13)
    ditherPattern()

  if unitsToDeploy.len > 0:
    if frame mod 60 < 30: ditherPatternCheckerboard() else: ditherPatternCheckerboard2()
    setColor(21)
    for y in (height div 4 * 3)..<height:
      for x in 0..<width:
        if not occupied(unitsToDeploy[unitsToDeploy.high], vec2i(x,y), true):
          rrect(cx + x * 16 + 1, cy + y * 16 + 1, cx + x * 16 + 14, cy + y * 16 + 14)
    ditherPattern()

  if moves.len > 0:
    return

  setSpritesheet(3)
  if selectedUnit != nil:
    if selectedUnit.battleMoves > 0:
      # draw possible moves
      for y in 0..<height:
        for x in 0..<width:
          let pos = vec2i(x,y)
          #if pos == selectedUnit.battlePos:
          #  continue
          let distprev = selectedUnitMoves[pos]
          let dist = distprev[0]
          let prev = distprev[1][1]
          if dist <= selectedUnit.moveDist:
            ditherPatternBigCheckerboard()
            #rrect(cx + x * 16 + 1, cy + y * 16 + 1, cx + x * 16 + 15 - 2, cy + y * 16 + 15 - 2)
            # analyse the tile and determine which spr to show
            var edges = 0
            if pos.x == 0 or selectedUnitMoves[pos + vec2i(-1,0)][0] > selectedUnit.moveDist:
              edges = edges or 1
            if pos.x == width - 1 or selectedUnitMoves[pos + vec2i(1,0)][0] > selectedUnit.moveDist:
              edges = edges or 2
            if pos.y == 0 or selectedUnitMoves[pos + vec2i(0,-1)][0] > selectedUnit.moveDist:
              edges = edges or 4
            if pos.y == height - 1 or selectedUnitMoves[pos + vec2i(0,1)][0] > selectedUnit.moveDist:
              edges = edges or 8

            if edges > 0:
              spr(47+edges, cx + pos.x * 16, cy + pos.y * 16)
            ditherPattern()

            if isTrap(selectedUnit, pos, false):
              setSpritesheet(0)
              spr(26, cx + pos.x * 16 + 8 - 4, cy + pos.y * 16 + 8 - 4)
              setSpritesheet(3)

    if selectedUnit.battleAttacks > 0:
      # draw possible attacks
      setColor(27)
      for u in units:
        if u.team != selectedUnit.team and u.isVisible(selectedUnit.team):
          if selectedUnit.canAttack(u.battlePos):
            if frame mod 60 < 30: ditherPatternCheckerboard() else: ditherPatternCheckerboard2()
            let x = u.battlePos.x
            let y = u.battlePos.y
            rrect(cx + x * 16, cy + y * 16, cx + x * 16 + 15, cy + y * 16 + 15)
            ditherPattern()


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
  if hintSite == self and selectedSite != self and frame mod 60 < 30:
    setColor(8)
    rrect(x-3, y-3, x + 48 + 3, y + 48 + 3)

  setColor(if self.disabled > 0: 27 elif self.blocked > 0: 0 elif self.used or available == false: 15 elif (inputMode != SelectUnit): 8 else: 15)
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

  if inputMode == SelectUnit:
    let dx = abs(pos.x - selectedSite.pos.x)
    let dy = abs(pos.y - selectedSite.pos.y)
    let dd = max(dx,dy)
    if dd <= selectUnitMaxRadius and dd >= selectUnitMinRadius:
      setColor(21)
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
  if unit.site == nil or nActions > unit.site.town.actions:
    return false
  if nSouls > unit.souls:
    return false
  if unit.site == nil or nFollowers > unit.site.getFollowerCount:
    return false
  if unit.site == nil or nRebels > unit.site.getRebelCount:
    return false
  if unit.site == nil or nSick > unit.site.getSickCount:
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

proc draw(self: ShamanAbility, sx, sy, w, h: int, enabled: bool, unit: Unit, index: int) =
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

  let site = unit.site

  if site == nil:
    return

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

  if unit.usedAbility:
    pal(1,27)
  spr(24, x, y)
  pal()
  x += 7

  j = 0
  for i in 0..<nSouls:
    if i >= unit.souls:
      pal(1,27)
    spr(7, x, y)
    x += 7
    j += 1
    if j == 5:
      x += 3
      j = 0
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

method draw(self: DestinyCardSettings, c: Card, pos: Vec2f) =
  let passed = currentDestiny == c and checkDemand(c, homeTown)

  G.center = false

  if omen:
    G.normalColor = 27
  else:
    G.normalColor = ageColors[age-1]

  G.beginArea(pos.x, pos.y, cardWidth, cardHeight, gTopToBottom, true)

  #setSpritesheet(0)
  #var x = pos.x + cardWidth div 2 - age * 8
  #for i in 0..<age:
  #  G.ssprite(56, x, pos.y.int + 40 - 8, 16, 16, 2, 2)
  #  x += 16

  if event != "":
    G.textColor = 21
    setFont(1)
    G.label(event)
    setFont(0)
    G.textColor = 22

  if demand != "":
    setFont(1)
    G.textColor = if passed: 18 else: 27
    G.label("Demand")
    G.textColor = 22
    setFont(0)
    if passed:
      G.textColor = 18
      G.label(demand)
      G.textColor = 22
    else:
      if currentDestiny == c and hoveringOverEndTurn and frame mod flashMod < flashCmp:
        G.label("<21>" & demand)
      else:
        G.label("<27>" & demand)
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
  G.beginArea(pos.x, pos.y, cardWidth, cardHeight, gTopToBottom, true)

  setSpritesheet(0)
  var x = pos.x + cardWidth div 2 - age * 8
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
        site.pos = vec2i(x,y)
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
      elif site.settings == siteSerpent:
        site.settings = siteSerpent2
      elif site.settings == siteSerpent2:
        site.settings = siteSerpent3
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
      if ds.age == age and ds.omen == false and (guideMode == false or ds.tutorial):
        for i in 0..<ds.count:
          ageDeck.add(newCard(ds))

  if ageDeck.len > 0:
    ageDeck.shuffle()
    ageDeck.shuffle()
    ageDeck.shuffle()

    for i in 0..<ageCardCount[age-1]:
      destinyPile.add(ageDeck.drawCard())

  for c in destinyDiscardPile:
    destinyPile.add(c)

  destinyDiscardPile.clear()

  if destinyPile.len > 0:
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
        u.usedAbility = false
      for ab in site.settings.abilities:
        if ab.startOfTurn:
          if ab.check(site):
            ab.action(site)

  for battle in battles:
    battle.knownTraps = @[]
    battle.teamTurn = 1
    for u in battle.units:
      u.battleMoves = u.battleMovesInit
      u.battleAttacks = u.battleAttacksInit
      u.revealed = false

    var playerUnits = 0
    var enemyUnits = 0

    for u in battle.units:
      u.battleMoves = u.battleMovesInit
      u.battleAttacks = u.battleAttacksInit
      u.revealed = false

      if u.team == 1:
        playerUnits += 1
      else:
        enemyUnits += 1

    if playerUnits > 0 and enemyUnits == 0:
      battle.victor = 1
      battle.completed = true
    elif playerUnits == 0 and enemyUnits > 0:
      battle.victor = 2
      battle.completed = true

  if currentDestiny != nil:
    # apply old destiny and discard
    let ds = currentDestiny.settings.DestinyCardSettings
    if ds.onStartNextTurn != nil:
      for town in towns:
        if town.team == 1:
          ds.onStartNextTurn(currentDestiny, town)
    var c = currentDestiny
    moveCard(c, vec2f(screenWidth div 2 - cardWidth div 2, screenHeight - cardHeight - 20), 0) do(cm: CardMove):
      moveCard(cm.c, destinyDiscardPile.pos.vec2f, 1.0) do(cm: CardMove):
        destinyDiscardPile.add(cm.c)
        currentDestiny = nil
        # draw one destiny card

        for town in towns:
          town.serpentSacrificesMade = 0
          town.nHealed = 0
          town.nRebelsKilled = 0
          town.startingActions = town.actions


        var c = destinyPile.drawCard()
        if c == nil:
          # pile empty, next age and, shuffle it
          age += 1
          if age > 3:
            age = 3
          fillDestiny()

          c = destinyPile.drawCard()

        if destinyPile.len == 0:
          # pile empty, next age and, shuffle it
          age += 1
          if age > 3:
            age = 3
          fillDestiny()

        if c != nil:
          moveCard(c, vec2f(screenWidth div 2 - cardWidth div 2, screenHeight - cardHeight - 20), 0) do(cm: CardMove):
            moveCard(cm.c, vec2f(screenWidth div 4 + 10, screenHeight - cardHeight - 2), 1.0) do(cm: CardMove):
              currentDestiny = cm.c
              let ds = currentDestiny.settings.DestinyCardSettings
              if ds.onStartTurn != nil:
                for town in towns:
                  if town.team == 1:
                    ds.onStartTurn(currentDestiny, town)

  if currentDestiny == nil:
    # draw one destiny card
    var c = destinyPile.drawCard()
    if c == nil:
      age += 1
      if age > 3:
        age = 3
      fillDestiny()

      c = destinyPile.drawCard()

    if c != nil:
      moveCard(c, vec2f(screenWidth div 4 + 10, screenHeight - cardHeight - 2), 0) do(cm: CardMove):
        currentDestiny = c
        let ds = currentDestiny.settings.DestinyCardSettings
        if ds.onStartTurn != nil:
          for town in towns:
            if town.team == 1:
              ds.onStartTurn(currentDestiny, town)



proc endTurn() =

  if inputMode == Relocate:
    endRelocate()

  turnPhase = phaseEndOfTurn

  battlesWaging = true
  selectedUnit = nil
  selectedSite = nil

  undoStack = @[]

  for battle in battles:
    battle.knownTraps = @[]
    battle.teamTurn = 2

    var playerUnits = 0
    var enemyUnits = 0

    for u in battle.units:
      u.battleMoves = u.battleMovesInit
      u.battleAttacks = u.battleAttacksInit
      u.revealed = false

      if u.team == 1:
        playerUnits += 1
      else:
        enemyUnits += 1

    if playerUnits > 0 and enemyUnits == 0:
      battle.victor = 1
      battle.completed = true
    elif playerUnits == 0 and enemyUnits > 0:
      battle.victor = 2
      battle.completed = true

    if turn mod 2 == 0:
      for y in 0..<battle.height:
        for x in 0..<battle.width:
          if battle.mget(vec2i(x,y)) == 9:
            var blocked = false
            for u in battle.units:
              if u.battlePos == vec2i(x,y):
                blocked = true
                break
            if not blocked:
              var u = newUnit(Soldier,nil)
              u.team = 2
              u.battlePos = vec2i(x,y)
              battle.units.add(u)


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
    if ds.rebelsMove:
      for town in towns:
        for site in town.sites:
          var rebels: seq[Unit] = @[]
          for u in site.units:
            if u.kind == Rebel:
              rebels.add(u)
          for u in rebels:
            u.move(town.randomSite())

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
      mainMenu = true
    return

  if homeTotem.settings != siteSerpent and homeTotem.settings != siteSerpent2 and homeTotem.settings != siteSerpent3:
    dialogYesNo("Your cult has been destroyed") do:
      mainMenu = true
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
          discard site.removeFollower()

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

proc newBattle(x,y: int, w,h: int): Battle =
  result = new(Battle)
  result.pos = vec2i(x,y)
  result.age = 0
  result.width = w
  result.height = h
  result.moves = @[]
  result.map = newSeq[int](result.width * result.height)

  var dirtAmount = rnd(5,10)
  var forestAmount = rnd(4,10)
  var rockAmount = rnd(0,3)
  var waterAmount = rnd(0,2)
  var clearingAmount = rnd(0,5)

  var deck = newSeq[int]()
  for i in 0..<dirtAmount:
    deck.add(1)
  for i in 0..<forestAmount:
    deck.add(3)
  for i in 0..<rockAmount:
    deck.add(2)
  for i in 0..<waterAmount:
    deck.add(4)
  for i in 0..<clearingAmount:
    deck.add(5)

  for y in 0..<result.height:
    for x in 0..<result.width:
      let pos = vec2i(x,y)
      result.mset(pos,rnd(deck))
      if (y == 0 or y == result.height-1) and result.mget(pos) == 4:
        result.mset(pos,1)
  result.map[(1 + rnd(3)) * result.width + (result.width div 2 - rndbi(3))] = 9

  result.units = @[]
  result.unitsToDeploy = @[]

  # place friendlies
  for i in 0..<result.width:
    var u = newUnit(if i == result.width div 2: Shaman else: rnd([Soldier,Soldier,Soldier,Cavalry]), nil)
    u.battlePos = vec2i(i,result.height-1)
    u.team = 1
    result.units.add(u)
    #result.unitsToDeploy.add(u)

  #for i in 0..<result.width div 2:
  #  var u = newUnit(Follower, nil)
  #  u.team = 1
  #  result.unitsToDeploy.add(u)

  # place enemies
  for i in 0..<result.width:
    for y in 0..0:
      var u = newUnit(rnd([Soldier,Soldier,Soldier,Cavalry,Shaman]), nil)
      u.battlePos = vec2i(i,y)
      u.team = 2
      result.units.add(u)

  result.revealHidden()

proc newSite(town: Town, siteSettings: SiteSettings, x, y: int): Site {.discardable.} =
  var site = new(Site)
  site.settings = siteSettings
  site.town = town
  site.used = false
  site.units = @[]
  town.sites[town.width * y + x] = site
  site.pos = vec2i(x,y)
  return site

proc gameInit() =
  loadSpritesheet(0, "spritesheet.png", 8, 8)
  loadSpritesheet(1, "tileset.png", 32, 32)
  loadSpritesheet(2, "tilesetWorld.png", 8, 8)
  loadSpritesheet(3, "tilesetBattle.png", 16,16)
  loadMap(0, "map.json")
  setMap(0)

proc newGame() =
  srand()

  currentDestiny = nil

  turnPhase = phaseTurn


  battles = @[]

  currentBattle = newBattle(2,2,8,8)

  battles.add(currentBattle)

  age = 0
  particles = @[]
  towns = @[]
  armies = @[]
  destinyPile = newPile("Destiny", pkAllFaceDown)
  destinyPile.pos = vec2i(2, screenHeight - cardHeight - 2)
  destinyDiscardPile = newPile("Destiny Discard", pkHidden)
  destinyDiscardPile.pos = vec2i(screenWidth div 4 + 5, screenHeight + 10)
  cardHand = newPile("Hand", pkAllFaceOpen)
  cardHand.pos = vec2i(2,3)

  turn = 0
  time = 0.0
  frame = 0

  loadMap(0, "map.json")

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
          var townHouse = newSite(town, siteHome, 0, 1)
          for i in 0..<2:
            townHouse.units.add(newUnit(Follower, townHouse))
          currentTown = town
          currentTown.isHometown = true
          homeTown = currentTown
          currentTown.actions = 3
          currentTown.startingActions = currentTown.actions

        for i,site in town.sites.mpairs:
          if site == nil:
            if town == currentTown:
              site = newSite(town, siteEmpty, i mod town.width, i div town.width)
            else:
              site = newSite(town, siteHovel, i mod town.width, i div town.width)

        towns.add(town)

  startTurn()

proc save(self: Unit, f: FileStream) =
  f.write(kind.uint8)
  f.write(hp.uint8)
  f.write(team.uint8)
  f.write(age.uint8)
  f.write(souls.uint8)
  f.write(abilities.len.uint8)
  for a in abilities:
    for i,ai in shamanAbilities:
      if ai == a:
        f.write(i.uint8)

proc loadUnit(f: FileStream): Unit =
  result = new(Unit)
  result.kind = f.readUint8().UnitKind
  result.hp = f.readUint8().int
  result.team = f.readUint8().int
  result.age = f.readUint8().int
  result.souls = f.readUint8().int
  let nAbilities = f.readUint8().int
  for i in 0..<nAbilities:
    let abilityId = f.readUint8().int
    result.abilities.add(shamanAbilities[abilityId])

proc save(self: Site, f: FileStream) =
  f.write(settings.name.len.uint8)
  f.write(settings.name)
  f.write(used.uint8)
  f.write(blocked.uint8)
  f.write(disabled.uint8)
  f.write(units.len.uint8)
  for unit in units:
    unit.save(f)

proc loadSite(f: FileStream): Site =
  result = new(Site)
  result.units = @[]
  var nameLen = f.readUint8()
  var name = f.readStr(nameLen.int)
  for s in siteSettings:
    if s.name == name:
      result.settings = s
      break
  if result.settings == nil:
    echo "error finding settings: ", name
  result.used = f.readUint8().bool
  result.blocked = f.readUint8().int
  result.disabled = f.readUint8().int
  var nUnits = f.readUint8().int
  for i in 0..<nUnits:
    var unit = f.loadUnit()
    unit.site = result
    result.units.add(unit)

proc save(self: Town, f: FileStream) =
  f.write(name.len.uint8)
  f.write(name)
  f.write(size.uint8)
  f.write(pos.x.uint8)
  f.write(pos.y.uint8)
  f.write(team.uint8)
  f.write(width.uint8)
  f.write(height.uint8)
  f.write(actions.uint8)
  f.write(rebellion.uint8)
  f.write(isHometown.uint8)
  f.write(sites.len.uint8)
  for site in sites:
    site.save(f)

proc save(self: Card, f: FileStream) =
  # look up index of card in destinySettings
  let ds = settings.DestinyCardSettings
  for i,s in destinySettings:
    if s == ds:
      f.write(i.uint16)
      break
  for i,s in destinyOmens:
    if s == ds:
      f.write((1000 + i).uint16)
      break

proc loadCard(f: FileStream): Card =
  # look up index of card in destinySettings
  result = new(Card)
  let cardIndex = f.readUint16().int
  if cardIndex < 1000:
    result.settings = destinySettings[cardIndex]
  else:
    result.settings = destinyOmens[cardIndex-1000]

proc loadTown(f: FileStream): Town =
  result = new(Town)
  result.sites = @[]
  var nameLen = f.readUint8().int
  result.name = f.readStr(nameLen)
  result.size = f.readUint8().int
  result.pos.x = f.readUint8().int
  result.pos.y = f.readUint8().int
  result.team = f.readUint8().int
  result.width = f.readUint8().int
  result.height = f.readUint8().int
  result.actions = f.readUint8().int
  result.rebellion = f.readUint8().int
  result.isHometown = f.readUint8().bool
  var nSites = f.readUint8().int
  for i in 0..<nSites:
    var site = f.loadSite()
    site.town = result
    result.sites.add(site)

proc saveGame() =
  let saveFile = joinPath(writePath,"save")
  let saveFileTmp = joinPath(writePath,"save.tmp")
  let saveFileOld = joinPath(writePath,"save.old")

  var f = openFileStream(saveFileTmp, fmWrite)
  f.write("SerpentsSave")
  # globals
  f.write(age.uint8)
  f.write(turn.uint16)
  f.write(guideMode.uint8)
  f.write(guideStep.uint8)
  # save the state of the destinyPile
  f.write(destinyPile.len.uint16)
  for c in destinyPile:
    c.save(f)
  # save the discardPile
  f.write(destinyDiscardPile.len.uint16)
  for c in destinyDiscardPile:
    c.save(f)
  # save currentDestiny
  currentDestiny.save(f)
  # go through each town and save it
  f.write(towns.len.uint8)
  for town in towns:
    town.save(f)
  f.close()

  if fileExists(saveFileOld):
    removeFile(saveFileOld)
  if fileExists(saveFile):
    moveFile(saveFile,saveFileOld)
  moveFile(saveFileTmp, saveFile)
  removeFile(saveFileOld)
  echo "saved game"

proc loadGame(): bool =
  var f: FileStream
  try:
    f = openFileStream(joinPath(writePath,"save"), fmRead)
  except IOError:
    return false

  defer: f.close()

  var magic = f.readStr("SerpentsSave".len)
  if magic != "SerpentsSave":
    echo "This is not a SerpentsSave game"
    return false
  # globals
  age = f.readUint8().int
  turn = f.readUint16().int
  guideMode = f.readUint8().bool
  guideStep = f.readUint8().int
  # load cards
  clearCardMoves()

  destinyPile = newPile("Destiny", pkAllFaceDown)
  destinyPile.pos = vec2i(2, screenHeight - cardHeight - 2)

  let nDestiny = f.readUint16().int
  for i in 0..<nDestiny:
    let c = f.loadCard()
    destinyPile.add(c)

  destinyDiscardPile = newPile("Destiny Discard", pkHidden)
  destinyDiscardPile.pos = vec2i(screenWidth div 4 + 5, screenHeight + 10)

  let nDestinyDiscard = f.readUint16().int
  for i in 0..<nDestinyDiscard:
    let c = f.loadCard()
    destinyDiscardPile.add(c)
  currentDestiny = f.loadCard()
  currentDestiny.pos = vec2f(screenWidth div 4 + 10, screenHeight - cardHeight - 2)
  # go through each town and load it
  var nTowns = f.readUint8().int
  towns = @[]
  homeTown = nil
  homeTotem = nil
  for i in 0..<nTowns:
    var town = f.loadTown()
    towns.add(town)
    if town.isHometown:
      currentTown = town
      homeTown = town
      for site in town.sites:
        if site.settings == siteSerpent or site.settings == siteSerpent2 or site.settings == siteSerpent3:
          homeTotem = site
  if homeTown == nil or homeTotem == nil:
    echo "couldn't find hometown or totem"
    return false
  return true

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
  selectedUnit = nil
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
  for army in armies:
    for u in army.units:
      if u.site != u.sourceSite:
        unitsMoved += 1

  return unitsMoved != 0

proc endRelocate() =
  inputMode = SelectSite

  if not hasMovedUnits():
    currentTown.actions += 1

  for site in currentTown.sites:
    site.units.sort() do(a,b: Unit) -> int:
      return b.kind.int - a.kind.int

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

proc mainMenuGui() =
  G.hintOnly = false
  G.normalColor = 15
  G.beginArea(screenWidth div 2 - 150, screenHeight div 2 - 100, 300, 200, gTopToBottom, true, true)
  G.hExpand = true
  G.center = true

  if optionsMenu:
    setFont(1)
    G.label("<21>Options</>")
    setFont(0)
    G.empty(5,5)
    if G.button("Focus Follows Mouse = " & (if focusFollowsMouse: "On" else: "Off")):
      focusFollowsMouse = not focusFollowsMouse
      updateConfigValue("General","focusFollowsMouse", $focusFollowsMouse)
      saveConfig()
    G.empty(5,5)
    if G.button("Back"):
      optionsMenu = false

  else:
    setFont(1)
    G.label("<21>Serpent's Souls</>")
    setFont(0)
    G.label("A game by <8>Impbox</> for <27>LD43</>")
    G.empty(5,5)

    if not gameStarted:
      if G.button("Start Game"):
        gameStarted = true
        mainMenu = false
        newGame()

      if G.button("Tutorial"):
        gameStarted = true
        mainMenu = false
        guideMode = true
        newGame()

      if G.button("Continue", saveExists):
        if loadGame():
          gameStarted = true
          mainMenu = false

    else:
      if G.button("Continue", saveExists):
        mainMenu = false

      G.empty(5,5)
      if G.button("End Game"):
        gameStarted = false

    G.empty(5,5)
    if G.button("Options"):
      optionsMenu = true
    G.empty(5,5)
    if G.button("Quit"):
      shutdown()

  G.center = false
  G.hExpand = false
  G.endArea()

proc gameGuiBattle(self: Battle) =
  # bottom bar
  G.beginArea(0, screenHeight - 31, screenWidth, 28, gRightoLeft)
  G.center = true

  if turnPhase == phaseTurn:
    if G.button("<21>E</>nd Turn", 100, 28, true, K_E):
      tryEndTurn()
    if G.hoverElement == G.element or G.downElement == G.element:
      hoveringOverEndTurn = true
    else:
      G.empty(100, 28)
  else:
    discard G.button(100, 28, false, K_UNKNOWN) do(x,y,w,h: int, enabled: bool):
      pal(29,0)
      spr(48 + ((frame div 5).int mod 4) * 2, x + w div 2 - 8, y, 2, 2)
      pal()
    discard G.button($turnPhase, 148, 28, false)

  G.endArea()

  # battle info
  G.beginArea(screenWidth div 4 + 4, 3, screenWidth div 2 - 8, 50, gTopToBottom, true)
  G.center = false
  G.vSpacing = 2
  G.vPadding = 0
  G.textColor = 18
  setFont(1)
  if completed:
    if victor == 1:
      G.textColor = teamColors[1]
      G.label("Victory")
    else:
      G.textColor = teamColors[2]
      G.label("Defeated")
  else:
    G.textColor = teamColors[0]
    G.label("Battle")
  setFont(0)
  G.textColor = 22
  G.label("Day " & $turn)
  G.endArea()



proc gameGuiTown(self: Town) =
  # right bar
  G.beginArea(screenWidth - 160, 3, 160 - 3, screenHeight - 36, gTopToBottom, true)
  G.center = true
  G.hExpand = true

  hoveringOverAbility = false

  if inputMode == ChooseAbilityToLearn:
    var shaman = selectedUnit
    G.label("Choose Skill to Learn")
    G.label("<spr(7,6,8)>".repeat(shaman.souls))
    G.center = false
    var i = 0
    for a in shamanAbilities:
      if a in shaman.abilities:
        continue
      if not a.requires.allIt(it in shaman.abilities):
        continue
      let keycode = (K_1.int + i).Keycode
      if G.button("<21>" & $(i+1) & "</> " & a.name & "\n" & "<spr(7,6,8)>".repeat(a.nSoulsToUnlock), shaman.souls >= a.nSoulsToUnlock, keycode):
        inputMode = SelectSite
        shaman.site.town.actions -= a.nActions
        shaman.souls -= a.nSoulsToUnlock
        shaman.abilities.add(a)
      i += 1

    G.empty(10,10)
    if G.button("<21>C</>ancel", true, K_C):
      inputMode = SelectSite

  elif inputMode == SelectSiteToBuild:
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
          discard selectedSite.killFollower()

    G.empty(10,10)
    if G.button("<21>C</>ancel", true, K_C):
      inputMode = SelectSite
      selectedSite.used = false

  elif selectedUnit != nil:
    G.label("Shaman")
    if selectedUnit.usedAbility:
      G.label("<spr(25)>")
    else:
      G.label("<spr(24)>")

    G.label("<spr(7,6,8)>".repeat(selectedUnit.souls))
    G.center = false
    var i = 0
    for a in selectedUnit.abilities:
      let keycode = (K_1.int + i).Keycode
      let ret = G.button(148, 50, placingUnits.len == 0 and a.check(selectedUnit), keycode) do(x,y,w,h: int, enabled: bool):
        a.draw(x,y,w,h,enabled,selectedUnit, i)
      if ret:
        saveUndo()
        a.action(selectedUnit, selectedSite)
        if not a.multiUse:
          selectedUnit.usedAbility = true
      if G.hoverElement == G.element or G.downElement == G.element:
        hoveringOverAbility = true
      i += 1
    if i < 5:
      if G.button("Learn new <21>S</>kill", 148, 50, true, K_S):
        inputMode = ChooseAbilityToLearn

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

    if currentArmy != nil:
      if inputMode == SelectSite:
        if G.button("<21>R</>elocate Army", 148, 28, currentArmy.moved == false, K_R):
          inputMode = MoveArmy
      elif inputMode == MoveArmy:
        if G.button("Cancel <21>R</>elocation", 148, 28, true, K_R):
          inputMode = SelectSite

    if currentTown != nil:
      if inputMode == Relocate:
        if hoveringOverAbility:
          G.buttonBackgroundColor = 27
        if G.button(if (hoveringOverAbility or hoveringOverEndTurn): "<21>This will end your relocation</>" elif not hasMovedUnits(): "Cancel <21>R</>elocation" else: "End <21>R</>elocation", 148, 28, placingUnits.len == 0, K_R):
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

  if guideMode and guideStep < guide.len:
    G.hintOnly = true
    let gs = guide[guideStep]
    G.center = false
    G.backgroundColor = 31
    G.textColor = 22
    G.normalColor = 22
    G.beginArea(screenWidth div 4 + 4, 56, screenWidth div 2 - 8, 50, gTopToBottom, true)
    G.labelStep(gs.text, guideStepTextStep)
    if mainMenu == false and (frame mod 3 == 0 or mousebtn(0)):
      guideStepTextStep += 1
    if guideStepTextStep >= gs.text.richPrintCount:
      if gs.clickNext:
        G.hintHotkey = K_X
        G.hintOnly = true
        if G.button("Ne<21>x</>t", true, K_X):
          guideStep += 1
          guideStepTextStep = 0
          G.hintHotkey = K_UNKNOWN
    G.endArea()


    if gs.check != nil and gs.check():
      guideStep += 1
      guideStepTextStep = 0
      G.hintHotkey = K_UNKNOWN
  else:
    G.hintHotkey = K_UNKNOWN
    G.hintOnly = false
    hintSite = nil
    guideMode = false

  G.normalColor = 15
  G.backgroundColor = 1
  G.textColor = 22


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
    G.label("Age " & $age & "  Day " & $turn)
    G.endArea()

    var shamanActions = 0
    for site in currentTown.sites:
      for u in site.units:
        if u.kind == Shaman:
          if u.usedAbility == false:
            shamanActions += 1

    if (actionFlash > 0 or (hoveringOverEndTurn and (currentTown.actions > 0 or shamanActions > 0))) and frame mod flashMod < flashCmp:
      pal(1,21)
      actionFlash -= 1
    var actionsStr = "Actions: "
    for i in 0..<currentTown.actions:
      actionsStr &= "<spr(8)>"
    for i in currentTown.actions..<currentTown.startingActions:
      actionsStr &= "<spr(9)>"
    var nShamanActions = 0
    actionsStr &= " "
    for site in currentTown.sites:
      for u in site.units:
        if u.kind == Shaman:
          if u.usedAbility == false:
            actionsStr &= "<spr(24)>"
          else:
            actionsStr &= "<spr(25)>"
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


proc gameGui() =
  G.normalColor = 15
  G.buttonBackgroundColor = 31
  G.buttonBackgroundColorDisabled = 1
  G.hoverColor = 22
  G.activeColor = 21
  G.textColor = 22
  G.hintColor = 8
  G.downColor = 15
  G.disabledColor = 25
  G.backgroundColor = 1
  G.hSpacing = 3
  G.vSpacing = 3
  G.hPadding = 4
  G.vPadding = 4

  if mainMenu and not gameStarted:
    mainMenuGui()
    return

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

  if currentBattle != nil:
    gameGuiBattle(currentBattle)
  elif currentTown != nil:
    gameGuiTown(currentTown)

  G.hSpacing = 3
  G.vSpacing = 3
  G.hPadding = 4
  G.vPadding = 4

  # draw cards and piles

  destinyPile.pos = vec2i(2, screenHeight - cardHeight - 2)
  destinyPile.draw()
  destinyDiscardPile.pos = vec2i(screenWidth div 4 + 5, screenHeight + 10)
  destinyDiscardPile.draw()

  if currentDestiny != nil and currentTown != nil:
    currentDestiny.draw()

  if cardHand.len > 0:
    for c in cardHand:
      c.draw()

  drawCards()

  if mainMenu:
    mainMenuGui()

proc townUpdate(self: Town, dt: float32) =
  if mousebtnp(2):
    undo()
    return

  var lastHoverUnit = hoverUnit
  var lastHoverSite = hoverSite
  hoverUnit = nil
  hoverSite = nil
  var (mx,my) = mouse()

  for site in sites:
    for u in site.units:
      if u.hp <= 0:
        newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)

  for i, site in sites:
    if site != nil:
      if hintSite == nil or hintSite == site:
        let cx = screenWidth div 2 - width * 25
        let cy = screenHeight div 2 - height * 25

        let x = i mod width
        let y = i div width

        if mx >= cx + x * 50 and my >= cy + y * 50 and mx <= cx + x * 50 + 48 and my <= cy + y * 50 + 48:
          hoverSite = site
          if focusFollowsMouse:
            if hintSite == nil or hintSite == hoverSite:
              selectedSite = hoverSite
        for u in site.units:
          if mx >= u.pos.x - 1 and mx <= u.pos.x + 7 and my >= u.pos.y - 1 and my <= u.pos.y + 7:
            hoverUnit = u
            hoverChangeTime = time
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

  if inputMode == SelectSite:
    if doubleClick:
      if hoverUnit != nil:
        if actions >= 1:
          startRelocate()
          if hoverUnit.kind != Rebel:
            grabUnit(hoverUnit)
        return
    elif mousebtnp(0):
      selectedSite = hoverSite
      if hoverUnit != nil and hoverUnit.kind == Shaman:
        selectedUnit = hoverUnit

  if inputMode == Relocate or inputMode == PlaceUnit:
    if inputMode == Relocate and placingUnits.len == 0 and doubleClick and hoverUnit == nil:
      endRelocate()

    if mousebtnp(0):
      if hoverSite != nil:
        if hintSite == nil or hintSite == hoverSite:
          selectedSite = hoverSite
      if hoverUnit != nil or placingUnits.len == 0 and inputMode == Relocate:
        pulling = true
      else:
        pulling = false

    if mousebtnpr(0,15):
      if pulling and inputMode == Relocate:
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

proc mget(self: Battle, pos: Vec2i): int =
  if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
    return 0
  return map[pos.y * width + pos.x]

proc mset(self: Battle, pos: Vec2i, t: int) =
  if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
    return
  map[pos.y * width + pos.x] = t

proc move(self: Battle, unit: Unit, dest: Vec2i, moveType: BattleMoveType, delay: float32, onComplete: proc(unit: Unit) = nil) =
  if manhattanDist(unit.battlePos, dest) == 1:
    moves.add(BattleMove(unit: unit, path: @[dest], moveType: moveType, onComplete: onComplete))
  else:
    let pathinfo = self.dijkstra(unit.battlePos, unit.moveDist, unit, false)
    var path: seq[Vec2i]
    var pos = dest
    path.add(pos)
    var distprev = pathinfo[pos]
    while distprev[1][0]:
      let prev = distprev[1][1]
      distprev = pathinfo[prev]
      pos = prev
      path.add(pos)
    discard path.pop()
    path.reverse()
    if path.len == 0:
      echo "can't find path from ", unit.battlePos, " to ", dest, " type: ", unit.kind
    else:
      moves.add(BattleMove(unit: unit, path: path, moveType: moveType, onComplete: onComplete))

proc checkForTrap(self: Battle, unit: Unit) =
  if isTrap(unit, unit.battlePos, true):
    newParticleText(unit.pos, vec2f(0,-10), 1.0, "Trap!", 27, 27)
    if unit.team == teamTurn:
      knownTraps.add(unit.battlePos)
    unit.hp -= 1
    pauseTimer = max(pauseTimer, 2.0)

proc checkForAmbush(self: Battle, unit: Unit, fleeDir: Vec2i) =
  for u in units:
    if u.team != unit.team and u.battleAttacksInit > 0 and manhattanDist(u.battlePos, unit.battlePos) == 1:
      let unitDir = unit.battlePos - u.battlePos
      if unitDir != fleeDir:
        newParticleText(unit.pos, vec2f(0,-10), 1.0, "Ambushed!", 27, 27)
        unit.hp -= 1
        u.flash = 5
        pauseTimer = max(pauseTimer, 2.0)

proc attack(self: Battle, attacker, defender: Unit) =
  attacker.flash = 5
  var dir = defender.battlePos - attacker.battlePos
  let direct = not attacker.attackIndirect
  dir.x = clamp(dir.x, -1, 1)
  dir.y = clamp(dir.y, -1, 1)
  # check if area behind defender is free
  if not occupied(defender, defender.battlePos + dir, true) and self.mget(defender.battlePos + dir) != 2:
    # if it's free, push defender back
    let oldPos = defender.battlePos
    #newParticleText(defender.pos, vec2f(0,-10), 1.0, "Retreat!", 22, 22)
    if direct:
      move(attacker, oldPos, bmAttack, 0.0)
      move(defender, defender.battlePos + dir, bmRetreat, 0.0) do(unit: Unit):
        # check if defender stepped into an ambush
        self.checkForAmbush(defender, dir)
        # check if attacker stepped into a trap
        self.checkForTrap(attacker)
    else:
      newParticleDest(attacker.pos, defender.pos, 0.25, 0, 80, 82)
      move(defender, defender.battlePos + dir, bmRetreat, 0.25) do(unit: Unit):
        # check if defender stepped into an ambush
        self.checkForAmbush(defender, dir)
  else:
    if direct:
      move(attacker, defender.battlePos, bmAttack, 0) do(unit: Unit):
        newParticleText(defender.pos, vec2f(0,-10), 1.0, "Rout!", 27, 27)
        defender.hp -= 1
        pauseTimer = max(pauseTimer, 2.0)
    else:
      newParticleDest(attacker.pos, defender.pos, 0.25, 0, 80, 82)
      newParticleText(defender.pos, vec2f(0,-10), 1.0, "Rout!", 27, 27)
      defender.hp -= 1
      pauseTimer = max(pauseTimer, 1.0)

  attacker.battleAttacks -= 1
  if direct:
    attacker.battleMoves -= 1

proc battleUpdateCommon(self: Battle, dt: float32) =
  if pauseTimer > 0:
    pauseTimer -= dt
    return

  var moveCompleted = false
  var movesInProgress = moves.len > 0
  for move in moves.mitems:
    if move.path.len == 0:
      echo "0 length path! wtf"
      moves.delete(0)
    elif move.time <= 0:
      echo "start move ", (move.index+1), "/", move.path.len
      move.unit.revealed = false
      move.lastPos = move.unit.battlePos
      move.unit.battlePos = move.path[move.index]
      move.time = 0.1
    elif move.time > 0:
      # move in progress
      move.time -= dt
      if move.time <= 0:
        echo "move step completed ", (move.index+1), "/", move.path.len, " ", move.moveType, " team: ", move.unit.team
        # step completed
        checkIfHidden(move.unit)
        # check if we stepped into a hidden enemy, will never happen during attack? (could happen with direct attacks of more than one distance)
        if move.moveType != bmAttack:
          for u in units:
            if u.team != move.unit.team and u.battlePos == move.unit.battlePos:
              echo "surprised"
              newParticleText(move.unit.pos, vec2f(0,-10), 1.0, "Surprise!", 27, 27)
              move.unit.battleMoves = 0
              move.unit.battleAttacks = 0
              pauseTimer = max(pauseTimer, 1.0)
              move.index = move.path.high
              self.move(move.unit, move.lastPos, bmRetreat, 0.5)
              break
        if move.unit.hp > 0 and move.index < move.path.high:
          echo "next step"
          move.unit.revealed = false
          move.time = 0.1
          move.index += 1
          move.lastPos = move.unit.battlePos
          move.unit.battlePos = move.path[move.index]
          checkIfHidden(move.unit)
        else:
          echo "was last step"
          moveCompleted = true
          if move.onComplete != nil:
            move.onComplete(move.unit)
          if selectedUnit != nil:
            selectedUnitMoves = self.dijkstra(selectedUnit.battlePos, 99999, selectedUnit, false)
          pauseTimer = max(pauseTimer, 0.5)

          if move.unit.hp > 0:
            checkForTrap(move.unit)

          if move.unit.hp > 0:
            revealHidden()

          moves.delete(0)
    break

  for u in units:
    if u.hp <= 0:
      newParticle(u.pos, vec2f(0,0), 0.25, 0, 16, 19)
  units.keepItIf(it.hp > 0)

  for i in 0..<units.len:
    for j in i+1..<units.len:
      if units[i].battlePos == units[j].battlePos:
        echo "problem! two units on same space!", units[i].battlePos


proc battleUpdate(self: Battle, dt: float32) =
  battleUpdateCommon(dt)

  if moves.len > 0:
    return

  let cx = screenWidth div 2 - width * 8
  let cy = screenHeight div 2 - height * 8
  var (mx,my) = mouse()

  let tx = (mx - cx) div 16
  let ty = (my - cy) div 16

  let tpos = vec2i(tx,ty)

  if unitsToDeploy.len > 0:
    if mousebtnp(0):
        if not (tx < 0 or ty < 0 or tx >= width or ty >= height):
          if ty >= height div 4 * 3:
            for i,u in units:
              if u.battlePos == tpos:
                unitsToDeploy.add(u)
                units.delete(i)
                return
            var unit = unitsToDeploy.pop()
            unit.battlePos = tpos
            unit.battleMoves = 0
            unit.battleAttacks = 0
            units.add(unit)
            revealHidden()
            return

  let lastHoverUnit = hoverUnit
  hoverUnit = nil

  if selectedUnit notin units:
    selectedUnit = nil
  if hoverUnit notin units:
    hoverUnit = nil

  for u in units:
    if mx >= u.pos.x - 1 and mx <= u.pos.x + 7 and my >= u.pos.y - 1 and my <= u.pos.y + 7:
      if u.isVisible(1):
        hoverUnit = u
        if hoverUnit != lastHoverUnit:
          hoverChangeTime = time
        break

  if mousebtnp(0):
    if hoverUnit != nil and hoverUnit.team == 1:
      selectedUnit = hoverUnit
      selectedUnitMoves = self.dijkstra(selectedUnit.battlePos, 99999, selectedUnit, false)
    else:
      if selectedUnit != nil:
        # check if this is a movable area

        if tx < 0 or ty < 0 or tx >= width or ty >= height:
          selectedUnit = nil
          return

        for u in units:
          if u.battlePos == tpos and u.team == 1:
            selectedUnit = u
            selectedUnitMoves = self.dijkstra(selectedUnit.battlePos, 99999, selectedUnit, false)
            return

        var occupiedBy: Unit = nil
        for u in units:
          if u.battlePos == tpos and u.isVisible(selectedUnit.team):
            occupiedBy = u
            break

        if occupiedBy != nil and occupiedBy.team != 1 and selectedUnit.battleAttacks > 0:
          # enemy, attack if in range
          if selectedUnit.canAttack(occupiedBy.battlePos):
            attack(selectedUnit, occupiedBy)

        elif selectedUnit.battleMoves > 0:
          if selectedUnitMoves.hasKey(tpos):
            let distprev = selectedUnitMoves[tpos]
            let dist = distprev[0]
            let prev = distprev[1][1]
            if dist <= selectedUnit.moveDist:
              move(selectedUnit, tpos, bmMove, 0)
              selectedUnit.battleMoves -= 1
        else:
          selectedUnit = nil

proc manhattanDist(a, b: Vec2i): int =
  return abs(a.x - b.x) + abs(a.y - b.y)

proc calculatePossibleMoves(self: Battle, u: Unit, reality = true): seq[(Vec2i,bool)] =
  # get all possible moves
  var possibleMoves: seq[(Vec2i,bool)] = @[]
  let costs = self.dijkstra(u.battlePos, 99999, u)
  for y in 0..<height:
    for x in 0..<width:
      let pos = vec2i(x,y)
      let distprev = costs[pos]
      if distprev[0] <= u.moveDist:
        var occupied = false
        if not occupied(u, pos, reality):
          possibleMoves.add((pos,false))
  return possibleMoves

proc calculatePossibleMoveAttacks(self: Battle, u: Unit, reality = true): seq[(Vec2i,bool)] =
  # get all possible moves + attacks
  var moves = calculatePossibleMoves(u, reality)
  var attacks: seq[(Vec2i,bool)]
  for pos in self:
    for move in moves:
      if u.canAttackFrom(move[0], pos):
        if (pos,false) notin moves:
          attacks.add((pos,true))
  moves.add(attacks)
  return moves

proc occupied(self: Battle, unit: Unit, pos: Vec2i, reality = true): bool =
  if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
    return true
  if mget(pos) == 4:
    return true
  if unit.kind == Cavalry and mget(pos) == 2:
    return true
  for u in units:
    if u.battlePos == pos and u.hp > 0:
      if not reality and u.isVisible(unit.team) == false:
        continue
      return true
  return false

proc impassable(self: Battle, unit: Unit, pos: Vec2i, reality = true): bool =
  if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
    return true
  if mget(pos) == 4:
    return true
  if unit.kind == Cavalry and mget(pos) == 2:
    return true
  for u in units:
    if u.team != unit.team and u.battlePos == pos and u.hp > 0:
      if not reality and u.isVisible(unit.team) == false:
        continue
      return true
  return false

proc scorePosition(self: Battle, u: Unit, pos: Vec2i, target: Unit = nil): float32 =
  result = 0
  if self.isTrap(u, pos, false):
    return -100.0

  for trap in knownTraps:
    if trap == pos:
      return -100.0

  let t = self.mget(pos)
  if t == 3: # forest
    result += 15.0
  elif t == 2: # rock
    result += 10.0

  if pos.x == 0 or pos.x == width - 1 or pos.y == 0 or pos.y == height - 1:
    result -= 5.0

  for n in self.neighbors(u, pos, false):
    if self.mget(n) == 3: # adjacent to forest, slight risk
      result -= 1.0
    if self.mget(n) == 2: # to rock, big risk
      result -= 5.0
    if self.mget(n) == 4: # to water, big risk
      result -= 5.0
    for u2 in units:
      if u2.battlePos == n and u2.team == u.team:
        result -= 2.0
        break

  for n in self.neighborsDiagonal(u, pos, false):
    for u2 in units:
      if u2.team == u.team:
        result += 5.0

  if target != nil:
    # would pushing this target kill them?
    var dir = u.battlePos - target.battlePos
    dir.x = clamp(dir.x, -1, 1)
    dir.y = clamp(dir.y, -1, 1)

    let posAfterAttack = target.battlePos + dir
    if self.mget(posAfterAttack) in [2,4]:
      result += 20.0
    else:
      for u2 in units:
        if u2.battlePos == posAfterAttack and u2.isVisible(u.team):
          result += 20.0
          break
        elif u2.team == u.team:
          for n in self.neighbors(target, posAfterAttack, false):
            if n == posAfterAttack:
              result += 30.0
              break

    # would pushing them push them into an ambush?

    # TODO take into account whether we'd end up in a bad position if it's a direct attack

  result += rndbi(5.0)

proc calculateMove(self: Battle, u: Unit): (Vec2i,float32) =
  var possibleAttackOrigins: seq[tuple[pos: Vec2i, unit: Unit, score: float32]]
  let possibleMoves = self.calculatePossibleMoves(u, false)
  for ma in possibleMoves:
    # check if there's anything we can attack here
    for u2 in units:
      if u2.team != u.team and u2.isVisible(u.team):
        if self.canAttackFrom(u, ma[0], u2.battlePos):
          possibleAttackOrigins.add((ma[0], u2, 0.0f))

  for ao in possibleAttackOrigins.mitems:
    ao.score = self.scorePosition(u, ao.pos, ao.unit)

  possibleAttackOrigins.keepItIf(it.score >= 0)

  if possibleAttackOrigins.len == 0:
    var bestPos = u.battlePos
    var bestScore: float32 = float32.low
    for ma in possibleMoves:
      let score = self.scorePosition(u, ma[0])
      if score > bestScore:
        bestScore = score
        bestPos = ma[0]
    return (bestPos,bestScore)

  else:
    var bestPos = u.battlePos
    var bestScore = float32.low
    for ao in possibleAttackOrigins:
      if ao.score > bestScore:
        bestScore = ao.score
        bestPos = ao.pos
    return (bestPos,bestScore)

  return (u.battlePos,0.0f)

iterator countupordown[T](a,b: T): T =
  if a < b:
    for i in countup(a+1, b-1):
      yield i
  else:
    for i in countdown(a-1, b+1):
      yield i

iterator countupordownInclusive[T](a,b: T): T =
  if a < b:
    for i in countup(a, b):
      yield i
  else:
    for i in countdown(a, b):
      yield i

proc checkIfHidden(self: Battle, u: Unit) =
  if mget(u.battlePos) == 3:
    # check if adjacent to enemy
    u.hidden = true
    for u2 in units:
      let t = mget(u2.battlePos)
      if u2.team != u.team and manhattanDist(u.battlePos, u2.battlePos) <= (if t == 2: 2 else: 1):
        u.hidden = false
        if teamTurn != u.team:
          u.revealed = true
  else:
    u.hidden = false
    ## check LoS
    #u.hidden = true
    #for u2 in units:
    #  if u2.team != u.team:
    #    let a = u2.battlePos
    #    let b = u.battlePos
    #    if manhattanDist(a,b) == 1:
    #      u.hidden = false
    #    else:
    #      var blocked = false
    #      if a.x == b.x or a.y == b.y: # los travels along axes
    #        if a.y == b.y:
    #          for x in countupordown(a.x,b.x):
    #            if self.mget(vec2i(x, a.y)) == 2:
    #              blocked = true
    #              break
    #        elif a.x == b.x:
    #          for y in countupordown(a.y,b.y):
    #            if mget(vec2i(a.x, y)) == 2:
    #              blocked = true
    #              break
    #        if not blocked:
    #          u.hidden = false

proc revealHidden(self: Battle) =
  for u in units:
    u.checkIfHidden()

proc isVisible(self: Unit, viewerTeam: int): bool =
  if team == viewerTeam:
    return true
  if revealed:
    return true
  if hidden:
    return false
  return true

proc battleEndTurn(self: Battle, dt: float32): bool =
  battleUpdateCommon(dt)

  if moves.len > 0 or pauseTimer > 0:
    return true

  var bestUnitToMove: Unit = nil
  var bestTarget: Unit
  var bestMove: Vec2i
  var bestScore = float32.low

  for u in units:
    if u.team != 1:
      if u.battleMoves > 0:
        var move = calculateMove(u)
        if move[1] > bestScore:
          bestMove = move[0]
          bestScore = move[1]
          bestUnitToMove = u
          bestTarget = nil

      if u.battleAttacks > 0:
        for u2 in units:
          if u2.team != u.team:
            if u.canAttack(u2.battlePos):
              let score = self.scorePosition(u, u.battlePos, u2)
              if score > bestScore:
                bestUnitToMove = u
                bestScore = score
                bestTarget = u2
                bestMove = u2.battlePos

  if bestUnitToMove != nil and bestScore >= 0:
    echo "found a move: score: ", bestScore, " ", bestUnitToMove.battlePos, " -> ", bestMove, (if bestTarget != nil: " attacking!" else: " moving")
    if bestTarget != nil:
      attack(bestUnitToMove, bestTarget)
      return true
    elif bestMove != bestUnitToMove.battlePos:
      move(bestUnitToMove, bestMove, bmMove, 0)
      bestUnitToMove.battleMoves -= 1
      return true

  return false


proc worldMapUpdate(dt: float32) =
  var (mx,my) = mouse()
  if mx < screenWidth div 4:
    if mousebtnp(0):
      # select town or army or battle
      let tx = mx div 8
      let ty = my div 8

      for town in towns:
        if town.pos.x == tx and town.pos.y == ty:
          currentTown = town
          currentBattle = nil
          currentArmy = nil
          break

      for army in armies:
        if army.pos.x == tx and army.pos.y == ty:
          currentArmy = army
          currentTown = nil
          currentBattle = nil
          break

      for battle in battles:
        if battle.pos.x == tx and battle.pos.y == ty:
          currentBattle = battle
          currentTown = nil
          currentArmy = nil
          break

proc gameUpdate(dt: float32) =
  time += dt

  if(btnp(pcBack)):
    mainMenu = not mainMenu

  G.update(gameGui, dt)

  if mainMenu:
    return

  if updateCards(dt):
    return

  case turnPhase:
    of phaseStartOfTurn:
      if phaseTimer >= 0 and not cardsMoving():
        phaseTimer -= dt
        if phaseTimer < 0:
          saveGame()
          turnPhase = phaseTurn
      return
    of phaseEndOfTurn:
      if not cardsMoving() and battlesWaging:
        battlesWaging = false
        for battle in battles:
          if battle.battleEndTurn(dt):
            battlesWaging = true
      elif phaseTimer >= 0 and not cardsMoving() and not battlesWaging:
        phaseTimer -= dt
        if phaseTimer < 0:
          startTurn()
      return
    else:
      discard

  for town in towns:
    for site in town.sites:
      for u in site.units:
        if u.hp <= 0:
          if u.kind == Rebel:
            town.nRebelsKilled += 1
      site.units.keepItIf(it.hp > 0)

  if G.activeElement != 0 or G.hoverElement != 0 or G.modalArea != 0:
    return

  if currentBattle != nil:
    currentBattle.battleUpdate(dt)
  elif currentTown != nil:
    townUpdate(currentTown, dt)

  worldMapUpdate(dt)

  #if mousebtnp(0):
  #  var (mx,my) = mouse()
  #  # check which thing they clicked on
  #  if mx < screenWidth div 4 and (inputMode == SelectSite or inputMode == Relocate or inputMode == MoveArmy):
  #    # choose town or army on worldMap
  #    let tx = mx div 8
  #    let ty = my div 8
  #    if inputMode == MoveArmy and currentArmy != nil:
  #      if abs(tx - currentArmy.pos.x) <= 1 and abs(ty - currentArmy.pos.y) <= 1 and (tx == currentArmy.pos.x and ty == currentArmy.pos.y) == false:
  #        for town in towns:
  #          if town.pos.x == tx and town.pos.y == ty:
  #            # move army into town
  #            currentTown = town
  #            if currentTown.team != 1:
  #              for s in currentTown.sites:
  #                for u in s.units:
  #                  if u.kind == Neutral:
  #                    u.setKind(Rebel)
  #                    u.flash = 5
  #            currentTown.team = 1
  #            undoStack = @[]
  #            selectedSite = nil
  #            placingUnits = currentArmy.units
  #            inputMode = PlaceUnit
  #            armies.delete(armies.find(currentArmy))
  #            currentArmy = nil
  #            return
  #        currentArmy.pos = vec2i(tx, ty)
  #        currentArmy.moved = true
  #        inputMode = SelectSite
  #        return

  #    if inputMode == Relocate:
  #      if placingUnits.len == 0:
  #        # pick up army
  #        if abs(tx - currentTown.pos.x) <= 1 and abs(ty - currentTown.pos.y) <= 1 and (tx == currentTown.pos.x and ty == currentTown.pos.y) == false:
  #          var army: Army = nil
  #          for i, army in armies:
  #            if army.pos.x == tx and army.pos.y == ty:
  #              if army.team == 1:
  #                placingUnits = army.units
  #                armies.delete(i)
  #                return
  #      else:
  #        # place army
  #        if abs(tx - currentTown.pos.x) <= 1 and abs(ty - currentTown.pos.y) <= 1 and (tx == currentTown.pos.x and ty == currentTown.pos.y) == false:
  #          var army: Army = nil
  #          for a in armies:
  #            if a.pos.x == tx and a.pos.y == ty:
  #              army = a
  #              break
  #          if army != nil:
  #            if army.team != 1:
  #              return
  #          if army == nil:
  #            army = newArmy(vec2i(tx,ty), 1, placingUnits)
  #            army.source = currentTown
  #            army.moved = true
  #            armies.add(army)
  #          else:
  #            for u in placingUnits:
  #              u.site = nil
  #            army.units.add(placingUnits)
  #            army.moved = true
  #          placingUnits = @[]
  #          return
  #    elif inputMode == SelectSite:
  #      for town in towns:
  #        if town.pos.x == tx and town.pos.y == ty:
  #          currentTown = town
  #          currentArmy = nil
  #          selectedSite = nil
  #          break
  #      for army in armies:
  #        if army.pos.x == tx and army.pos.y == ty:
  #          currentArmy = army
  #          currentTown = nil
  #          selectedSite = nil
  #          break

  #  elif inputMode == SelectSite:
  #    selectedUnit = nil
  #    # select shaman
  #    if hoverUnit != nil and hoverUnit.kind == Shaman:
  #      selectedUnit = hoverUnit
  #      if currentTown != nil:
  #        for site in currentTown.sites:
  #          if site != nil:
  #            for u in site.units:
  #              if u == selectedUnit:
  #                selectedSite = site
  #                break
  #      return

  #  if currentTown != nil:
  #    # select site
  #    var sx = screenWidth div 2 - 25 * currentTown.width
  #    var sy = screenHeight div 2 - 25 * currentTown.height
  #    if mx < sx or my < sy or mx > sx + currentTown.width * 50 or my > sy + currentTown.height * 50:
  #      # out of bounds, pan
  #      discard
  #    else:
  #      mx -= sx
  #      my -= sy
  #      let tx = mx div 50
  #      let ty = my div 50
  #      if tx >= 0 and tx < currentTown.width and ty >= 0 and ty < currentTown.height:
  #        var site = currentTown.sites[ty * currentTown.width + tx]
  #        if site != nil:
  #          if inputMode == SelectSite:
  #            if hintSite == nil or hintSite == hoverSite:
  #              selectedSite = site

proc gameDraw() =
  frame += 1
  if gameStarted:
    gameDrawGame()
  else:
    gameDrawMenu()

  # cursor
  block drawCursor:
    let (mx,my) = mouse()

    # tooltip
    if not mainMenu and turnPhase == phaseTurn and hoverChangeTime < time - 0.3:
      setColor(21)
      setOutlineColor(1)
      if hoverUnit == nil and hoverSite != nil:
        printOutlineC($hoverSite.settings.name, mx, my - 15)
      elif hoverUnit != nil:
        printOutlineC($hoverUnit.kind, mx, my - 15)

    # cursor
    pal(29,0)
    setSpritesheet(0)
    if mainMenu:
      spr(0, mx, my)
    elif phaseTimer > 0:
      spr(34 + (frame.int div 10 mod 4), mx - 4, my - 4)
    elif G.downElement != 0:
      spr(40, mx - 1, my - 1)
    elif G.activeHoverElement != 0:
      spr(39, mx - 1, my - 1)
    elif inputMode == Relocate or inputMode == PlaceUnit or currentBattle != nil and currentBattle.unitsToDeploy.len > 0:
      spr(if hoverUnit == nil: 38 else: 41, mx - 4, my - 7)
    elif inputMode == SelectUnit:
      spr(33, mx - 4, my - 4)
    else:
      spr(0, mx, my)
    pal()

    # units
    var x = 0
    var y = 0
    if currentBattle != nil:
      for i in countdown(currentBattle.unitsToDeploy.high,0):
        let u = currentBattle.unitsToDeploy[i]
        if i == currentBattle.unitsToDeploy.high: # show first unit under cursor
          u.draw(mx - 4, my)
        else:
          u.draw(mx + 7 + x, my - 7 + y)
          x += 6
          if x >= 6 * 5:
            x = 0
            y += 8

    else:
      for i in countdown(placingUnits.high,0):
        let u = placingUnits[i]
        if i == placingUnits.high and hoverUnit == nil: # show first unit under cursor
          u.draw(mx - 4, my)
        else:
          u.draw(mx + 7 + x, my - 7 + y)
          x += 6
          if x >= 6 * 5:
            x = 0
            y += 8


proc gameDrawMenu() =
  cls()
  setCamera()
  G.draw(gameGui)

proc drawWorldMap() =
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

  for battle in battles:
    setColor(27)
    circfill(battle.pos.x * 8 + 4, battle.pos.y * 8 + 4, 4)

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

proc gameDrawGame() =
  setCamera()

  setColor(1)
  rectfill(0,0,screenWidth,screenHeight)

  if currentBattle != nil:
    currentBattle.drawBattle()

  elif currentArmy != nil:
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

  elif currentTown != nil:
    currentTown.draw()

  drawWorldMap()


  setColor(15)
  vline(screenWidth div 4, 0, screenHeight - 1)

  setSpritesheet(0)

  setCamera()

  # particles
  for p in mitems(particles):
    setSpritesheet(p.sheet)
    var pos = if p.hasDest: lerp(p.pos, p.dest, 1.0 - (p.ttl / p.maxTtl)) else: p.pos
    if p.text != "":
      setColor(if frame mod 8 < 4: p.color1 else: p.color2)
      printOutlineC(p.text, pos.x, pos.y)
    else:
      let a = p.ttl / p.maxTtl
      let f = lerp(p.startSpr.float32,p.endSpr.float32,a).int
      spr(f, pos.x, pos.y)

    if not p.hasDest:
      p.pos += p.vel * 1.0/60.0
    p.ttl -= 1.0/60.0

  particles.keepItIf(it.ttl > 0)

  setCamera()
  G.draw(gameGui)


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
#nico.createWindow("ld43", 1080 div 4, 1920 div 4, 2)

#fps(60)
fixedSize(false)
integerScale(true)

loadConfig()
focusFollowsMouse = parseBool(getConfigValue("General", "focusFollowsMouse", "false"))

try:
  saveExists = loadGame()
except:
  saveExists = false

nico.run(gameInit, gameUpdate, gameDraw)
