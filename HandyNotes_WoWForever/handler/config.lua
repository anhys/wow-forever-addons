local myname, ns = ...

ns.defaults = {
    profile = {
        default_icon = "VignetteLoot",
        show_on_world = true,
        show_on_minimap = false,
        show_npcs = true,
        show_npcs_filter = "lootable", -- [lootable, notable]
        show_npcs_emphasizeNotable = true,
        show_treasure = true,
        show_treasure_filter = "lootable", -- [lootable, notable]
        -- show_treasure_emphasizeNotable = true,
        show_routes = true,
        upcoming = true,
        areapoi_soon = 10, -- minutes; how early ns.areaPoi.Soon() calls a point imminent
        found = false,
        alts_achievements_count = false,
        -- notability!
        achievement_notable = true,
        mount_notable = true,
        toy_notable = true,
        pet_notable = true,
        transmog_notable = true,
        quest_notable = true,
        decor_notable = true,
        transmog_specific = true, -- consider whether you know the appearance from *this* item specifically
        notable_shared = true,
        -- Reward:Notable() reads this: on, loot that can't drop for you isn't a
        -- reason to want a point. True keeps it doing what it always has; the
        -- plugins have no option for it yet, unlike SilverDragon
        charloot = true,
        -- icon stuff
        icon_scale = 1.0,
        icon_alpha = 1.0,
        icon_item = false,
        tooltip_charloot = true,
        tooltip_sharedloot = true,
        tooltip_pointanchor = true,
        tooltip_item = true,
        tooltip_questid = false,
        groupsHidden = {},
        groupsHiddenByZone = {['*']={},},
        zonesHidden = {},
        achievementsHidden = {},
        worldmapoverlay = true,
    },
    char = {
        hidden = {
            ['*'] = {},
        },
    },
}

