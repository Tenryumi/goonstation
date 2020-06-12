/*
What are the archived variables for?
	Calculations are done using the archived variables with the results merged into the regular variables.
	This prevents race conditions that arise based on the order of tile processing.
*/

/datum/gas
	var/moles = 0
#ifdef ATMOS_ARCHIVING
	var/ARCHIVED(moles) = 0
#endif
	var/specific_heat = 0

/datum/gas/sleeping_agent
	specific_heat = 40
/datum/gas/oxygen_agent_b
	specific_heat = 300
/datum/gas/volatile_fuel
	specific_heat = 30
/datum/gas/rad_particles
	specific_heat = 20


/datum/gas_mixture
	#define _DEFINE_GAS(GAS, ...) var/GAS = 0;
	APPLY_TO_GASES(_DEFINE_GAS)
	#undef _DEFINE_GAS

#ifdef ATMOS_ARCHIVING
	#define _DEFINE_ARCH_GAS(GAS, ...) var/tmp/GAS;
	APPLY_TO_ARCHIVED_GASES(_DEFINE_ARCH_GAS)
	#undef _DEFINE_ARCH_GAS
#endif

	var/temperature = 0
#ifdef ATMOS_ARCHIVING
	var/tmp/ARCHIVED(temperature)
#endif

	var/volume = CELL_VOLUME
	var/group_multiplier = 1
	var/graphic
	var/tmp/graphic_archived // intentionally NOT using ARCHIVED() because graphic archiving is actually important and shouldn't be turned off
	var/list/datum/gas/trace_gases
	var/tmp/fuel_burnt = 0


// Overrides
/datum/gas_mixture/disposing()
	if (trace_gases)
		trace_gases = null
	..()

/datum/gas_mixture/New()
	..()
	total_gas_mixtures++


/datum/gas_mixture/unpooled()
	trace_gases = initial(trace_gases)
	volume = initial(volume)
	temperature = initial(temperature)
	group_multiplier = initial(group_multiplier)
	graphic = initial(graphic)
#ifdef ATMOS_ARCHIVING
	ARCHIVED(temperature) = initial(ARCHIVED(temperature))
#endif
	graphic_archived = initial(graphic_archived)
	fuel_burnt = initial(fuel_burnt)
	trace_gases = initial(trace_gases)
	#define _UNPOOL_GAS(GAS, ...) GAS = initial(GAS);
	APPLY_TO_GASES(_UNPOOL_GAS)
#ifdef ATMOS_ARCHIVING
	APPLY_TO_ARCHIVED_GASES(_UNPOOL_GAS)
#endif
	#undef _UNPOOL_GAS
	..()

// Mutator procs
// For specific events
/datum/gas_mixture/proc/zero()
	trace_gases = null
	ZERO_BASE_GASES(src)
	if (map_currently_underwater)
		oxygen = MOLES_O2STANDARD * 0.5
		nitrogen = MOLES_N2STANDARD * 0.5
		temperature = OCEAN_TEMP

/datum/gas_mixture/proc/vacuum() //yknow, for when you want "zero" to actually mean "zero".
	trace_gases = null
	ZERO_BASE_GASES(src)


/datum/gas_mixture/proc/check_tile_graphic()
	//returns 1 if graphic changed
	graphic = ""

	if(toxins > MOLES_PLASMA_VISIBLE)
		graphic += "plasma;"
	else if(length(trace_gases))
		var/datum/gas/sleeping_agent = locate(/datum/gas/sleeping_agent) in trace_gases
		if(sleeping_agent && (sleeping_agent.moles > 1))
			graphic += "n2o;"
		var/datum/gas/rad_particles = locate(/datum/gas/rad_particles) in trace_gases
		if(rad_particles && (rad_particles.moles > 1))
			graphic += "n2o;"
	. = graphic != graphic_archived
#ifndef ATMOS_ARCHIVING
	graphic_archived = graphic
#endif

