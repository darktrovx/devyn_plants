# devyn_plants

# Dependancies
ox_lib : https://github.com/overextended/ox_lib
ox_inventory : https://github.com/overextended/ox_inventory
oxmysql : https://github.com/overextended/oxmysql
interact : https://github.com/darktrovx/interact

# Setup
Run the `db.sql` inside the setup folder.

Add these items to ox_inventory/data/items

```
["weed_seed"] = {
		label = "Weed Seed",
		weight = 1000,
		stack = true,
		close = true,
		degrade = 4320,
		decay = true,
		description = "Grow this sky high",
		client = {
			image = "weed_seed.png",
		}
	},
	["weed_fertilizer"] = {
		label = "Fertilizer",
		weight = 3000,
		stack = true,
		close = true,
		degrade = 4320,
		decay = true,
		description = "Smells like shit",
		client = {
			image = "weed_nutrition.png",
		}
	},
	["weed_bud"] = {
		label = "Weed Bud",
		weight = 500,
		stack = true,
		close = true,
		degrade = 4320,
		decay = true,
		description = "",
		client = {
			image = "weed.png",
		}
	},
```

 
