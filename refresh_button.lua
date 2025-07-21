local refreshUrl = "https://raw.githubusercontent.com/TheIndependentBrotherhood/tts-pkmn-master-trainer-hex/refs/heads/main/refresh_button.png"

-- Ajoute un cache buster à chaque URL
function addCacheBuster(url)
    return url .. "?v=" .. os.time() .. "_" .. math.random(100000,999999)
end

-- Utilitaire pour positionner proprement chaque carte au-dessus du deck
function getStackedPosition(base, i)
    return { base[1], base[2] + 2 + i * 0.4, base[3] }
end

-- Variable globale pour suivre la dernière pile créée/fusionnée
lastContainer = nil

function onLoad()
    self.createButton({
        label = "",
        click_function = "reloadAllAssets",
        function_owner = self,
        position = {0, 0.2, 0},
        width = 1000,
        height = 1000,
        font_size = 1,
        color = {0,0,0,0},
        hover_color = {0,0,0,0},
        press_color = {0,0,0,0},
        tooltip = "Reload Cache"
    })
end

function logDebug(msg, color)
    printToAll("[DEBUG] "..msg, color or {1,1,0})
end

-- Patch forceReloadCustomObject pour cache busting
function forceReloadCustomObject(obj, cb)
    if not obj or not obj.getCustomObject then
        logDebug("forceReloadCustomObject: obj is invalid", {1,0,0})
        if cb then cb(obj) end
        return
    end
    local custom = obj.getCustomObject()
    if not custom then
        logDebug("forceReloadCustomObject: custom is nil", {1,0,0})
        if cb then cb(obj) end
        return
    end

    local urlKey
    if custom.image then urlKey = "image"
    elseif custom.face then urlKey = "face"
    elseif custom.mesh then urlKey = "mesh"
    elseif custom.diffuse then urlKey = "diffuse"
    end
    if not urlKey then
        logDebug("forceReloadCustomObject: urlKey is nil", {1,0,0})
        if cb then cb(obj) end
        return
    end

    local originalUrl = custom[urlKey]
    if not originalUrl then
        logDebug("forceReloadCustomObject: originalUrl is nil", {1,0,0})
        if cb then cb(obj) end
        return
    end

    local tempCustom = {}
    for k, v in pairs(custom) do tempCustom[k] = v end
    tempCustom[urlKey] = addCacheBuster(refreshUrl)
    obj.setCustomObject(tempCustom)

    Wait.time(function()
        local resetCustom = {}
        for k, v in pairs(custom) do resetCustom[k] = v end
        resetCustom[urlKey] = addCacheBuster(originalUrl)
        obj.setCustomObject(resetCustom)
        logDebug("forceReloadCustomObject: Reloaded "..(obj.getName() or obj.getGUID()))
        if cb then cb(obj) end
    end, 0.6)
end

function onObjectEnterContainer(container, obj)
    -- Callback appelé dès qu'une carte rejoint une pile/deck
    lastContainer = container
    logDebug("onObjectEnterContainer: container="..container.getGUID().." obj="..obj.getGUID(), {0,1,0})
end

-- Rafraîchit chaque carte d'un deck custom, discrètement (empilement vertical)
function forceReloadAllCardsInDeck(deck, afterDeckCb)
    if not deck or not deck.getObjects then
        logDebug("forceReloadAllCardsInDeck: not a deck", {1,0,0})
        if afterDeckCb then afterDeckCb() end
        return
    end
    local cards = deck.getObjects()
    if not cards or #cards == 0 then
        logDebug("forceReloadAllCardsInDeck: deck is empty", {1,0,0})
        if afterDeckCb then afterDeckCb() end
        return
    end
    local pos = deck.getPosition()
    local extractedCards = {}
    local total = #cards
    local done = 0

    local function onCardRefreshed(cardObj, idx)
        table.insert(extractedCards, cardObj)
        done = done + 1
        if done == total then
            logDebug("Toutes les cartes du deck ont été rafraîchies.")
            Wait.time(function()
                for i, c in ipairs(extractedCards) do
                    c.lock()
                    c.setPositionSmooth(getStackedPosition(pos, i), false, true)
                end
                Wait.time(function()
                    for _, c in ipairs(extractedCards) do c.unlock() end
                    logDebug("Pile reconstituée.")
                    if afterDeckCb then afterDeckCb() end
                end, 1.1)
            end, 1.2)
        end
    end

    deck.shuffle()
    for i, cardData in ipairs(cards) do
        deck.takeObject({
            index = 0,
            position = getStackedPosition(pos, i),
            smooth = false,
            callback_function = function(cardObj)
                cardObj.lock()
                Wait.time(function()
                    forceReloadCustomObject(cardObj, function(c)
                        c.setPositionSmooth(getStackedPosition(pos, i), false, true)
                        -- unlock/remise dans la pile une fois tout le deck traité (voir plus haut)
                        onCardRefreshed(c, i)
                    end)
                end, 0.5)
            end
        })
    end
end

function reloadDeckOneByOne(deck, basePos, doneCb)
    -- PATCH : pour les decks de cartes custom fusionnées, on les traite individuellement et proprement
    forceReloadAllCardsInDeck(deck, doneCb)
end

function reloadAllAssets(obj, player_color)
    local player = Player[player_color]
    local who = player_color
    if player and player.steam_name then who = player.steam_name end
    printToAll("Full reload triggered by " .. who, {1,1,1})

    -- Reload all custom objects on the table (except decks)
    for _, o in ipairs(getAllObjects()) do
        if o and o.getCustomObject and o.getCustomObject() and o.tag ~= "Deck" then
            local name = o.getName and o:getName() or "(no name)"
            if not name or name == "" then name = "(no name)" end
            logDebug("Forcing reload of custom object: " .. name)
            forceReloadCustomObject(o)
        end
    end

    -- Handle decks one by one, synchronously
    local decks = {}
    for _, o in ipairs(getAllObjects()) do
        if o and o.tag == "Deck" and o.getObjects then table.insert(decks, o) end
    end
    local basePos = self.getPosition and self.getPosition() or {0,2,0}

    local function processNextDeck(idx)
        if idx > #decks then
            broadcastToAll("Attempted to force reload all custom object assets!", {1,1,1})
            return
        end
        local deck = decks[idx]
        local deckName = deck.getName and deck:getName() or "(no name)"
        logDebug("Deck found: " .. deckName, {0.6,0.9,0.9})
        reloadDeckOneByOne(deck, basePos, function()
            logDebug("Deck reloaded: " .. deckName, {0.5,1,0.5})
            processNextDeck(idx + 1)
        end)
    end

    processNextDeck(1)
end