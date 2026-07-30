# ox_doorlock NODE7 Recipe

```cfg
exec @ox_doorlock/permissions.cfg

ensure oxmysql
ensure ox_lib
ensure ox_target
ensure node7-core
ensure node7-inventory
ensure node7-lockpick-minigame
ensure ox_doorlock
```

Import `sql/ox_doorlock.sql` once for a new database. Add the item from `ITEM.lua` to the NODE7 shared items file and copy `lockpick.png` into the NODE7 inventory image directory.