/datum/gas_mixture/proc/react(atom/dump_location)
	var/reacting = 0 //set to 1 if a notable reaction occured (used by pipe_network)

	if(length(trace_gases) > 0)
		if(temperature > 900)
			if(toxins > MINIMUM_HEAT_CAPACITY && carbon_dioxide > MINIMUM_HEAT_CAPACITY)
				var/datum/gas/oxygen_agent_b/trace_gas = locate(/datum/gas/oxygen_agent_b/) in trace_gases
				if(trace_gas)
					var/reaction_rate = min(carbon_dioxide*0.75, toxins*0.25, trace_gas.moles*0.05)

					carbon_dioxide -= reaction_rate
					oxygen += reaction_rate

					trace_gas.moles -= reaction_rate*0.05

					temperature += (reaction_rate*20000)/HEAT_CAPACITY(src)

					reacting = 1

	if(temperature > 900 && farts && toxins > MINIMUM_HEAT_CAPACITY && carbon_dioxide > MINIMUM_HEAT_CAPACITY)
		var/reaction_rate = min(carbon_dioxide*0.75, toxins*0.25, farts*0.05)

		carbon_dioxide -= reaction_rate
		toxins += reaction_rate

		farts -= reaction_rate*0.05

		temperature += (reaction_rate*10000)/HEAT_CAPACITY(src)

		reacting = 1

	fuel_burnt = 0
	if(temperature > FIRE_MINIMUM_TEMPERATURE_TO_EXIST)
		if(fire() > 0)
			reacting = 1

	return reacting

/datum/gas_mixture/proc/fire()
	var/energy_released = 0
	var/old_heat_capacity = HEAT_CAPACITY(src)

	if(length(trace_gases))
		var/datum/gas/volatile_fuel/fuel_store = locate(/datum/gas/volatile_fuel/) in trace_gases
		if(fuel_store) //General volatile gas burn
			var/burned_fuel = 0

			if(oxygen < fuel_store.moles)
				burned_fuel = oxygen
				fuel_store.moles -= burned_fuel
				oxygen = 0
			else
				burned_fuel = fuel_store.moles
				oxygen -= fuel_store.moles
				//qdel(fuel_store)
				trace_gases -= fuel_store
				if(!trace_gases.len)
					trace_gases = null
				fuel_store = null

			energy_released += FIRE_CARBON_ENERGY_RELEASED * burned_fuel
			carbon_dioxide += burned_fuel
			fuel_burnt += burned_fuel

	//Handle plasma burning
	if(toxins > MINIMUM_HEAT_CAPACITY)
		var/plasma_burn_rate = 0
		var/oxygen_burn_rate = 0
		//more plasma released at higher temperatures
		var/temperature_scale
		if(temperature > PLASMA_UPPER_TEMPERATURE)
			temperature_scale = 1
		else
			temperature_scale = (temperature-PLASMA_MINIMUM_BURN_TEMPERATURE)/(PLASMA_UPPER_TEMPERATURE-PLASMA_MINIMUM_BURN_TEMPERATURE)
		if(temperature_scale > 0)
			oxygen_burn_rate = 1.4 - temperature_scale
			if(oxygen > toxins*PLASMA_OXYGEN_FULLBURN)
				plasma_burn_rate = (toxins*temperature_scale)/4
			else
				plasma_burn_rate = (temperature_scale*(oxygen/PLASMA_OXYGEN_FULLBURN))/4
			if(plasma_burn_rate > MINIMUM_HEAT_CAPACITY)
				toxins -= plasma_burn_rate/3
				oxygen -= plasma_burn_rate*oxygen_burn_rate
				carbon_dioxide += plasma_burn_rate/3

				energy_released += FIRE_PLASMA_ENERGY_RELEASED * (plasma_burn_rate)

				fuel_burnt += (plasma_burn_rate)*(1+oxygen_burn_rate)

	if(energy_released > 0)
		var/new_heat_capacity = HEAT_CAPACITY(src)
		if(new_heat_capacity > MINIMUM_HEAT_CAPACITY)
			temperature = (temperature*old_heat_capacity + energy_released)/new_heat_capacity

	return fuel_burnt

//Update archived versions of variables
//Returns: 1 in all cases
#ifdef ATMOS_ARCHIVING
/datum/gas_mixture/proc/archive()
	#define _ARCHIVE_GAS(GAS, ...) ARCHIVED(GAS) = GAS;
	APPLY_TO_GASES(_ARCHIVE_GAS)
	#undef _ARCHIVE_GAS
	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			trace_gas.ARCHIVED(moles) = trace_gas.moles
	ARCHIVED(temperature) = temperature
	graphic_archived = graphic
	return 1
#endif

