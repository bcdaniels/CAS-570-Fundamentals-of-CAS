breed [households household]
households-own [energy move-threshold net-return move-dist farm-dist fission-rate min-fertility]

patches-own [vegetation fertility farmstead state field owner fallow veg-clear-cost site]

globals [xval yval init-energy divisor cum_bad-years check max_veg
          move-rate harvest-rate farm-rate clearing-rate move-cost-rate
         fertility-loss-rate
         restore-rate ]

to setup
  clear-all
  set init-energy 100
  set max_veg 50
  set-default-shape households "house"
  set cum_bad-years 0
  set divisor 1
  set move-rate init-move-threshold / 100
  set harvest-rate harvest / 100
  set farm-rate farm-cost / 100
  set clearing-rate tree-clearing-cost / 100
  set move-cost-rate move-cost / 100
  set fertility-loss-rate fertility-loss / 100
  set restore-rate fertility-restore / 100
  setup-patches
  setup-households
  reset-ticks
end

to setup-patches
  ask patches [
    set vegetation 50
    set pcolor 62
    set field 0
    set fertility 1
    set owner -1
    set fallow 0
    set state "unused"
    set site FALSE
    set farmstead 0
    set veg-clear-cost init-energy * clearing-rate
    ]
end

to setup-households
  create-households init-households [
    set size 2
    set energy init-energy
    ifelse adaptive [
      set move-dist (random 4) + 1   ;; jump distance
      set move-rate random-float 1  ;; move threshhold
      set fission-rate 1 + random-float 1 ;; fission energy
      set farm-dist (random 19) + 1 ;; swidden radius
      set min-fertility random-float 1  ;; minimum fertility acceptable for farming
;      set n_patches (random 4) + 1  ;; number of patches to farm
    ][
      set color red
      set fission-rate fission-energy / 100
      set farm-dist swidden-radius
      set move-threshold init-energy * move-rate ; calculate move threshold from % value set by user
      set min-fertility 0.8
    ]

    move-to one-of patches
    let hh-num who

    ask patch-here [
      ;; build a farmstead but you can't farm here
      set pcolor red
      set farmstead farmstead + 1
      set state "active"
      set fertility 0
    ]
    ask other patches in-radius farm-dist with [owner = -1] [
      ;; household takes ownership of unowned patches in area around farmstead
      set owner hh-num
      set pcolor 74
      set state "active"
      set fallow 0
    ]
  ]
end

to go
  if max_cycles > 0 and ticks >= max_cycles [ stop ] ; stop the simulation if preset tick limit
  ifelse bad-years != 0 and random 100 <= bad-years ; determine if it is a "bad year" and cut harvest in half
    [set divisor 2
    set cum_bad-years cum_bad-years + 1]
    [set divisor 1]

  ifelse show-info = "none" ; show household energy switch
    [ ask households [set label ""] ask patches [set plabel ""] ]
    [ ifelse show-info = "energy"
      [ask households [set label round energy] ask patches [set plabel ""]]
      [ask patches [set plabel owner] ask households [set label who]]
    ]

  ask households [
    ifelse tracking [pen-down][pen-up]
    set size 1.5 * count households-on patch-here
    check-move ;; move to new location if energy falls below threshhold
    choose-land ;; pick patch to cultivate and farm it
    reproduce ;; reproduce if enough surplus energy
    check-death ;; die if energy drops to 0
  ]

  regrow-patch ;; regrow vegetation and optional restore fertility
  tick ;; mark time cycle
  if not any? households [ stop ] ; stop simulation if all households are dead or gone
end

to check-move
  ; If household energy drops below a threshhold, move to a new location
  ; Reset the 'move threshhold' to be lower so that a household doesn't keep moving after it first moves.
  ; Over time, bring the 'move threshhold back up to its original value

  ifelse energy < move-threshold [
    move
  ][
    if move-threshold < (init-energy * move-rate) and energy > move-threshold [set move-threshold move-threshold + 1]
  ]
end

