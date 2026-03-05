## HL1 VOX Sound System

VOX words are played via `surface.PlaySound("vox/<word>.wav")` on the CLIENT.
For sequential playback, use `timer.Simple(delay, fn)` with each word's duration + a 0.05s gap.

**CRITICAL: Only use words from the verified list below. Do NOT invent words — they will fail to load.**

## Complete Verified Word List (valve/sound/vox/)

```
a  accelerating  accelerator  accepted  access  acknowledge  acknowledged  acquired
acquisition  across  activate  activated  activity  adios  administration  advanced
after  agent  alarm  alert  alien  aligned  all  alpha  am  amigo  ammunition  an
and  announcement  anomalous  antenna  any  apprehend  approach  are  area  arm
armed  armor  armory  arrest  ass  at  atomic  attention  authorize  authorized
automatic  away  b  back  backman  bad  bag  bailey  barracks  base  bay  be  been
before  beyond  biohazard  biological  birdwell  bizwarn  black  blast  blocked
bloop  blue  bottom  bravo  breach  breached  break  bridge  bust  but  button
buzwarn  bypass  c  cable  call  called  canal  cap  captain  capture  ceiling
celsius  center  centi  central  chamber  charlie  check  checkpoint  chemical
cleanup  clear  clearance  close  code  coded  collider  _comma  command
communication  complex  computer  condition  containment  contamination  control
coolant  coomer  core  correct  corridor  crew  cross  cryogenic  d  dadeda  damage
damaged  danger  day  deactivated  decompression  decontamination  deeoo  defense
degrees  delta  denied  deploy  deployed  destroy  destroyed  detain  detected
detonation  device  did  die  dimensional  dirt  disengaged  dish  disposal
distance  distortion  do  doctor  doop  door  down  dual  duct  e  east  echo  ed
effect  egress  eight  eighteen  eighty  electric  electromagnetic  elevator
eleven  eliminate  emergency  energy  engage  engaged  engine  enter  entry
environment  error  escape  evacuate  exchange  exit  expect  experiment
experimental  explode  explosion  exposure  exterminate  extinguish  extinguisher
extreme  f  facility  fahrenheit  failed  failure  farthest  fast  feet  field
fifteen  fifth  fifty  final  fine  fire  first  five  flooding  floor  fool  for
forbidden  force  forms  found  four  fourteen  fourth  fourty  foxtrot  freeman
freezer  from  front  fuel  g  get  go  going  good  goodbye  gordon  got
government  granted  great  green  grenade  guard  gulf  gun  guthrie  handling
hangar  has  have  hazard  head  health  heat  helicopter  helium  hello  help
here  hide  high  highest  hit  hole  hostile  hot  hotel  hour  hours  hundred
hydro  i  idiot  illegal  immediate  immediately  in  inches  india  ing
inoperative  inside  inspection  inspector  interchange  intruder  invallid
invasion  is  it  johnson  juliet  key  kill  kilo  kit  lab  lambda  laser  last
launch  leak  leave  left  legal  level  lever  lie  lieutenant  life  light  lima
liquid  loading  locate  located  location  lock  locked  locker  lockout  lower
lowest  magnetic  main  maintenance  malfunction  man  mass  materials  maximum
may  medical  men  mercy  mesa  message  meter  micro  middle  mike  miles
military  milli  million  minefield  minimum  minutes  mister  mode  motor
motorpool  move  must  nearest  nice  nine  nineteen  ninety  no  nominal  north
not  november  now  number  objective  observation  of  officer  ok  on  one  open
operating  operations  operative  option  order  organic  oscar  out  outside  over
overload  override  pacify  pain  pal  panel  percent  perimeter  _period
permitted  personnel  pipe  plant  platform  please  point  portal  power  presence
press  primary  proceed  processing  progress  proper  propulsion  prosecute
protective  push  quantum  quebec  question  questioning  quick  quit  radiation
radioactive  rads  rapid  reach  reached  reactor  red  relay  released  remaining
renegade  repair  report  reports  required  research  resevoir  resistance  right
rocket  roger  romeo  room  round  run  safe  safety  sargeant  satellite  save
science  scream  screen  search  second  secondary  seconds  sector  secure
secured  security  select  selected  service  seven  seventeen  seventy  severe
sewage  sewer  shield  shipment  shock  shoot  shower  shut  side  sierra  sight
silo  six  sixteen  sixty  slime  slow  soldier  some  someone  something  son
sorry  south  squad  square  stairway  status  sterile  sterilization  storage
sub  subsurface  sudden  suit  superconducting  supercooled  supply  surface
surrender  surround  surrounded  switch  system  systems  tactical  take  talk
tango  tank  target  team  temperature  temporal  ten  terminal  terminated
termination  test  that  the  then  there  third  thirteen  thirty  this  those
thousand  threat  three  through  time  to  top  topside  touch  towards  track
train  transportation  truck  tunnel  turn  turret  twelve  twenty  two
unauthorized  under  uniform  unlocked  until  up  upper  uranium  us  usa  use
used  user  vacate  valid  vapor  vent  ventillation  victor  violated  violation
voltage  vox_login  walk  wall  want  wanted  warm  warn  warning  waste  water  we
weapon  west  whiskey  white  wilco  will  with  without  woop  xeno  yankee  yards
year  yellow  yes  you  your  yourself  zero  zone  zulu
```

## Punctuation (special files)
- `_comma` — short pause
- `_period` — longer pause / sentence end

## Notable MISSING words (do NOT use)
- `unit`, `eliminated`, `stand`, `captured`, `mission`, `complete`, `advance`, `stop`, `hold`

## Known Word Durations (seconds, for timer.Simple sequencing)
```lua
["_comma"]=0.25, ["_period"]=0.43,
["a"]=0.37, ["alert"]=0.54, ["all"]=0.53, ["and"]=0.40,
["approach"]=0.81, ["are"]=0.31, ["at"]=0.29, ["attention"]=0.81,
["away"]=0.51, ["been"]=0.41, ["breached"]=0.57, ["capture"]=0.74,
["clear"]=0.55, ["deploy"]=0.75, ["destroy"]=0.65, ["down"]=0.54,
["eight"]=0.48, ["eliminate"]=0.80, ["engage"]=0.85, ["exterminate"]=0.98,
["fire"]=0.69, ["first"]=0.57, ["five"]=0.69, ["four"]=0.47,
["freeman"]=0.69, ["go"]=0.48, ["good"]=0.51, ["has"]=0.59,
["hostile"]=0.66, ["in"]=0.34, ["is"]=0.40, ["kill"]=0.61,
["man"]=0.58, ["move"]=0.49, ["nine"]=0.60, ["no"]=0.38,
["now"]=0.47, ["objective"]=0.76, ["one"]=0.47, ["out"]=0.38,
["perimeter"]=0.68, ["proceed"]=0.68, ["quick"]=0.48, ["renegade"]=0.78,
["roger"]=0.59, ["search"]=0.60, ["secure"]=0.65, ["secured"]=0.87,
["sector"]=0.60, ["six"]=0.55, ["squad"]=0.66, ["status"]=0.73,
["surrender"]=0.72, ["target"]=0.59, ["ten"]=0.50, ["terminated"]=0.88,
["that"]=0.38, ["the"]=0.36, ["threat"]=0.55, ["three"]=0.46,
["to"]=0.30, ["two"]=0.51, ["violation"]=0.94, ["wanted"]=0.60,
["warning"]=0.56, ["wilco"]=0.63, ["you"]=0.38, ["your"]=0.40,
["yourself"]=0.93, ["zero"]=0.65,
-- Fallback for any unlisted word: 0.6
```
