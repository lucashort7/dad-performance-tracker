local M = {}

local _root_hook_path = "/Game/Pagoda/Characters/Player/Abilities"

M.ABILITIES = {
	CounterAttack = {
		index = 0,
		fullName = "GA_CounterAttack_C",
		friendlyName = "CounterAttack",
		shortName = "CTR",
		path = _root_hook_path .. "/Counter/GA_CounterAttack.GA_CounterAttack_C:HandleTargetReady",
	},
	Dodge = {
		index = 1,
		fullName = "GA_Dodge_C",
		friendlyName = "Dodge",
		shortName = "DDG",
		path = _root_hook_path .. "/Dodge/GA_Dodge.GA_Dodge_C:CheckPerfectDodge",
		hasParam = true,
	},
	BasicAttack = {
		index = 2,
		fullName = "GA_BasicAttack_C",
		friendlyName = "LightAttack",
		shortName = "AA",
		path = _root_hook_path .. "/BasicAttack/GA_BasicAttack.GA_BasicAttack_C:ExecuteUbergraph_GA_BasicAttack",
	},
	ContinuousAttack = {
		index = 3,
		fullName = "GA_BasicAttack_Continuous_C",
		friendlyName = "FeverRushAttack",
		shortName = "FVR",
		path = _root_hook_path
			.. "/ContinuousAttack/GA_BasicAttack_Continuous.GA_BasicAttack_Continuous_C:CreateHitInputs",
	},
	FollowUpAttack = {
		index = 4,
		fullName = "GA_BasicAttack_DodgeFollowup_C",
		friendlyName = "DodgeFollowUp",
		shortName = "AA_FU",
		path = _root_hook_path
			.. "/BasicAttack/GA_BasicAttack_DodgeFollowup.GA_BasicAttack_DodgeFollowup_C:HandleAttackStarted",
	},
	StrongAttack = {
		index = 5,
		fullName = "GA_Attack_Strong_C",
		friendlyName = "HeavyAttack",
		shortName = "STG",
		path = _root_hook_path .. "/Strong/GA_Attack_Strong.GA_Attack_Strong_C:HandleMontageHit",
	},
	RangedAttack = {
		index = 6,
		fullName = "GA_Player_DrummerangToss_C",
		friendlyName = "Drummerang",
		shortName = "RNG",
		path = _root_hook_path
			.. "/Ranged/GA_Player_DrummerangToss.GA_Player_DrummerangToss_C:ExecuteUbergraph_GA_Player_DrummerangToss",
	},
	RangedFollowUp = {
		index = 7,
		fullName = "GA_BasicAttack_GapCloser_C",
		friendlyName = "DrummerangFollowUp",
		shortName = "RNG_FU",
		path = _root_hook_path
			.. "/BasicAttack/GA_BasicAttack_GapCloser.GA_BasicAttack_GapCloser_C:BeginAttackSequence",
	},
	DanceMove = {
		index = 8,
		fullName = "GA_Player_Taunt_C",
		friendlyName = "DanceMove",
		shortName = "DNC",
		path = _root_hook_path .. "/GA_Player_Taunt.GA_Player_Taunt_C:ExecuteUbergraph_GA_Player_Taunt",
	},
}

function M.GetLabel(abilityKey, layoutType)
	local ability = M.ABILITIES[abilityKey]
	if not ability then
		return abilityKey
	end -- Fallback to abilityKey if not found

	if layoutType == "full" then
		return ability.fullName
	elseif layoutType == "friendly" then
		return ability.friendlyName
	else -- Default to shortname or if layoutType is "shortname"
		return ability.shortName
	end
end

return M
