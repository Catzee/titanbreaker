customSchema = class({})

function customSchema:init()

    -- Check the schema_examples folder for different implementations

    -- Flag Example
    statCollection:setFlags({   
        version = "6.0T",
        numPlayers = PlayerResource:GetPlayerCount(),
        map = GetMapName(),
     })

    -- Listen for changes in the current state
    ListenToGameEvent('game_rules_state_change', function(keys)
        local state = GameRules:State_Get()

        -- Send custom stats when the game ends
        if state == DOTA_GAMERULES_STATE_POST_GAME then

            -- Build game array
            local game = BuildGameArray()

            -- Build players array
            local players = BuildPlayersArray()

            -- Print the schema data to the console
            if statCollection.TESTING then
                PrintSchema(game, players)
            end

            -- Send custom stats
            if statCollection.HAS_SCHEMA then
                statCollection:sendCustom({ game = game, players = players })
            end
        end
    end, nil)
end

-------------------------------------

-- In the statcollection/lib/utilities.lua, you'll find many useful functions to build your schema.
-- You are also encouraged to call your custom mod-specific functions

-- Returns a table with our custom game tracking.
function BuildGameArray()
    local game = {}

    -- Add game values here as game.someValue = GetSomeGameValue()
    game.gl = math.floor(_G.COverthrowGameMode.GameMinutes) -- Game length, from the horn sound, in seconds
    game.rn = _G.COverthrowGameMode.RoundCounter - 1 -- Rounds played
    game.wt = _G.COverthrowGameMode.Winner -- Winning team

    -- calc healer ratio for both teams
    local healerratiot1 = math.floor((100 * _G.COverthrowGameMode.HealerTeamRatio[DOTA_TEAM_GOODGUYS] / (PlayerResource:GetPlayerCount() / 2)))
    --print("healerratiot1")
    --print(healerratiot1)
    local healerratiot2 = math.floor((100 * _G.COverthrowGameMode.HealerTeamRatio[DOTA_TEAM_BADGUYS] / (PlayerResource:GetPlayerCount() / 2)))
    --print("healerratiot2")
    --print(healerratiot2)

    game.hrpt1 = healerratiot1
    game.hrpt2 = healerratiot2


    return game
end

-- Returns a table containing data for every player in the game
function BuildPlayersArray()

    local healerratiot1 = math.floor((100 * _G.COverthrowGameMode.HealerTeamRatio[DOTA_TEAM_GOODGUYS] / (PlayerResource:GetPlayerCount() / 2)))
    local healerratiot2 = math.floor((100 * _G.COverthrowGameMode.HealerTeamRatio[DOTA_TEAM_BADGUYS] / (PlayerResource:GetPlayerCount() / 2)))

    local players = {}
    for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) then
            if not PlayerResource:IsBroadcaster(playerID) then

                local hero = PlayerResource:GetSelectedHeroEntity(playerID)

                -- Team string logic
                local player_team = ""
                local ratio = 0
                if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
                    player_team = "Team 1"
                    ratio = healerratiot1
                else
                    player_team = "Team 2"
                    ratio = healerratiot2
                end
                local heal = 0
                local dmg = 0

                --find all teammates and average numbers
                local all = HeroList:GetAllHeroes()
                local count = 0
                local healing = 0
                local damage = 0
                if hero.totaltimeplayed and hero.totaltimeplayed > 0 then
                    healing = math.floor(hero.totalhealingdone / hero.totaltimeplayed)
                    damage = math.floor(hero.totaldamagedone / hero.totaltimeplayed)
                end
                for i=1, #all do
                    if all[i] and all[i]:IsHero() and hero:GetTeam() == all[i]:GetTeam() then
                        if all[i].totaldamagedone and all[i].totalhealingdone and all[i].totaltimeplayed and all[i].totaltimeplayed > 0 then
                            heal = heal + all[i].totalhealingdone / all[i].totaltimeplayed
                            dmg = dmg + all[i].totaldamagedone / all[i].totaltimeplayed
                            count = count + 1
                        end
                    end
                end
                if count > 0 then
                    heal = math.floor(heal / count)
                    dmg = math.floor(dmg / count)
                end
                

                table.insert(players, {
                    -- steamID32 required in here
                    steamID32 = PlayerResource:GetSteamAccountID(playerID),

                    -- Example functions for generic stats are defined in statcollection/lib/utilities.lua
                    -- Add player values here as someValue = GetSomePlayerValue(),

                    ph = GetHeroNameGAA(hero), -- Hero by its short name
                    --pl = hero:GetLevel(), -- Hero level at the end of the game
                    --pnw = GetNetworth(hero), -- Sum of hero gold and item worth
                    --pbb = hero.buyback_count, -- Amount of buybacks performed during the game
                    pt = player_team, -- Team this hero belongs to
                    pk = hero:GetKills(), -- Number of kills of this players hero
                    pa = hero:GetAssists(), -- Number of deaths of this players hero
                    pd = hero:GetDeaths(), -- Number of deaths of this players hero
                    i1 = getItemNameGAA(hero,0), -- Item Slot #1
                    i2 = getItemNameGAA(hero,1), -- Item Slot #2
                    i3 = getItemNameGAA(hero,2), -- Item Slot #3
                    i4 = getItemNameGAA(hero,3), -- Item Slot #4
                    i5 = getItemNameGAA(hero,4), -- Item Slot #5
                    i6 = getItemNameGAA(hero,5), -- Item Slot #6
                    hr = ratio,
                    dps = damage,
                    hps = healing,
                    dpst = dmg,
                    hpst = heal,
                })
            end
        end
    end

    return players
