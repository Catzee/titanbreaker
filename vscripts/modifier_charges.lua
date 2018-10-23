modifier_charges = class({})

if IsServer() then
    function modifier_charges:Update()
        if self:GetDuration() == -1 then
            local cdr = GetCooldownReductionFactor( self:GetParent(), self:GetAbility() )
            local thinkTime = self.kv.replenish_time * cdr
            if self.kv and self.kv.replenish_time_per_level and self:GetAbility() then
                thinkTime = (self.kv.replenish_time - self.kv.replenish_time_per_level * (self:GetAbility():GetLevel() - 1)) * cdr
            end
            self:SetDuration(thinkTime, true)
            self:StartIntervalThink(thinkTime)
        end

        if self:GetStackCount() == 0 then
            self:GetAbility():StartCooldown(self:GetRemainingTime())
        end
    end

    function modifier_charges:OnCreated(kv)
        self:SetStackCount(kv.start_count or kv.max_count)
        self.kv = kv

        if kv.start_count and kv.start_count ~= kv.max_count then
            self:Update()
        end
    end

    function modifier_charges:DeclareFunctions()
        local funcs = {
            MODIFIER_EVENT_ON_ABILITY_EXECUTED
        }

        return funcs
    end

    function modifier_charges:OnAbilityExecuted(params)
        if params.unit == self:GetParent() then
            local ability = params.ability

            if params.ability == self:GetAbility() then
                self:DecrementStackCount()
                self:Update()
            end
        end

        return 0
    end

    function modifier_charges:OnIntervalThink()
        local stacks = self:GetStackCount()

        if stacks < self.kv.max_count then
            local cdr = GetCooldownReductionFactor( self:GetParent(), self:GetAbility() )
            local thinkTime = self.kv.replenish_time * cdr
            if self.kv and self.kv.replenish_time_per_level and self:GetAbility() then
                thinkTime = (self.kv.replenish_time - self.kv.replenish_time_per_level * (self:GetAbility():GetLevel() - 1)) * cdr
            end
            self:SetDuration(thinkTime, true)
            self:IncrementStackCount()

            if stacks == self.kv.max_count - 1 then
                self:SetDuration(-1, true)
                self:StartIntervalThink(-1)
            end
        end
    end
end

function modifier_charges:DestroyOnExpire()
    return false
end

function modifier_charges:IsPurgable()
    return false
end

function modifier_charges:RemoveOnDeath()
    return false
end

function modifier_charges:GetAttributes()
  return MODIFIER_ATTRIBUTE_MULTIPLE
end