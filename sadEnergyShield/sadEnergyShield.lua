require "/scripts/status.lua"

function init()
    -- Initialisation des paramètres du bouclier à partir de l'effet de statut
    self.capacityBar = config.getParameter("capacityBar") -- Affichage de la barre de capacité du bouclier
	self.capacityBarFrameNum = config.getParameter("capacityBarFrameNum")
    self.shieldCapacity = config.getParameter("shieldCapacity") -- Capacité maximale du bouclier
    self.shieldRechargeRate = config.getParameter("shieldRechargeRate") -- Taux de recharge du bouclier en capacité par seconde
    self.shieldRechargeDelay = config.getParameter("shieldRechargeDelay") -- Délai avant le début de la recharge
	
	self.shieldHitDamageMin = config.getParameter("shieldHitDamageMin") -- 
    self.shieldHitDamageMax = config.getParameter("shieldHitDamageMax") -- 

    self.currentShield = self.shieldCapacity -- Initialisation de la capacité actuelle du bouclier
    self.previousShield = self.currentShield -- Ajout d'une variable pour suivre la capacité précédente du bouclier
    self.rechargeTimer = 0 -- Initialisation du timer de recharge
    self.recharging = false -- Indicateur de recharge en cours
    self.protectionActive = true -- Indicateur de la protection active
	
    self.genProtection = config.getParameter("genProtection", 0) * 100
    self.resistFire = config.getParameter("resistFire", 0) * 100
    self.immuFire = config.getParameter("immuFire", 0) * 100
    self.resistIce = config.getParameter("resistIce", 0) * 100
    self.immuIce = config.getParameter("immuIce", 0) * 100
    self.resistElectric = config.getParameter("resistElectric", 0) * 100
    self.immuElectric = config.getParameter("immuElectric", 0) * 100
    self.resistPoison = config.getParameter("resistPoison", 0) * 100
    self.immuPoison = config.getParameter("immuPoison", 0) * 100

    sb.logInfo("--------- Shield Total Capacity: %s", self.shieldCapacity)
    sb.logInfo("--------- Shield Current Capacity: %s", self.currentShield)
    sb.logInfo("--------- Shield Recharge Rate: %s", self.shieldRechargeRate)
    sb.logInfo("--------- Shield Recharge Delay: %s", self.shieldRechargeDelay)

    self.capacityBarProgress = math.floor(self.capacityBarFrameNum - ((self.currentShield * self.capacityBarFrameNum) / self.shieldCapacity))
	if (self.capacityBar == 1) then animator.setAnimationState("capabar", "capacityBarDmg" .. self.capacityBarProgress) end
	
	self.protectionModifierGroup = effect.addStatModifierGroup({
        {stat = "protection", amount = self.genProtection},
        {stat = "fireStatusImmunity", amount = self.immuFire},
        {stat = "fireResistance", amount = self.resistFire},
        {stat = "iceStatusImmunity", amount = self.immuIce},
        {stat = "iceResistance", amount = self.resistIce},
        {stat = "electricStatusImmunity", amount = self.immuElectric},
        {stat = "electricResistance", amount = self.resistElectric},
        {stat = "poisonStatusImmunity", amount = self.immuPoison},
        {stat = "poisonResistance", amount = self.resistPoison},
    })

    self.listener = damageListener("damageTaken", function(notifications)
        for _, notification in pairs(notifications) do
            sb.logInfo("--------- Notification: %s", notification)
            -- Forcing damageDealt for testing purposes
            local damage = notification.healthLost
            if (damage == 0) then damage = math.random(self.shieldHitDamageMin, self.shieldHitDamageMax) end-- Forcing a damage value for testing
			
            local sourceEntityId = notification.sourceEntityId
            local targetEntityId = notification.targetEntityId
            local damageSourceKind = notification.damageSourceKind
            local hitType = notification.hitType

            sb.logInfo("--------- Source Entity ID: %s", sourceEntityId)
            sb.logInfo("--------- Target Entity ID: %s", targetEntityId)
            sb.logInfo("--------- Damage Source Kind: %s", damageSourceKind)
            sb.logInfo("--------- Hit Type: %s", hitType)
            sb.logInfo("--------- Damage Taken: %s", damage)
			
            if (damage > 0) then
                if (self.currentShield > 0) then
                    self.currentShield = math.max(0, self.currentShield - damage) -- Réduction de la capacité du bouclier
                    sb.logInfo("--------- Shield Current Capacity after hit: %s", self.currentShield)

                    if (self.currentShield == 0) then
                        animator.setAnimationState("shield", "depleted")
                        sb.logInfo("--------- Shield Depleted")
                        effect.setStatModifierGroup(self.protectionModifierGroup, {
                            {stat = "protection", amount = 0},
                            {stat = "fireStatusImmunity", amount = 0},
                            {stat = "fireResistance", amount = 0},
                            {stat = "iceStatusImmunity", amount = 0},
                            {stat = "iceResistance", amount = 0},
                            {stat = "electricStatusImmunity", amount = 0},
                            {stat = "electricResistance", amount = 0},
                            {stat = "poisonStatusImmunity", amount = 0},
                            {stat = "poisonResistance", amount = 0},
                        })
                        self.protectionActive = false
                    else
                        animator.setAnimationState("shield", "hit")
                    end

                    self.rechargeTimer = self.shieldRechargeDelay
                    self.recharging = false
                else
                    self.rechargeTimer = self.shieldRechargeDelay -- Réinitialise le timer de recharge si des dégâts sont subis
                    sb.logInfo("--------- Recharge Interrupted, Timer Reset")
                end
            end
        end
    end)
end

function update(dt)	
	self.listener:update()

    if (self.currentShield < self.shieldCapacity) then
        self.capacityBarProgress = math.floor(self.capacityBarFrameNum - ((self.currentShield * self.capacityBarFrameNum) / self.shieldCapacity))
		
		if (self.rechargeTimer > 0) then
            self.rechargeTimer = self.rechargeTimer - dt
            sb.logInfo("--------- Recharge Timer: %s", self.rechargeTimer)
			
			if (self.capacityBar == 1) then animator.setAnimationState("capabar", "capacityBarDmg" .. self.capacityBarProgress) end
        else
            if (not self.recharging) then
                sb.logInfo("--------- Shield Recharging Started")
				if (self.previousShield == 0) then
					animator.setAnimationState("shield", "activation")
				end
                self.recharging = true
            end

            self.currentShield = math.min(self.shieldCapacity, self.currentShield + self.shieldRechargeRate * dt)
            sb.logInfo("--------- Shield Current Capacity during recharge: %s", self.currentShield)
            
            if (self.currentShield > 0 and not self.protectionActive) then
                effect.setStatModifierGroup(self.protectionModifierGroup, {
                    {stat = "protection", amount = self.genProtection},
                    {stat = "fireStatusImmunity", amount = self.immuFire},
                    {stat = "fireResistance", amount = self.resistFire},
                    {stat = "iceStatusImmunity", amount = self.immuIce},
                    {stat = "iceResistance", amount = self.resistIce},
                    {stat = "electricStatusImmunity", amount = self.immuElectric},
                    {stat = "electricResistance", amount = self.resistElectric},
                    {stat = "poisonStatusImmunity", amount = self.immuPoison},
                    {stat = "poisonResistance", amount = self.resistPoison},
                })
                self.protectionActive = true
            end
			
			if (self.capacityBar == 1) then animator.setAnimationState("capabar", "capacityBarDmg" .. self.capacityBarProgress) end
        end
    end

    -- Mise à jour de la variable de la capacité précédente du bouclier
    self.previousShield = self.currentShield
end