end

-- Prints the custom schema, required to get an schemaID
function PrintSchema(gameArray, playerArray)
    print("-------- GAME DATA --------")
    DeepPrintTable(gameArray)
    print("\n-------- PLAYER DATA --------")
    DeepPrintTable(playerArray)
    print("-------------------------------------")
end

-- Write 'test_schema' on the console to test your current functions instead of having to end the game
if Convars:GetBool('developer') then
    Convars:RegisterCommand("test_schema", function() PrintSchema(BuildGameArray(), BuildPlayersArray()) end, "Test the custom schema arrays", 0)
end

-------------------------------------

-- If your gamemode is round-based, you can use statCollection:submitRound(bLastRound) at any point of your main game logic code to send a round
-- If you intend to send rounds, make sure your settings.kv has the 'HAS_ROUNDS' set to true. Each round will send the game and player arrays defined earlier
-- The round number is incremented internally, lastRound can be marked to notify that the game ended properly
function customSchema:submitRound(isLastRound)

    local winners = BuildRoundWinnerArray()
    local game = BuildGameArray()
    local players = BuildPlayersArray()

    statCollection:sendCustom({ game = game, players = players })

    isLastRound = isLastRound or false --If the function is passed with no parameter, default to false.
    return { winners = winners, lastRound = isLastRound }
end

-- A list of players marking who won this round
function BuildRoundWinnerArray()
    local winners = {}
    local current_winner_team = _G.COverthrowGameMode.Winner or 0 --You'll need to provide your own way of determining which team won the round
    for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) then
            if not PlayerResource:IsBroadcaster(playerID) then
                winners[PlayerResource:GetSteamAccountID(playerID)] = (PlayerResource:GetTeam(playerID) == current_winner_team) and 1 or 0
            end
        end
    end
    return winners
end

function getItemNameGAA(hero, slot)
    local item = hero:GetItemInSlot(slot)
    if item ~= nil then
        return item:GetName()
    else
        return "none"
    end
end

function GetHeroNameGAA(hero)
    if hero then
        local heroName = hero:GetUnitName()
        if heroName then
            heroName = string.gsub(heroName, "npc_dota_hero_", "")
        else 
            heroName = "unknown"
        end
        return heroName
    else
        heroName = "unknown"
        return heroName
    end

    return "unknown"
end