//Similar to merge(...) but first checks to see if the amount of air assumed is small enough
//	that group processing is still accurate for source (aborts if not)
//Returns: 1 on successful merge, 0 if the check failed
/datum/gas_mixture/proc/check_then_merge(datum/gas_mixture/giver)
	if(!giver)
		return 0
	#define _ABOVE_SUSPEND_THRESHOLD(GAS, ...) ((giver.GAS > MINIMUM_AIR_TO_SUSPEND) && (giver.GAS >= GAS*MINIMUM_AIR_RATIO_TO_SUSPEND)) ||
	if(APPLY_TO_GASES(_ABOVE_SUSPEND_THRESHOLD) 0)
		return 0
	#undef _ABOVE_SUSPEND_THRESHOLD
	if(abs(giver.temperature - temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return 0

	if(length(giver.trace_gases))
		for(var/datum/gas/trace_gas in giver.trace_gases)
			var/datum/gas/corresponding
			if(length(trace_gases))
				corresponding = locate(trace_gas.type) in trace_gases
			if((trace_gas.moles > MINIMUM_AIR_TO_SUSPEND) && (!corresponding || (trace_gas.moles >= corresponding.moles*MINIMUM_AIR_RATIO_TO_SUSPEND)))
				return 0

	return merge(giver)

//Merges all air from giver into self. Deletes giver.
//Returns: 1 on success (no failure cases yet)
/datum/gas_mixture/proc/merge(datum/gas_mixture/giver)
	if(!giver)
		return 0

	if(abs(temperature-giver.temperature)>MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY(src)*group_multiplier
		var/giver_heat_capacity = HEAT_CAPACITY(giver)*giver.group_multiplier
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if(combined_heat_capacity != 0)
			temperature = (giver.temperature*giver_heat_capacity + temperature*self_heat_capacity)/combined_heat_capacity

	if((group_multiplier>1)||(giver.group_multiplier>1))
		#define _MERGE_GAS_GM(GAS, ...) GAS += giver.GAS*giver.group_multiplier/group_multiplier;
		APPLY_TO_GASES(_MERGE_GAS_GM)
		#undef _MERGE_GAS_GM
	else
		#define _MERGE_GAS(GAS, ...) GAS += giver.GAS;
		APPLY_TO_GASES(_MERGE_GAS)
		#undef _MERGE_GAS

	if(length(giver.trace_gases))
		for(var/datum/gas/trace_gas in giver.trace_gases)
			var/datum/gas/corresponding
			if(length(trace_gases))
				corresponding = locate(trace_gas.type) in trace_gases
			if(!corresponding)
				corresponding = new trace_gas.type()
				if(!trace_gases)
					trace_gases = list()
				trace_gases += corresponding
			corresponding.moles += trace_gas.moles*giver.group_multiplier/group_multiplier

	pool(giver)
	return 1

//Proportionally removes amount of gas from the gas_mixture
//Returns: gas_mixture with the gases removed
/datum/gas_mixture/proc/remove(amount)
	var/sum = TOTAL_MOLES(src)
	amount = min(amount,sum) //Can not take more air than tile has!
	if(amount <= 0)
		return null

	var/datum/gas_mixture/removed = unpool(/datum/gas_mixture)

	#define _REMOVE_GAS(GAS, ...) \
		removed.GAS = QUANTIZE((GAS/sum)*amount); \
		GAS -= removed.GAS/group_multiplier;
	APPLY_TO_GASES(_REMOVE_GAS)
	#undef _REMOVE_GAS

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			if(!removed.trace_gases)
				removed.trace_gases = list()
			removed.trace_gases += corresponding

			corresponding.moles = (trace_gas.moles/sum)*amount
			trace_gas.moles -= corresponding.moles/group_multiplier

	removed.temperature = temperature

	return removed

//Proportionally removes amount of gas from the gas_mixture
//Returns: gas_mixture with the gases removed
/datum/gas_mixture/proc/remove_ratio(ratio)
	if(ratio <= 0)
		return null

	ratio = min(ratio, 1)

	var/datum/gas_mixture/removed = unpool(/datum/gas_mixture)

	#define _REMOVE_GAS_RATIO(GAS, ...) \
		removed.GAS = QUANTIZE(GAS*ratio); \
		GAS -= removed.GAS/group_multiplier;
	APPLY_TO_GASES(_REMOVE_GAS_RATIO)
	#undef _REMOVE_GAS_RATIO

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			if(!removed.trace_gases)
				removed.trace_gases = list()
			removed.trace_gases += corresponding

			corresponding.moles = trace_gas.moles*ratio
			trace_gas.moles -= corresponding.moles/group_multiplier

	removed.temperature = temperature

	return removed

//Similar to remove(...) but first checks to see if the amount of air removed is small enough
//	that group processing is still accurate for source (aborts if not)
//Returns: gas_mixture with the gases removed or null
/datum/gas_mixture/proc/check_then_remove(amount)
	//Since it is all proportional, the check may be done on the gas as a whole
	var/sum = TOTAL_MOLES(src)
	amount = min(amount,sum) //Can not take more air than tile has!

	if((amount > MINIMUM_AIR_RATIO_TO_SUSPEND) && (amount > sum*MINIMUM_AIR_RATIO_TO_SUSPEND))
		return 0

	return remove(amount)

//Copies variables from sample
/datum/gas_mixture/proc/copy_from(datum/gas_mixture/sample)
	if (sample == null)
		return

	#define _COPY_GAS(GAS, ...) GAS = sample.GAS;
	APPLY_TO_GASES(_COPY_GAS)
	#undef _COPY_GAS

	trace_gases = null
	if(length(sample.trace_gases) > 0)
		trace_gases = list()
		for(var/datum/gas/trace_gas in sample.trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			trace_gases += corresponding

			corresponding.moles = trace_gas.moles

	temperature = sample.temperature

	return 1

//Subtracts right_side from air_mixture. Used to help turfs mingle
/datum/gas_mixture/proc/subtract(datum/gas_mixture/right_side)
	#define _SUBTRACT_GAS(GAS, ...) GAS -= right_side.GAS;
	APPLY_TO_GASES(_SUBTRACT_GAS)
	#undef _SUBTRACT_GAS

	if(length(right_side.trace_gases) > 0)
		trace_gases = list()

		for(var/datum/gas/trace_gas in right_side.trace_gases)
			var/datum/gas/corresponding = locate(trace_gas.type) in trace_gases
			if(!corresponding)
				corresponding = new trace_gas.type()
				trace_gases += corresponding

			corresponding.moles -= trace_gas.moles

	return 1

//Returns: 0 if the self-check failed then -1 if sharer-check failed then 1 if both checks pass
/datum/gas_mixture/proc/check_gas_mixture(datum/gas_mixture/sharer)
	if (!sharer)
		return 0
	#define _DELTA_GAS(GAS, ...) var/delta_##GAS = (GAS - sharer.GAS)/5;
	APPLY_TO_ARCHIVED_GASES(_DELTA_GAS)
	#undef _DELTA_GAS

	var/delta_temperature = (ARCHIVED(temperature) - sharer.ARCHIVED(temperature))

	#define _ABOVE_SUSPEND_THRESHOLD(GAS, ...) ((abs(delta_##GAS) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_##GAS) >= GAS*MINIMUM_AIR_RATIO_TO_SUSPEND)) ||
	if(APPLY_TO_ARCHIVED_GASES(_ABOVE_SUSPEND_THRESHOLD) 0)
		return 0
	#undef _ABOVE_SUSPEND_THRESHOLD

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return 0

	if(length(sharer.trace_gases))
		if(!trace_gases || !trace_gases.len)
			return 0
		for(var/datum/gas/trace_gas in sharer.trace_gases)
			if(trace_gas.ARCHIVED(moles) > MINIMUM_AIR_TO_SUSPEND*4)
				var/datum/gas/corresponding = locate(trace_gas.type) in trace_gases
				if(corresponding)
					if(trace_gas.ARCHIVED(moles) >= corresponding.ARCHIVED(moles)*MINIMUM_AIR_RATIO_TO_SUSPEND*4)
						return 0
				else
					return 0

	if(length(trace_gases))
		if(!sharer.trace_gases || !sharer.trace_gases.len)
			return 0
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.ARCHIVED(moles) > MINIMUM_AIR_TO_SUSPEND*4)
				if(!locate(trace_gas.type) in sharer.trace_gases)
					return 0

	#define _ABOVE_SUSPEND_THRESHOLD(GAS, ...) ((abs(delta_##GAS) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_##GAS) >= sharer.GAS*MINIMUM_AIR_RATIO_TO_SUSPEND)) ||
	if(APPLY_TO_ARCHIVED_GASES(_ABOVE_SUSPEND_THRESHOLD) 0)
		return -1
	#undef _ABOVE_SUSPEND_THRESHOLD

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.ARCHIVED(moles) > MINIMUM_AIR_TO_SUSPEND*4)
				var/datum/gas/corresponding
				if(length(sharer.trace_gases))
					corresponding = locate(trace_gas.type) in sharer.trace_gases
				if(corresponding)
					if(trace_gas.ARCHIVED(moles) >= corresponding.ARCHIVED(moles)*MINIMUM_AIR_RATIO_TO_SUSPEND*4)
						return -1
				else
					return -1

	return 1

//Returns: 0 if self-check failed or 1 if check passes
/datum/gas_mixture/proc/check_turf(turf/model)
	#define _DELTA_GAS(GAS, ...) var/delta_##GAS = (ARCHIVED(GAS) - model.GAS)/5;
	APPLY_TO_GASES(_DELTA_GAS)
	#undef _DELTA_GAS

	var/delta_temperature = (ARCHIVED(temperature) - model.temperature)

	#define _ABOVE_SUSPEND_THRESHOLD(GAS, ...) ((abs(delta_##GAS) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_##GAS) >= ARCHIVED(GAS)*MINIMUM_AIR_RATIO_TO_SUSPEND)) ||
	if(APPLY_TO_GASES(_ABOVE_SUSPEND_THRESHOLD) 0)
		return 0
	#undef _ABOVE_SUSPEND_THRESHOLD
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return 0

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.ARCHIVED(moles) > MINIMUM_AIR_TO_SUSPEND*4)
				return 0

	return 1

//Performs air sharing calculations between two gas_mixtures assuming only 1 boundary length
//Return: amount of gas exchanged (+ if sharer received)
/datum/gas_mixture/proc/share(datum/gas_mixture/sharer)
	if(!sharer)
		return
	#define _DELTA_GAS(GAS, ...) var/delta_##GAS = QUANTIZE(ARCHIVED(GAS) - sharer.ARCHIVED(GAS))/5;
	APPLY_TO_GASES(_DELTA_GAS)
	#undef _DELTA_GAS

	var/delta_temperature = (ARCHIVED(temperature) - sharer.ARCHIVED(temperature))

	var/old_self_heat_capacity = 0
	var/old_sharer_heat_capacity = 0

	var/heat_capacity_self_to_sharer = 0
	var/heat_capacity_sharer_to_self = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		#define _SHARE_GAS_HEAT(GAS, SPECIFIC_HEAT, ...) \
			if(delta_##GAS > 0) { heat_capacity_self_to_sharer += SPECIFIC_HEAT * delta_##GAS } \
			else if(delta_##GAS < 0) { heat_capacity_sharer_to_self -= SPECIFIC_HEAT * delta_##GAS }
		APPLY_TO_GASES(_SHARE_GAS_HEAT)
		#undef _SHARE_GAS_HEAT

		old_self_heat_capacity = HEAT_CAPACITY(src)*group_multiplier
		old_sharer_heat_capacity = HEAT_CAPACITY(sharer)*sharer.group_multiplier

	var/moved_moles = 0

	#define _SHARE_GAS(GAS, ...) \
		GAS -= delta_##GAS / group_multiplier; \
		sharer.GAS += delta_##GAS / sharer.group_multiplier; \
		moved_moles += delta_##GAS;
	APPLY_TO_GASES(_SHARE_GAS)
	#undef _SHARE_GAS

	var/list/trace_types_considered

	if(length(trace_gases))
		trace_types_considered = list()

		for(var/datum/gas/trace_gas in trace_gases)

			var/datum/gas/corresponding
			if(length(sharer.trace_gases))
				corresponding = locate(trace_gas.type) in sharer.trace_gases
			var/delta = 0

			if(corresponding)
				delta = QUANTIZE(trace_gas.ARCHIVED(moles) - corresponding.ARCHIVED(moles))/5
			else
				corresponding = new trace_gas.type()
				if(!sharer.trace_gases)
					sharer.trace_gases = list()
				sharer.trace_gases += corresponding

				delta = trace_gas.ARCHIVED(moles)/5

			trace_gas.moles -= delta/group_multiplier
			corresponding.moles += delta/sharer.group_multiplier

			if(delta)
				var/individual_heat_capacity = trace_gas.specific_heat*delta
				if(delta > 0)
					heat_capacity_self_to_sharer += individual_heat_capacity
				else
					heat_capacity_sharer_to_self -= individual_heat_capacity

			moved_moles += delta

			trace_types_considered += trace_gas.type


	if(length(sharer.trace_gases))
		for(var/datum/gas/trace_gas in sharer.trace_gases)
			if(trace_types_considered && (trace_gas.type in trace_types_considered)) continue
			else
				var/datum/gas/corresponding
				var/delta = 0

				corresponding = new trace_gas.type()
				if(!trace_gases)
					trace_gases = list()
				trace_gases += corresponding

				delta = trace_gas.ARCHIVED(moles)/5

				trace_gas.moles -= delta/sharer.group_multiplier
				corresponding.moles += delta/group_multiplier

				//Guaranteed transfer from sharer to self
				var/individual_heat_capacity = trace_gas.specific_heat*delta
				//heat_sharer_to_self += individual_heat_capacity*sharer.ARCHIVED(temperature)
				heat_capacity_sharer_to_self += individual_heat_capacity

				moved_moles += -delta

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity + heat_capacity_sharer_to_self - heat_capacity_self_to_sharer
		var/new_sharer_heat_capacity = old_sharer_heat_capacity + heat_capacity_self_to_sharer - heat_capacity_sharer_to_self

		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			temperature = (old_self_heat_capacity*temperature - heat_capacity_self_to_sharer*ARCHIVED(temperature) + heat_capacity_sharer_to_self*sharer.ARCHIVED(temperature))/new_self_heat_capacity

		if(new_sharer_heat_capacity > MINIMUM_HEAT_CAPACITY)
			sharer.temperature = (old_sharer_heat_capacity*sharer.temperature-heat_capacity_sharer_to_self*sharer.ARCHIVED(temperature) + heat_capacity_self_to_sharer*ARCHIVED(temperature))/new_sharer_heat_capacity

			if(abs(old_sharer_heat_capacity) > MINIMUM_HEAT_CAPACITY)
				if(abs(new_sharer_heat_capacity/old_sharer_heat_capacity - 1) < 0.10) // <10% change in sharer heat capacity
					temperature_share(sharer, OPEN_HEAT_TRANSFER_COEFFICIENT)

	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE) || abs(moved_moles) > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = ARCHIVED(temperature)*(TOTAL_MOLES(src) + moved_moles) - sharer.ARCHIVED(temperature)*(TOTAL_MOLES(sharer) - moved_moles)
		return (delta_pressure*R_IDEAL_GAS_EQUATION/volume)

	else
		return 0

//Similar to share(...), except the model is not modified
//Return: amount of gas exchanged
/datum/gas_mixture/proc/mimic(turf/model, border_multiplier = 1)
	#define _DELTA_GAS(GAS, ...) var/delta_##GAS = QUANTIZE(((ARCHIVED(GAS) - model.GAS)/5)*border_multiplier/group_multiplier);
	APPLY_TO_GASES(_DELTA_GAS)
	#undef _DELTA_GAS

	var/delta_temperature = (ARCHIVED(temperature) - model.temperature)

	var/heat_transferred = 0
	var/old_self_heat_capacity = 0
	var/heat_capacity_transferred = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		#define _MIMIC_GAS_HEAT(GAS, SPECIFIC_HEAT, ...) \
			if(delta_##GAS) { \
				var/GAS##_heat_capacity = SPECIFIC_HEAT * delta_##GAS; \
				heat_transferred -= GAS##_heat_capacity * model.temperature; \
				heat_capacity_transferred -= GAS##_heat_capacity; \
			}
		APPLY_TO_GASES(_MIMIC_GAS_HEAT)
		#undef _MIMIC_GAS_HEAT

		old_self_heat_capacity = HEAT_CAPACITY(src)*group_multiplier

	var/moved_moles = 0

	#define _MIMIC_GAS(GAS, ...) \
		GAS = QUANTIZE(GAS - delta_##GAS); \
		moved_moles += delta_##GAS;
	APPLY_TO_GASES(_MIMIC_GAS)
	#undef _MIMIC_GAS

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			var/delta = 0

			delta = QUANTIZE((trace_gas.ARCHIVED(moles)/5)*border_multiplier/group_multiplier)

			if (abs(delta) <= ATMOS_EPSILON) continue

			trace_gas.moles = QUANTIZE(trace_gas.moles - delta)

			var/heat_cap_transferred = delta*trace_gas.specific_heat
			heat_transferred += heat_cap_transferred*ARCHIVED(temperature)
			heat_capacity_transferred += heat_cap_transferred
			moved_moles += delta

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity - heat_capacity_transferred
		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			if(border_multiplier)
				temperature = (old_self_heat_capacity*temperature - heat_capacity_transferred*border_multiplier*ARCHIVED(temperature))/new_self_heat_capacity
			else
				temperature = (old_self_heat_capacity*temperature - heat_capacity_transferred*border_multiplier*ARCHIVED(temperature))/new_self_heat_capacity

		temperature_mimic(model, model.thermal_conductivity, border_multiplier)

	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE))
		var/delta_pressure = ARCHIVED(temperature)*(TOTAL_MOLES(src) + moved_moles) - model.temperature*BASE_GASES_TOTAL_MOLES(model)
		return (delta_pressure*R_IDEAL_GAS_EQUATION/volume)
	else
		return 0

/datum/gas_mixture/proc/check_both_then_temperature_share(datum/gas_mixture/sharer, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - sharer.ARCHIVED(temperature))

	var/self_heat_capacity = HEAT_CAPACITY_ARCHIVED(src)
	var/sharer_heat_capacity = HEAT_CAPACITY_ARCHIVED(sharer)

	var/self_temperature_delta = 0
	var/sharer_temperature_delta = 0

	if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
		var/heat = conduction_coefficient*delta_temperature* \
			(self_heat_capacity*sharer_heat_capacity/(self_heat_capacity+sharer_heat_capacity))

		self_temperature_delta = -heat/(self_heat_capacity*group_multiplier)
		sharer_temperature_delta = heat/(sharer_heat_capacity*sharer.group_multiplier)
	else
		return 1

	if((abs(self_temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) \
		&& (abs(self_temperature_delta) > MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND*ARCHIVED(temperature)))
		return 0

	if((abs(sharer_temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) \
		&& (abs(sharer_temperature_delta) > MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND*sharer.ARCHIVED(temperature)))
		return -1

	temperature += self_temperature_delta
	sharer.temperature += sharer_temperature_delta

	return 1
	//Logic integrated from: temperature_share(sharer, conduction_coefficient) for efficiency

/datum/gas_mixture/proc/check_me_then_temperature_share(datum/gas_mixture/sharer, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - sharer.ARCHIVED(temperature))

	var/self_heat_capacity = HEAT_CAPACITY_ARCHIVED(src)
	var/sharer_heat_capacity = HEAT_CAPACITY_ARCHIVED(sharer)

	var/self_temperature_delta = 0
	var/sharer_temperature_delta = 0

	if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
		var/heat = conduction_coefficient*delta_temperature* \
			(self_heat_capacity*sharer_heat_capacity/(self_heat_capacity+sharer_heat_capacity))

		self_temperature_delta = -heat/(self_heat_capacity*group_multiplier)
		sharer_temperature_delta = heat/(sharer_heat_capacity*sharer.group_multiplier)
	else
		return 1

	if((abs(self_temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) \
		&& (abs(self_temperature_delta) > MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND*ARCHIVED(temperature)))
		return 0

	temperature += self_temperature_delta
	sharer.temperature += sharer_temperature_delta

	return 1
	//Logic integrated from: temperature_share(sharer, conduction_coefficient) for efficiency

/datum/gas_mixture/proc/check_me_then_temperature_turf_share(turf/simulated/sharer, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - sharer.temperature)

	var/self_temperature_delta = 0
	var/sharer_temperature_delta = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY_ARCHIVED(src)

		if((sharer.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*sharer.heat_capacity/(self_heat_capacity+sharer.heat_capacity))

			self_temperature_delta = -heat/(self_heat_capacity*group_multiplier)
			sharer_temperature_delta = heat/sharer.heat_capacity
	else
		return 1

	if((abs(self_temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) \
		&& (abs(self_temperature_delta) > MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND*ARCHIVED(temperature)))
		return 0

	temperature += self_temperature_delta
	sharer.temperature += sharer_temperature_delta

	return 1
	//Logic integrated from: temperature_turf_share(sharer, conduction_coefficient) for efficiency

/datum/gas_mixture/proc/check_me_then_temperature_mimic(turf/model, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - model.temperature)
	var/self_temperature_delta = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY_ARCHIVED(src)

		if((model.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*model.heat_capacity/(self_heat_capacity+model.heat_capacity))

			self_temperature_delta = -heat/(self_heat_capacity*group_multiplier)

	if((abs(self_temperature_delta) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) \
		&& (abs(self_temperature_delta) > MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND*ARCHIVED(temperature)))
		return 0

	temperature += self_temperature_delta

	return 1
	//Logic integrated from: temperature_mimic(model, conduction_coefficient) for efficiency

/datum/gas_mixture/proc/temperature_share(datum/gas_mixture/sharer, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - sharer.ARCHIVED(temperature))
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY_ARCHIVED(src)
		var/sharer_heat_capacity = HEAT_CAPACITY_ARCHIVED(sharer)

		if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*sharer_heat_capacity/(self_heat_capacity+sharer_heat_capacity))

			temperature -= heat/(self_heat_capacity*group_multiplier)
			sharer.temperature += heat/(sharer_heat_capacity*sharer.group_multiplier)

/datum/gas_mixture/proc/temperature_mimic(turf/model, conduction_coefficient, border_multiplier)
	var/delta_temperature = (temperature - model.temperature)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY(src)//ARCHIVED()()

		if((model.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*model.heat_capacity/(self_heat_capacity+model.heat_capacity))

			if(border_multiplier)
				temperature -= heat*border_multiplier/(self_heat_capacity*group_multiplier)
			else
				temperature -= heat/(self_heat_capacity*group_multiplier)

/datum/gas_mixture/proc/temperature_turf_share(turf/simulated/sharer, conduction_coefficient)
	var/delta_temperature = (ARCHIVED(temperature) - sharer.temperature)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = HEAT_CAPACITY(src)

		if((sharer.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity* sharer.heat_capacity /(self_heat_capacity+sharer.heat_capacity))

			temperature -= heat/(self_heat_capacity*group_multiplier)
			sharer.temperature += heat/sharer.heat_capacity

//Compares sample to self to see if within acceptable ranges that group processing may be enabled
/datum/gas_mixture/proc/compare(datum/gas_mixture/sample)
	if (!sample)
		return 0
	#define _COMPARE_GAS(GAS, ...) \
		if((abs(GAS-sample.GAS) > MINIMUM_AIR_TO_SUSPEND) && \
			((GAS < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.GAS) || (GAS > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.GAS))) \
			{ return 0; }
	APPLY_TO_GASES(_COMPARE_GAS)
	#undef _COMPARE_GAS

	if((TOTAL_MOLES(src)) > MINIMUM_AIR_TO_SUSPEND)
		if((abs(temperature-sample.temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) && \
			((temperature < (1-MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND)*sample.temperature) || (temperature > (1+MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND)*sample.temperature)))
			return 0

	if(length(sample.trace_gases))
		for(var/datum/gas/trace_gas in sample.trace_gases)
			if(trace_gas.ARCHIVED(moles) > MINIMUM_AIR_TO_SUSPEND)
				var/datum/gas/corresponding
				if(length(trace_gases))
					corresponding = locate(trace_gas.type) in trace_gases
				if(corresponding)
					if((abs(trace_gas.moles - corresponding.moles) > MINIMUM_AIR_TO_SUSPEND) && \
						((corresponding.moles < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*trace_gas.moles) || (corresponding.moles > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*trace_gas.moles)))
						return 0
				else
					return 0

	if(length(trace_gases))
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.moles > MINIMUM_AIR_TO_SUSPEND)
				var/datum/gas/corresponding
				if(sample.trace_gases)
					corresponding = locate(trace_gas.type) in sample.trace_gases
				if(corresponding)
					if((abs(trace_gas.moles - corresponding.moles) > MINIMUM_AIR_TO_SUSPEND) && \
						((trace_gas.moles < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*corresponding.moles) || (trace_gas.moles > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*corresponding.moles)))
						return 0
				else
					return 0
	return 1

// Dead prototypes (or never implemented?)
// /datum/gas_mixture/proc/check_me_then_share(datum/gas_mixture/sharer)
	//Similar to share(...) but first checks to see if amount of air moved is small enough
	//	that group processing is still accurate for source (aborts if not)
	//Returns: 1 on successful share, 0 if the check failed

// /datum/gas_mixture/proc/check_me_then_mimic(turf/model)
	//Similar to mimic(...) but first checks to see if amount of air moved is small enough
	//	that group processing is still accurate (aborts if not)
	//Returns: 1 on successful mimic, 0 if the check failed

// /datum/gas_mixture/proc/check_both_then_share(datum/gas_mixture/sharer)
	//Similar to check_me_then_share(...) but also checks to see if amount of air moved is small enough
	//	that group processing is still accurate for the sharer (aborts if not)
	//Returns: 0 if the self-check failed then -1 if sharer-check failed then 1 if successful share
