local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_FIREDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_FIREAREA)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -0.7, -3, -1.1, 0)

local arr = {
{1, 1, 1},
{1, 1, 1},
{1, 1, 1},
{0, 1, 0},
{0, 3, 0},
}

local area = createCombatArea(arr)

combat:setArea(area)

function onCastSpell(creature, variant)
	return combat:execute(creature, variant)
end
