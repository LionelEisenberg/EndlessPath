## Introduction

This is the plan for the combat architecture, and in-game requirements for the MVP of the Combat system.

### Combat Flow

First and foremost, when the player starts an adventure, we must generate a resource manager for the player. This is because while the player uses those resources in the Combat system, the adventure system will also use those resources. [TOPIC REVIEW: This causes problems, one avenue of investigation is to see if, instead of just creating the resource manager and passing it around, we can create a whole new combatant node at the begining of an adventure and re-use it throughout combats.]. When creating the resources, we want those to be linked to the UI's CharacterInfoPanel, visible wether the adventure view or the combat view is active.

Combat begins when the player, in the adventure view, clicks on a tile who's encounter is of type CombatEncounter. This will trigger the AdventureView [@adventure_view.gd] to hide the adventure view, and show the combat view [@combat_view.gd]. At this point, we will start the combat with a passed in CombatEncounter [@combat_encounter.gd] which holds a pool of CombatantData that we will use to create the enemy combatant. The player combatant will be created and setup with the players resource manager. The AdventureCombat will then begin the combat loop:
- Enemy, cast ability on cooldown 
- Player, have access to ability bar, each ability has cooldowns and uses resources, click on ability in ability bar to use ability on enemy combatant
- When ability is used, it damages enemy

When either combatantnode dies, the combat is over with a success or a failure, player resources should stay updated throughout combat and continue for the rest of the adventure. The AdventureCombat will then hide the combat view, and show the adventure view.

### Current Architecture

Here are the current components that go into the combat system:

AdventureView [Node] - Handles switching between the adventure tilemap view and adventure combat view. Currently is what initializes the combat system, as well as the player resource manager at the beginning of the adventure.
--TilemapView [Node] - Handles the tilemap view of the adventure [OUT OF SCOPE FOR THE COMBAT SECTION]
--CombatView [Node] - Handles the combat view of the adventure. [Currently no logic lives here]
---AdventureCombat [Node] - Handles the combat loop and initialization of combatants.
----PlayerCombatant [CombatantNode] - Handles the player combatant.
----EnemyCombatant [CombatantNode] - Handles the enemy combatant.
----CanvasLayer [CanvasLayer] - Handles the canvas layer for the combat view.
-----AbilityBar [Panel] - Handles the ability bar for the player.
------AbilityButton [Button] - Handles the ability buttons for the player.
--CharacterInfoPanel [Panel] - Handles the Resource Manager display for the player.

And the CombatantNode [@combatant_node.gd] is the base class for both the player and enemy combatants. It looks like:

CombatantNode [CombatantNode] - Handles the combatant node.
--CombatantResourceManager [CombatantResourceManager] - resource manager for the combatant. Handles changing health, madra and stamina for the given combatant.
--CombatantAbilityManager [CombatantAbilityManager] - ability manager for the combatant. Initializes the AbilityBar, keeps track of ability cooldown and handles ability use including resource cost and cooldown.
---CombatAbilityInstance [CombatAbilityInstance] - Handles the instance of an ability for the combatant. Linked to AbilityButton.
--CombatantEffectManager [CombatantEffectManager] - effect manager for the combatant. Handles processing effects received by the combatant from other combatants abilities.
--Sprite2D [Sprite2D] - Handles the sprite for the combatant.

Now the data structure are driving a lot of the logic in the combat system. Here is what drives what:

- character_atributes_data - holds character attributes for the combatant, read in by CharacterManager for the player
- character_abilities_data - holds character abilities for the combatant, read in by CharacterManager for the player
- combatant_data - holds combatant data for the combatants.
- ability_data - holds ability data for a given ability.
- combat_effect_data - holds effect data for a given effect.

### Logic Flow

-> AdventureView.start_adventure() gets called when ActionManager starts adventure 
-> Create new CombatResourceManager set from players total CharacterAttributesData fetched from CharacterManager -> Initialize AdventureCombat with CombatEncounter & player resource manager 
-> AdventureCombat.start_combat() the player combatant with the player resource manager:
	-> player combatant initialized with player resource manager (The passed Node is used directly)
	-> ability manager setup with player CombatantData fetched from CharacterManager which includes CharacterAbilitiesData & CharacterAttributesData
		-> For each ability in player CombatantData, create a new CombatAbilityInstance and ability button for the ability and connect signals from the instance to the button and the button to the instance
	-> effect manager setup with player CombatantData fetched from CharacterManager which includes CharacterAbilitiesData & CharacterAttributesData
	-> sprite set to player sprite from the combatant data
-> AdventureCombat.start_combat() the enemy combatant:
	-> Everything goes the same way as with the Player but uses all the data in the combatant data instead of getting anything from the CharacterManager
-> Player clicks on ability in ability bar:
	-> button sends signal to ability manager
	-> ability manager checks if ability can be used (Check Resources, Check Cooldown)
	-> If ability can be used, ability manager uses ability by calling ability.use(target) on the ability instance
		-> ability manager decreases resource manager resources
		-> ability instance creates a timer for the ability cooldown and starts this timer
		-> ability instance signals `cooldown_started`, `cooldown_updated`, and `cooldown_ready` to the associated button
		-> ability instance applies effects to the target via target.receive_effect()

### Functional Call Flow

```
mermaid
sequenceDiagram
	participant User
	participant UI as AbilityButton
	participant AM as CombatAbilityManager
	participant AI as CombatAbilityInstance
	participant RM as CombatResourceManager
	participant Target as EnemyCombatant
	participant EM as CombatEffectManager

	User->>UI: Click Ability
	UI->>AM: signal pressed(ability_index)
	
	Note over AM: Check Resources & Cooldown
	
	alt Resources Available & Cooldown Ready
		AM->>RM: consume_resources(cost)
		AM->>AI: use(target_combatant)
		
		activate AI
		AI->>AI: start_cooldown_timer()
		AI->>UI: signal cooldown_started(duration)
		
		loop Cooldown Timer
			AI->>UI: signal cooldown_updated(time_left)
		end
		
		AI->>Target: receive_effect(effect_data, source_attributes)
		deactivate AI
		
		activate Target
		Target->>EM: process_effect(effect_data, source_attributes)
		
		activate EM
		EM->>EM: calculate_value(source_attributes, target_attributes)
		EM->>RM: apply_change(final_value)
		deactivate EM
		
		deactivate Target
		
		Note over AI: Timer Finishes
		AI->>UI: signal cooldown_ready()
		
	else Not Enough Resources or On Cooldown
		AM-->>UI: (Optional) signal error/feedback
	end
```
