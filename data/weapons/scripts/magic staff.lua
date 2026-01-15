local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ENERGY)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -0.6, 0, -0.2, 0)

function onUseWeapon(player, variant)
    return combat:execute(player, variant)
end
