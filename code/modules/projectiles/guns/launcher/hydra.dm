/obj/item/gun/launcher/hydra
	name = "hydra launcher"
	desc = "Featuring prototype rapid fabrication technology and a chemical input system, the VMXL-022 'HYDRA' chemical launcher is capable of firing microgrenades filled with chemical \
	smoke at over 600 feet per second. It's also in violation of several interstellar treaties regarding chemical warfare, but who's keeping count?"
	icon_state = "hydra"
	item_state = "riotgun"
	origin_tech = list(TECH_COMBAT = 4, TECH_MATERIAL = 5, TECH_BIO = 5, TECH_ESOTERIC = 3)
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BELT
	force = 7

	fire_sound = 'sound/weapons/empty.ogg'
	fire_sound_text = "a whirr, followed by a thunk-hiss"
	screen_shake = 0
	throw_distance = 7
	release_force = 5
	fire_delay = 12

	///For attack log purposes, we'll track the last fired grenade
	var/obj/item/grenade/chem_grenade/microgrenade/micro = null

	var/container_type = /obj/item/reagent_containers/glass/beaker/vial
	var/obj/item/reagent_containers/active_container
	var/list/containers = list()

	/// Two max non-selected containers, plus one selected.
	var/max_containers = 2

	/**
	* Healchems, painkillers, misc medicine and teargas/water. The reason we have this is because chemsmoke is hilariously, painfully broken when used offensively.
	*
	* Be very, very careful when adding things to this list.
	*/
	var/allowed_reagents = list(
		/datum/reagent/inaprovaline,
		/datum/reagent/bicaridine,
		/datum/reagent/kelotane,
		/datum/reagent/dermaline,
		/datum/reagent/dylovene,
		/datum/reagent/dexalin,
		/datum/reagent/dexalinp,
		/datum/reagent/tricordrazine,
		/datum/reagent/paracetamol,
		/datum/reagent/tramadol,
		/datum/reagent/nanoblood,
		/datum/reagent/hyronalin,
		/datum/reagent/alkysine,
		/datum/reagent/rezadone,
		/datum/reagent/adminordrazine,
		/datum/reagent/capsaicin,
		/datum/reagent/water
		)
	matter = list(MATERIAL_PLASTIC = 6000, MATERIAL_GLASS = 3000)

/// Swap between loaded containers.
/obj/item/gun/launcher/hydra/proc/pump(mob/M)
	var/obj/item/reagent_containers/next = null
	if (length(containers))
		next = containers[1]
	if (active_container)
		containers += active_container //Switch selected container
		active_container = null
	if (next)
		containers -= next //Remove container from loaded list.
		active_container = next
		to_chat(M, SPAN_WARNING("You switch [src] to draw from \the [next]. Reagents remaining: [next.reagents.total_volume]."))
	else if (active_container)
		to_chat(M, SPAN_WARNING("\The [src] is drawing from \the [active_container]. Reagents remaining: [active_container.reagents.total_volume]."))
	else
		to_chat(M, SPAN_WARNING("\The [src] is empty."))
	update_icon()

/obj/item/gun/launcher/hydra/examine(mob/user, distance)
	. = ..()
	if (distance <= 2)
		var/container_count = length(containers) + (active_container? 1 : 0)
		to_chat(user, "Has [container_count] container\s loaded.")
		if (active_container)
			to_chat(user, "\A [active_container] is selected. Reagents remaining: [active_container.reagents.total_volume].")

/obj/item/gun/launcher/hydra/proc/load(cont_type, mob/user)
	if (length(containers) >= max_containers)
		to_chat(user, SPAN_WARNING("\The [src] is full."))
		return
	if (!user.unEquip(cont_type, src))
		return
	containers.Insert(1, cont_type) //add to the head of the list, so that it is loaded on the next pump
	user.visible_message(
	SPAN_NOTICE("\The [user] inserts \a [cont_type] into \the [src]."),
	SPAN_NOTICE("You insert \a [cont_type] into \the [src].")
	)

