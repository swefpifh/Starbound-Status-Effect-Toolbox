require "/scripts/status.lua"

function init()
  -- Initialisation des paramètres
  self.statusEffectEnable = tonumber(config.getParameter("statusEffectEnable", 1))  -- Force la conversion en nombre
  self.statusEffectID = config.getParameter("statusEffectID", "glow")
  self.treasurePoolsID = config.getParameter("treasurePoolsID")
  
  -- Initialiser la variable pour vérifier si tué par le joueur
  self.killedByPlayer = false
  self.spawnedItem = false
  
  -- Enregistrer la fonction onDamageTaken pour vérifier les dommages reçus
  script.setUpdateDelta(1)
  self.damageNotification = damageListener("damageTaken", function(notifications)
    for _, notification in pairs(notifications) do
      if notification.healthLost > 0 and notification.sourceEntityId and world.entityType(notification.sourceEntityId) == "player" then
        self.killedByPlayer = true
      end
    end
  end)
end

function update(dt)
  -- Appliquer l'effet de statut si activé
  if self.statusEffectEnable == 1 then
    status.addEphemeralEffect(self.statusEffectID)
  end

  self.damageNotification:update()
  -- Vérification de la mort de l'entité
  if not status.resourcePositive("health") and not self.spawnedItem then
    die()
  end
end

function die()
  if self.killedByPlayer and not self.spawnedItem then
    spawnItemFromTreasurePool()
    self.spawnedItem = true
  end
end

function spawnItemFromTreasurePool()
  local position = entity.position()
  local items = root.createTreasure(self.treasurePoolsID, world.threatLevel())

  for _, item in ipairs(items) do
    world.spawnItem(item, position)
  end
end