to move
  ;; procedure to move to a new farm and abandon the old one

    ;; find a new fertile patch to move to that is unowned and is not a farmstead
    let fertility-lim min-fertility
    if not adaptive [set move-dist (random 4) + 1]
    let new-farm one-of patches in-radius ( (farm-dist * move-dist) + 1) with [fertility > fertility-lim and farmstead = 0 and owner = -1]
    if not is-patch? new-farm [ ;; no patch to move to
      stop
    ]

  let hh-num who ; household ID
  let old-farm patch-here
  ;; abandon old farmstead
  if count households-on patch-here = 0 [ ;; display previous farmstead as abandoned if no households left there
    ask patch-here [
      set pcolor violet - 2
      set farmstead farmstead - 1
      if farmstead = 0 [
        set state "abandoned"
        set site TRUE]
      ]

    ask other patches with [owner = hh-num] [ ;; release previously owned patches when household moves but not when it fissions
      set owner -1
      set fallow 0
      set pcolor 62
      set state "unused"
    ]
  ]

  ;; move to new farmstead
  move-to new-farm
  ask patch-here [ ;; establish a new farmstead and take ownership of land around it; build a farmstead but you can't farm here
    set pcolor red
    set farmstead farmstead + 1
    set state "active"
    set fertility 0
    ]

  ask other patches in-radius farm-dist with [owner = -1] [
    set owner hh-num ;; household takes ownership of unowned patches in area around farmstead
    set pcolor 74 ;; initial color to see farming area
    set state "active"
    set fallow 0
    ]

  set energy energy - (init-energy * move-cost-rate) - ((distance old-farm) / 5) ; energy to move to new farm
  if energy <= move-threshold [
    set move-threshold move-threshold - ((init-energy * move-cost-rate) + 1) ; drop new moving threshold below current energy level
  ]
end

to choose-land
  let hh-num 0
  set hh-num who
  ifelse any? other (patches in-radius farm-dist) with [fertility > 0 and (owner = hh-num or owner = -1)] [ ; check for owned or unclaimed fertile patches
    ;; pick an owned patch to cultivate with the maximum potential net return
    let farm-patch one-of (((
          (patches in-radius farm-dist)
          with [owner = hh-num or owner = -1])
          with-max [(fertility * harvest-rate * init-energy) - (farm-rate * init-energy) - veg-clear-cost - ((distancexy pxcor pycor) / 5)]))

    ask farm-patch [ ;; take posession of patch if not already owned
      set owner hh-num
    ]
    farm farm-patch ; cultivate the patch
  ][
    set energy energy - (0.1 * init-energy) ;; household continues to use energy even if it doesn't farm
  ]
end

to farm [farmfield]
  let fval 1.0
  ask farmfield [
    if vegetation > 0 [ set vegetation 0] ; clear any vegation on the land to farm
    set fallow 0 ; mark field as cultivated
    set field 1 ; mark field as cultivated
    set pcolor 31
    set fval fertility
    if fertility > 0 [set fertility (fertility - fertility-loss-rate)] ; reduce fertility by farming
    if fertility < 0 [set fertility 0] ; fertility can't drop below 0
    set pcolor 39.9 - (8.9 * fertility) ; set color to match fertility
    ]
  set net-return ((harvest-rate * init-energy) * fval / divisor) - (farm-rate * init-energy) - veg-clear-cost - ((distance farmfield) / 5) ; calculate harvest return
  set energy energy + net-return ; add return to household energy
end

to reproduce
  ; if household energy passes threshold, create a new household,
  ; give each of the 2 households half the energy of the original,
  ; and move the new household to a new location

  if energy > (init-energy * fission-rate) and (energy / 2) > move-threshold [
    let parent-energy energy
    let parent-color color
    hatch 1 [
      set size 2
      set color parent-color
      set energy (parent-energy / 2)
      if energy <= move-threshold [ ;; reset move threshold to be a little below current energy
        set move-threshold energy - (0.1 * energy)
      ]
      if adaptive and random 1000 <= innovation-rate [ ;; descendent innovates
        innovate
      ]
      move
    ]
    set energy (energy / 2)
    if energy <= move-threshold [ ;; reset move threshold to be a little below current energy
      set move-threshold energy - (0.1 * energy)
    ]
  ]
end

to innovate
  let color-change 1
  if random 2 = 0 [set color-change -1]
  set color color + color-change
  let innovation one-of [1 2 3 4 5]
  if innovation = 1 [
    set move-dist (random 4) ; recalculate jump distance
  ]
  if innovation = 2 [
    set move-rate random-float 1 ; recalculate move threshhold
  ]
  if innovation = 3 [
    set fission-rate random-float 1 ; recalculate fission energy
  ]
  if innovation = 4 [
    set farm-dist (random 19) + 1  ; recalculate swidden radius
  ]
  if innovation = 5 [
    set min-fertility random-float 1  ; recalculate minimum fertility acceptable for farming
  ]
; set n_patches (random 4) + 1   ; recalculate number of patches to farm
end


to check-death
  let hh-num who
  if energy <= 0 [
    ask patch-here [ ; show farmstead as one whose household died
      set farmstead farmstead - 1
      if farmstead = 0 [
        set pcolor magenta - 2
        set site TRUE
        set state "died"
      ]
    ask other patches with [owner = hh-num] [ ;; release owned packages when household moves
      set owner -1
      set state "unused"
      set pcolor 62
    ]
    ]
   die
  ]