/obj/item/gun/launcher/hydra/proc/unload(mob/user)
	if (active_container)
		user.put_in_hands(active_container)
		user.visible_message(
		SPAN_NOTICE("\The [user] removes \a [active_container] from [src]."),
		SPAN_NOTICE("You remove \a [active_container] from \the [src].")
		)
		active_container = null
	else if (length(containers))
		var/vial = containers[length(containers)]
		LIST_DEC(containers)
		user.put_in_hands(vial)
		user.visible_message(
		SPAN_NOTICE("\The [user] removes \a [vial] from [src]."),
		SPAN_NOTICE("You remove \a [vial] from \the [src].")
		)
	else
		to_chat(user, SPAN_WARNING("\The [src] is empty."))

/obj/item/gun/launcher/hydra/attack_self(mob/user)
	pump(user)


/obj/item/gun/launcher/hydra/use_tool(obj/item/tool, mob/user, list/click_params)
	//Container - load.
	if (istype(tool, container_type))
		if (tool.reagents.total_volume >= 10)
			for (var/datum/reagent/current as anything in tool.reagents.reagent_list)
				if (!is_type_in_list(current, allowed_reagents))
					to_chat(user, SPAN_WARNING("\The [src]'s reagent lock flashes red and refuses \the [tool]."))
					return TRUE
			load(tool, user)
			return TRUE
		else
			to_chat(user, SPAN_WARNING("\The [tool] doesn't have enough reagents to do this!"))
			return TRUE

	return ..()


/obj/item/gun/launcher/hydra/attack_hand(mob/user)
	if (user.get_inactive_hand() == src)
		unload(user)
	else
		..()

/obj/item/gun/launcher/hydra/consume_next_projectile()
	if (active_container)
		var/obj/item/grenade/chem_grenade/microgrenade/micro = new (src)
		if (micro.beaker_1)
			active_container.reagents.trans_to_obj(micro.beaker1, 10) //Move 10u into the microgrenade...
			micro.activate(null)
			return micro //... and fire!
		else
			crash_with({"[src] attempted to fire with no contained grenade"})
			return null
	else
		return null //No container loaded.

/obj/item/gun/launcher/hydra/handle_post_fire(mob/user)
	if(micro)
		var/reagent_list = null
		for (var/datum/reagent/medicine in micro.beaker_1.reagents)
			if(istype(medicine, /datum/reagent/sugar)) //Skip sugar, which comes in there automatically as part of the smoke
				continue
			reagent_list += medicine
		admin_attacker_log(user, "fired a chemical smoke grenade from a microgrenade launcher, containing [reagent_list].")
	else
		crash_with({"[src] fired with no contained grenade"}) //There's a grenade, but no contents.

	if (!active_container.reagents || active_container.reagents.total_volume < 10) //If there's not enough for another shot...
		active_container.dropInto(loc) //Auto-eject the container.
		visible_message(
		SPAN_NOTICE("\The [src] automatically ejects \the [active_container].")
		)
		playsound(src, "sound/weapons/empty.ogg", 100, 1)
		active_container = null
		pump(user)

	..()

/obj/item/grenade/chem_grenade/microgrenade
	name = "microgrenade"
	desc = "A tiny grenade synthesised from an internal fabricator, full of chemical smoke."
	path = 1
	stage = 2
	affected_area = 2 //Smaller than regular chemnades.
	icon_state = "microgrenade"
	/// So we can check beaker1/beaker2 when loading the grenade.
	var/obj/item/reagent_containers/glass/beaker/beaker1 = null
	var/obj/item/reagent_containers/glass/beaker/beaker2 = null


/obj/item/grenade/chem_grenade/microgrenade/Initialize()
	. = ..()
	beaker1 = new (src)
	beaker2 = new (src)
	beaker1.reagents.add_reagent(/datum/reagent/sugar, 3) //Smoke, 9u
	beaker2.reagents.add_reagent(/datum/reagent/potassium, 3) //Plus 10u reagent from the container. Doesn't sound like much...
	beaker2.reagents.add_reagent(/datum/reagent/phosphorus, 3) //... but chemsmoke is wild. Any more and we'd risk ODing the patient.
	detonator = new /obj/item/device/assembly_holder/timer_igniter/hydra (src)
	beakers += beaker1
	beakers += beaker2

/obj/item/device/assembly_holder/timer_igniter/hydra
	default_time = 3 //Quicker detonation (default is 5).