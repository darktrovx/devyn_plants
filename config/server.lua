return {
    plantCheck = 10, -- seconds
    plantTypes = {
        ['weed'] = {
            defaults = {
                food = 5,
                water = 5,
            },
            harvest = {
                item = 'weed_bud',
                min = 5,
                max = 10,
            },
            growthItems = {
                food = {
                    ['fertilizer'] = {
                        name = 'Fertilizer',
                        usage = 1,
                        growth = 1,
                    },
                },
                water = {
                    ['water'] = {
                        name = 'Water',
                        usage = 1,
                        growth = 1,
                    },
                }
            },
            stages = {
                [1] = {
                    name = 'Seedling',
                    time = 14400, -- seconds
                    bonus = {
                        food = 5,
                        water = 5,
                        extra = 1,
                    },
                },
                [2] = {
                    name = 'Flowering',
                    time = 18000, -- seconds
                    bonus = {
                        food = 5,
                        water = 5,
                        extra = 3,
                    },
                },
                [3] = {
                    name = 'Harvest',
                    time = 18000, -- seconds
                    bonus = {
                        food = 5,
                        water = 5,
                        extra = 2,
                    },
                },
            },
        }
    }
}