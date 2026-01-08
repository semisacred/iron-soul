Scriptname DragonsoulUnapply extends ActiveMagicEffect

Spell Property DRAbility Auto
Spell Property DROnDying Auto
Quest Property DRQuest Auto

Event OnEffectStart(Actor Target, Actor Caster)

    ;Debug.Notification("Potion EndDeferredKill")

    if Target.HasSpell(DRAbility) && Target.HasSpell(DROnDying)

        Target.GetActorbase().SetEssential(true)
        Target.EndDeferredKill()
        Target.DamageAV("health", Target.GetAVMax("Health")+999)
        Utility.Wait(3)
        Target.RestoreAV("health", 1000)
        Target.GetActorbase().SetEssential(false)

        Target.RemoveSpell(DRAbility)
        Target.RemoveSpell(DROnDying)
        DRQuest.Stop()

    else

        DRQuest.Start()

    endif


Endevent