ns.options = {
    type = "group",
    name = myname:gsub("HandyNotes_", ""),
    get = function(info) return ns.db[info[#info]] end,
    set = function(info, v)
        ns.db[info[#info]] = v
        ns.HL:Refresh()
    end,
    hidden = function(info)
        return ns.hiddenConfig[info[#info]]
    end,
    childGroups = "tab",
    args = {
        common = {
            type = "group",
            name = "Common",
            args = {
                icon = {
                    type = "group",
                    name = "Icons",
                    inline = true,
                    order = 10,
                    args = {
                        desc = {
                            name = "These settings control the look and feel of the icon.",
                            type = "description",
                            order = 0,
                        },
                        icon_scale = {
                            type = "range",
                            name = "Icon Scale",
                            desc = "The scale of the icons",
                            min = 0.25, max = 2, step = 0.01,
                            order = 20,
                        },
                        icon_alpha = {
                            type = "range",
                            name = "Icon Alpha",
                            desc = "The alpha transparency of the icons",
                            min = 0, max = 1, step = 0.01,
                            order = 30,
                        },
                        show_on_world = {
                            type = "toggle",
                            name = "World Map",
                            desc = "Show icons on world map",
                            order = 40,
                        },
                        show_on_minimap = {
                            type = "toggle",
                            name = "Minimap",
                            desc = "Show all icons on the minimap",
                            order = 50,
                        },
                        default_icon = {
                            type = "select",
                            name = "Default Icon",
                            values = {
                                VignetteLoot = CreateAtlasMarkup("VignetteLoot", 20, 20) .. " Chest",
                                VignetteLootElite = CreateAtlasMarkup("VignetteLootElite", 20, 20) .. " Chest with star",
                                Garr_TreasureIcon = CreateAtlasMarkup("Garr_TreasureIcon", 20, 20) .. " Shiny chest",
                            },
                            order = 60,
                        },
                        worldmapoverlay = {
                            type = "toggle",
                            name = "Add button to world map",
                            desc = "Put a button on the world map for quick access to these options",
                            set = function(info, v)
                                ns.db[info[#info]] = v
                                if WorldMapFrame.RefreshOverlayFrames then
                                    WorldMapFrame:RefreshOverlayFrames()
                                end
                            end,
                            hidden = function(info)
                                if not ns.SetupMapOverlay then
                                    return true
                                end
                                return ns.options.hidden(info)
                            end,
                            order = 70,
                        },
                    },
                },
                display = {
                    type = "group",
                    name = "What to display",
                    inline = true,
                    order = 20,
                    args = {
                        npcs = {
                            type = "group",
                            inline = true,
                            name = "NPCs",
                            args = {
                                show_npcs = {
                                    type = "toggle",
                                    name = "Show NPCs",
                                    desc = "Show rare NPCs, generally to be killed for items or achievements",
                                    order = 10,
                                    dropdownHidden = true,
                                },
                                show_npcs_filter = {
                                    type = "select",
                                    name = "Filter",
                                    desc = "Show rare NPCs, generally to be killed for items or achievements",
                                    values = {
                                        all = ALL,
                                        lootable = "Will drop loot",
                                        notable = "Will drop notable loot",
                                    },
                                    sorting = {"all", "lootable", "notable"},
                                    order = 20,
                                },
                                show_npcs_emphasizeNotable = {
                                    type = "toggle",
                                    name = "Emphasize notable NPCs",
                                    desc = "Put more emphasis on NPCs that you can still get something from: achievements, transmogs, mounts, pets, toys",
                                    order = 30,
                                },

                            },
                            order = 10,
                        },
                        treasure = {
                            type = "group",
                            inline = true,
                            name = "Treasure",
                            args = {
                                show_treasure = {
                                    type = "toggle",
                                    name = "Show Treasure",
                                    desc = "Show treasures that can be found in the world",
                                    order = 10,
                                    dropdownHidden = true,
                                },
                                show_treasure_filter = {
                                    type = "select",
                                    name = "Filter",
                                    desc = "Show treasures that can be found in the world",
                                    values = {
                                        all = ALL,
                                        lootable = "Will drop loot",
                                        notable = "Will drop notable loot",
                                    },
                                    sorting = {"all", "lootable", "notable"},
                                    order = 20,
                                },
                                -- show_treasure_emphasizeNotable = {
                                --     type = "toggle",
                                --     name = "Emphasize notable NPCs",
                                --     desc = "Put more emphasis on NPCs that you can still get something from: achievements, transmogs, mounts, pets, toys",
                                --     order = 30,
                                -- },

                            },
                            order = 20,
                        },
                        unhide = {
                            type = "execute",
                            name = "Reset hidden nodes",
                            desc = "Show all nodes that you manually hid by right-clicking on them and choosing \"hide\".",
                            func = function()
                                for _, coords in pairs(ns.hidden) do
                                    wipe(coords)
                                end
                                ns.HL:Refresh()
                            end,
                            order = 50,
                        },
                    },
                },
                -- the "found" cluster
                found = {
                    type = "group",
                    name = "Found...",
                    inline = true,
                    order = 30,
                    args = {
                        found = {
                            type = "toggle",
                            name = "Show found",
                            desc = "Show waypoints for items you've already found?",
                            order = 20,
                        },
                    },
                },
                tooltips = {
                    type = "group",
                    name = "Tooltips",
                    desc = "Settings about how tooltips are displayed",
                    inline = true,
                    args = {
                        tooltip_item = {
                            type = "toggle",
                            name = "Use item tooltips",
                            desc = "Show the full tooltips for items",
                            order = 10,
                        },
                        tooltip_charloot = {
                            type = "toggle",
                            name = "Loot for this character only",
                            desc = "Only show loot that should drop for the current character",
                            order = 12,
                        },
                        tooltip_sharedloot = {
                            type = "toggle",
                            name = "Shared loot",
                            desc = "Some rares have a common pool of drops that're shared between them",
                            order = 12,
                        },
                        tooltip_pointanchor = {
                            type = "toggle",
                            name = "Anchor tooltips to points",
                            desc = "Whether to anchor the tooltips to the individual points or to the map",
                            order = 15,
                        },
                        tooltip_questid = {
                            type = "toggle",
                            name = "Show quest ids",
                            desc = "Show the internal id of the quest associated with this node. Handy if you want to report a problem with it.",
                            order = 40,
                        },
                    },
                    order = 25,
                },
                notable = {
                    type = "group",
                    name = "What's notable?",
                    desc = "Define exactly what counts as being \"notable\"",
                    inline = true,
                    args = {
                        achievement_notable = {
                            type = "toggle",
                            name = TRANSMOG_SOURCE_5,
                            desc = "Count unearned achievement-progress as notable",
                            order = 10,
                        },
                        mount_notable = {
                            type = "toggle",
                            name = PERKS_VENDOR_CATEGORY_MOUNT or MOUNTS, -- MOUNT is the wrong form when translated
                            desc = "Count unlearned mounts as notable loot",
                            order = 10,
                        },
                        toy_notable = {
                            type = "toggle",
                            name = TOY,
                            desc = "Count unlearned toys as notable loot",
                            order = 20,
                        },
                        pet_notable = {
                            type = "toggle",
                            name = TOOLTIP_BATTLE_PET,
                            desc = "Count uncaught pets as notable loot",
                            order = 30,
                        },
                        transmog_notable = {
                            type = "toggle",
                            name = "Transmog",
                            desc = "Count unlearned transmogrification appearances as notable loot",
                            order = 40,
                        },
                        decor_notable = {
                            type = "toggle",
                            name = BINDING_TAG_DECOR or "Decor",
                            desc = "Count unfound decor as notable loot",
                            order = 50,
                            disabled = not BINDING_TAG_DECOR,
                        },
                        quest_notable = {
                            type = "toggle",
                            name = "Quest-attached",
                            desc = "Count items with attached uncompleted quests as notable loot (this includes a lot of \"learnable\" items, weekly reputation drops, etc)",
                            order = 60,
                        },
                    },
                    order = 40,
                },
                fiddly = {
                    type = "group",
                    name = "Fiddly details",
                    desc = "Quirky small tweaks",
                    inline = true,
                    args = {
                        icon_item = {
                            type = "toggle",
                            name = "Use item icons",
                            desc = "Show the icons for items, if known; otherwise, the achievement icon will be used",
                            order = 10,
                        },
                        upcoming = {
                            type = "toggle",
                            name = "Show inaccessible",
                            desc = "Show waypoints for items you can't get yet (max level, gated quests, etc); they'll be tinted red to indicate this",
                            order = 25,
                        },
                        areapoi_soon = {
                            type = "range",
                            name = "Event notice period",
                            desc = "How many minutes before a timed event starts to mark its point as imminent, on the map and in its tooltip",
                            min = 1, max = 60, step = 1,
                            order = 27,
                        },
                        show_routes = {
                            type = "toggle",
                            name = "Show routes",
                            desc = "Show relevant routes between points",
                            disabled = function() return not ns.MapSystem end,
                            order = 37,
                        },
                        transmog_specific = {
                            type = "toggle",
                            name = "Transmog exact items",
                            desc = "For transmog appearances, only count them as known if you know them from that exact item, rather than from another sharing the same appearance",
                            order = 45,
                        },
                        alts_achievements_count = {
                            type = "toggle",
                            name = "Alts achievements count",
                            desc = "Consider achievement-related things done if you have it completed on another character already. Lots of achievement criteria are warband-shared, in which case this setting won't make a difference.",
                            order = 55,
                        },
                        notable_shared = {
                            type = "toggle",
                            name = "Shared loot is notable",
                            desc = "Some rares have a common pool of drops that're shared between them. When this is checked, that shared loot will count for notability.",
                            order = 60,
                        },
                    },
                    order = 50,
                },
            },
        },
        data = {
            name = "Data",
            type = "group",
            args = {
                achievementsHidden = {
                    type = "multiselect",
                    name = "Show achievements",
                    desc = "Toggle whether you want to show points for a given achievement",
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.achievement and not values[point.achievement] then
                                    local _, achievement = GetAchievementInfo(point.achievement)
                                    values[point.achievement] = achievement or ('achievement:'..point.achievement)
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    hidden = function(info)
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.achievement then
                                    info.option.hidden = nil
                                    return ns.options.hidden(info)
                                end
                            end
                        end
                        info.option.hidden = true
                        return true
                    end,
                    order = 30,
                },
                zonesHidden = {
                    type = "multiselect",
                    name = "Show in zones",
                    desc = "Toggle whether you want to show points in a given zone",
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID in pairs(ns.points) do
                            if not values[uiMapID] then
                                local info = C_Map.GetMapInfo(uiMapID)
                                if info and (
                                    info.mapType == Enum.UIMapType.Zone or
                                    info.mapType == Enum.UIMapType.Continent or
                                    info.mapType == Enum.UIMapType.World
                                ) then
                                    -- zones only
                                    values[uiMapID] = info.name
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    order = 35,
                },
                groupsHidden = {
                    type = "multiselect",
                    name = "Show groups",
                    desc = "Toggle whether to show certain groups of points",
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.group and not values[point.group] then
                                    values[point.group] = ns.render_string(ns.groups[point.group] or point.group)
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    hidden = function(info)
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.group then
                                    info.option.hidden = nil
                                    return ns.options.hidden(info)
                                end
                            end
                        end
                        info.option.hidden = true
                        return true
                    end,
                    order = 40,
                },
            },
        },
    },
}