end

to regrow-patch
  ask patches [
    set farmstead count households-here
    ifelse fertility < 1
      [set fertility fertility + restore-rate] ; restore fertility
      [set fertility 1]; don't exceed max fertility
    if farmstead = 0 and not site and field = 0 [
      if vegetation < 50 [
        set vegetation vegetation + 1 ; regrow vegetation in non-farmed non-farmstead fields
        set pcolor 69.9 - (vegetation * 7.9 / 50) ; set vegetation color according to vegetation type (forest is darker green)
      ]
    ]

    if owner != -1 and field = 0 [set fallow fallow + 1] ; increment timer on fields uncultivated in current cycle for potential release

    set field 0 ; re-initialize all fields as uncultivated for next cycle (all fields uncultivated after harvest)
    if transfer-ownership [
      if fallow > max-fallow and farmstead = 0 and not site [set owner -1] ; release field uncultivated for <max-fallow> years to be claimed by others
    ]
    if clearing-rate > 0 and vegetation > 0 [set veg-clear-cost (init-energy * clearing-rate / 100) * (vegetation / max_veg)]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
560
10
1123
574
-1
-1
5.5
1
9
1
1
1
0
1
1
1
-50
50
-50
50
1
1
1
ticks
30.0

BUTTON
10
10
76
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
10
143
43
run
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
190
600
298
645
Total farmsteads
count patches with [farmstead > 0 and state = \"active\"]
0
1
11

PLOT
190
80
550
245
Households
time
totals
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"count" 1.0 0 -13345367 true "" "plot count households"

SLIDER
10
185
180
218
harvest
harvest
0
100
12.0
1
1
%
HORIZONTAL

SLIDER
10
115
180
148
fission-energy
fission-energy
100
200
150.0
1
1
%
HORIZONTAL

BUTTON
145
10
208
43
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
190
255
550
420
Farming Returns
time
totals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"avg returns X 10" 1.0 0 -10899396 true "" "if count households > 0 [plot 10 * mean [net-return] of households]"
"avg energy" 1.0 0 -5825686 true "" "if count households > 0 [plot mean [energy] of households]"
"avg fertility %" 1.0 0 -12440034 true "" "plot 100 * mean [fertility] of patches"

SLIDER
10
290
180
323
init-move-threshold
init-move-threshold
0
100
50.0
5
1
%
HORIZONTAL

SLIDER
10
80
180
113
init-households
init-households
1
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
10
150
180
183
swidden-radius
swidden-radius
0
20
12.0
1
1
patches
HORIZONTAL

SLIDER
10
220
180
253
farm-cost
farm-cost
0
100
3.0
1
1
%
HORIZONTAL

SLIDER
10
325
180
358
move-cost
move-cost
0
100
2.0
1
1
%
HORIZONTAL

SLIDER
10
360
180
393
fertility-loss
fertility-loss
0
100
15.0
1
1
%
HORIZONTAL

SLIDER
10
395
180
428
fertility-restore
fertility-restore
0
100
1.0
1
1
%
HORIZONTAL

PLOT
190
430
550
595
Vegetation
time
%
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"forest" 1.0 0 -15575016 true "" "plot (count patches with [vegetation >= 40]) * 100 / (count patches)"
"shrub" 1.0 0 -8732573 true "" "plot (count patches with [vegetation >= 20 and vegetation < 40]) * 100 / (count patches)"
"grass/herb" 1.0 0 -4079321 true "" "plot (count patches with [vegetation > 0 and vegetation < 20 ]) * 100 / (count patches)"
"bare" 1.0 0 -6459832 true "" "plot (count patches with [vegetation = 0]) * 100 / (count patches)"
"farmed" 1.0 0 -2674135 true "" "plot (count patches with [field = 1]) * 100 / (count patches)"
"fallowed" 1.0 0 -13345367 true "" "plot (count patches with [fallow > 0]) * 100 / (count patches)"

INPUTBOX
215
10
314
70
max_cycles
1000.0
1
0
Number

SLIDER
10
430
180
463
bad-years
bad-years
0
100
20.0
1
1
%
HORIZONTAL

SLIDER
10
255
180
288
tree-clearing-cost
tree-clearing-cost
0
100
3.0
1
1
%
HORIZONTAL

SLIDER
10
500
180
533
max-fallow
max-fallow
0
40
20.0
1
1
NIL
HORIZONTAL

SWITCH
10
465
180
498
transfer-ownership
transfer-ownership
1
1
-1000

CHOOSER
320
10
412
55
show-info
show-info
"none" "energy" "owner"
0

MONITOR
300
600
410
645
Active households
count households
17
1
11

MONITOR
410
600
549
645
households/farmstead
count households / count patches with [farmstead = 1 and state = \"active\"\n]
1
1
11

SWITCH
10
535
180
568
adaptive
adaptive
1
1
-1000

SLIDER
10
570
180
603
innovation-rate
innovation-rate
0
500
500.0
10
1
per 1000
HORIZONTAL

MONITOR
620
600
717
645
fission energy
mean [fission-rate] of households * 100
0
1
11

MONITOR
720
600
822
645
swidden radius
mean [farm-dist] of households
0
1
11

MONITOR
820
600
900
645
min fertility
mean [min-fertility] of households
1
1
11

MONITOR
900
600
1020
645
move threshold (%)
mean [move-rate] of households * 100
0
1
11

MONITOR
1020
600
1092
645
move dist
mean [move-dist] of households
1
1
11

SWITCH
420
10
527
43
tracking
tracking
1
1
-1000

MONITOR
470
330
550
375
avg energy
mean [energy] of households
0
1
11

MONITOR
470
375
550
420
avg return
mean [net-return] of households
0
1
11

@#$#@#$#@
#SWIDDEN FARMING VERSION 2.0

## MODEL OVERVIEW

####This model simulates some of the dynamics of house-hold level swidden agriculture (also called shifting cultivation or slash-and-burn agriculture). The model can run in controled or adaptive mode. In controlled mode, the user sets values related to farming decisions. In adaptive mode, these values are set by the household agents who transmit their practices to daughter households with the possibility of innovation.

## MODEL FUNCTION

### INITIALIZATION
A number of households selected by the user are placed randomly on a landscape. All households begin with 100 eu (energy units). Initially, all patches are covered with forest (vegetation = 50) and have a maximum fertility value (= 1.0). All households use a minimum amount of energy to contiue to live, even if they don't farm (currently set to 1% of the initial energy per model cycle [tick]).

### ESTABLISHING A FARM 
Households establish a farmstead and claim ownership of all patches within the [swidden-radius] (set by the user in controlled mode and by the household agent in adaptive mode). Other households cannot farm this land while it is is owned. The household then begins to farm patches in area owned. Farming is not permitted on the farmstead patch itself. Farmsteads are identified by their red color in controlled mode (in adaptive mode, colors vary - see below). 

When a household moves or dies, it relinquishes ownership of its patches. An abandonded farmstead turns violet in color; a farmestead where the household dies (or disperses if we want to be kinder and gentler about it) turns magenta. There is some variation to this pattern of ownership if the [transfer-ownership] option is enabled (see below).

### SELECTING A PATCH TO CULTIVATE
Each househole selects a patch to cultivate each cycle from among owned patches that 1) have the maximum fertility and 2) produce the maximum potential net return (harvest minus costs to farm, clear land, and travel to the farmed land).

### CULTIVATING A PATCH
When a patch is cultivated, it is cleared of vegetation (vegetation set to 0) and the color is set to white. The cost of clearing vegetation is scaled according to the cost of clearing forest (set by the user), with forest (vegetation = 50) costing the most to clear and nearly bare grass (vegetation = 1) the least. There is a small energy cost for travel to and from fields (currently set to 20% of the distance to the field in eu's -- i.e., cultivating a patch that is 5 units away will incur a cost of 1 eu per cycle). The fertility value of the patch declines by the [fertility-loss] factor set by the user. 

Each patch farmed produces a gross return in [harvest] (set by the user at the beginning of the simulation run), weighted by the patch fertility, which declines with each time it is farmed. 

The net return to the household = [harvest] * [fertility] - [farm-cost]. The [farm-cost] (i.e., the energy cost to cultivate the patch, also in eu's) is also set by the user at the beginning of the run. The household's total energy is increased (or decreased) by the net return.

### MOVING
If the energy of a household drops below a percentage of the initial energy ([init-move-threshold], set by the user in controlled mode and by the household in adaptive move), the household will search for a new location to farm. It will look for a patch with a specified level of fertility and at some distance from the existing farmstead. In controlled mode, the household searches for land with at least 80% of the maximum fertility value within a radius that is [swidden_radius] X [a random number between 1 and 5]. In adaptive mode, the household agent 'decides' what is an acceptable minimum fertility value and the multiplier (still between 1 and 5) for the [swidden-radius] to determin distance to the new farm. 

When it finds such a location, the household will move to that patch, establish a new farmstead, and begin swidden farming around the new farmstead. There is a fixed cost to moving [move-cost] (in eu's) set by the user plus a cost scaled to distance (currently set to 20% of the distance in eu's).

### REPRODUCTION
If a household accumulates more energy than specified by [fission-energy] (set by the user in controlled mode and by the household agent in adaptive mode), it will fission and create (hatch in NetLogo) a new household. This household follows the move routine to establish a new place to farm--if one is available. If no suitable new land is available, the new household will stay on the existing farmstead and farm the land along with the parent household until land is available. After fissioning, both the parent and daughter households receive half the amount of energy stored by the parent prior to fissioning.

### LAND TENURE
If the [transfer-ownership] switch is on, households have limited land tenure. If land has lain fallow for more than the number of years set by the user in the [max-fallow] slider, it reverts to unclaimed and any agent (including the original owner) can claim it in the next cycle.

### REVEGETATION AND FERTILITY RECOVERY
Each patch that has been cultivated but that is not currently being farmed nor is a current or former farmstead begins to regrow vegetation. Vegetation increments by a value of 1 each cycle until it reaches 50 (forest). The user can also set a soil fertility recovery value [fertility-restore]. A patch that is not a farmstead will regain this much of its fertility each cycle until it reaches a maximum of 1.00.

### STOCHASTIC EVENTS
A temporally variable environment can simulated. A [bad-years] value can be set by the user. This represents the approximate percentage of total cycles that there are poor harvests. Currently, a poor harvest is half its normal value. A random function selects cycles as a 'bad year'. All households are affected equally by bad years, although this could easily be changed to randomly select individual household to have a poor harvest in any particular cycle.

### OUTPUT DISPLAYS
The displays are self-explanatory. For each cycle, they track the number of households actively farming, the sum of fertility values in all patches, the mean of net harvest returns and energy per household, and cumulative number of farmsteads established.

### ADAPTIVE MODE
In adaptive mode, the household agents, not the user set the following variables: [fission-energy], [init-move-threshold], [swidden-radius], [move-distance] (multiplier for moving to a new farm), and [min-fertility] (minimum acceptable fertilility to establish a new farm) and user settings for these variables are ignored. 

These values are randomized for the agents that start the simulation, and are passed to all daughter households if a household fissions. However, each daughter household has a chance when it is initialized (hatched in NetLogo) to randomize one of the household-set variables in adaptive mode. This chance of "innovation" is determined by [innovation-rate] slider. 

Each household, with different farming values, is initialized with a random color at the start of the simulation. All daughter households will keep the same color as the parent household. If a daughter household "innovates" a new farm practice value, its color will shift to a different shade of the original parent color. 

## STARTING THE SIMULATION

Set options (see above). Most options are expressed in percent of initial household energy. The switches for [transfer-ownership] and [adaptive] mode can be enabled or disabled.

Click setup

Optionally set the maximum cycles. When this number of ticks is reached, the simulation stops. If cycles is set to 0, the simulation continues indefinitely or until all households die.

Optionally set the [show-info] chooser can be set to display the energy value or ID for each household during the simulation. 

If [tracking] is on, a colored line will track the movement of each household.

Click run (or step to step through the simulation one cycle at a time)

## THINGS TO NOTICE

With only very small soil recovery values, farming can be maintained for thousands of cycles. 

Varying the soil fertility loss and recovery values will cause households to shift between short and long fallow farming.

Changing land tenure rules can cause a phase change, shifting the model from a dynamically stable population of households to boom-bust cycles.

Most farmsteads generated in adaptive mode ultimately fail.

Shrubs are an uncommon vegetation community except during boom-bust cycles. Swidden farming creates a mosaic of forest and open land, but does not encourage the spread of shrubs.

## EXTENDING THE MODEL

A good extension would be to have the option of a variable landscape with respect to soil fertility.

## RELATED MODELS

This model combines an earlier swidden farming model with an adaptive agent version of that model.

## CREDITS AND REFERENCES

####Copyright C. Michael Barton, Arizona State University. 2013
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>count turtles</metric>
    <steppedValueSet variable="swidden_radius" first="1" step="1" last="10"/>
  </experiment>
  <experiment name="Limit Tenure experiment" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count households</metric>
    <metric>ticks</metric>
    <enumeratedValueSet variable="fission-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fertility-loss">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptive">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tree-clearing-cost">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bad-years">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-cost">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-households">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-tenure">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="harvest">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-fallow">
      <value value="3"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="swidden-radius">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fertility-restore">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-move-threshold">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_cycles">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-cost">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
