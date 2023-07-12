# chestlock
server sided chest lock mod for mineclone2


features so far:

* if you dont have access
  1. you cant blow it up
  2. you cant move items in or out
  3. you can only view the items
  4. you can not break the chest or signs
* if you place a sign and dont include your name, or make a typo, you can still remove it
* you can keep adding players by making signs on each side of the chest with [private] on the first line, to add multiple players
* you will always have access to your own chests, private signs, and other blocks that are protected
* you can add #HOPPER to the list to allow hopper extraction, hopper input to the chest is always allowed (too complex to prevent)

example sign:
```
[private]
Xandertron
Noob960
```

a sign placed on the back of the chest, including the sign above:
```
[private]
IHATEDOGS
Killer5
#HOPPER
```
all 4 players (plus hopper extraction) can access the chest
