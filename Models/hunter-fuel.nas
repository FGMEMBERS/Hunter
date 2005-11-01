# This is aminor amendment of fuel.nas which changes the logic so that the 
# code no longer changes the selection state of tanks.



# Properties under /consumables/fuel/tank[n]:
# + level-gal_us    - Current fuel load.  Can be set by user code.
# + level-lbs       - OUTPUT ONLY property, do not try to set
# + selected        - boolean indicating tank selection.
# + density-ppg     - Fuel density, in lbs/gallon.
# + capacity-gal_us - Tank capacity 
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.

UPDATE_PERIOD = 0.3;

# ============================== Register timer ===========================================

registerTimer = func {

    settimer(fuelUpdate, UPDATE_PERIOD);
    
}# end func

# ============================= end Register timer =======================================

# =================================== Fuel Update ========================================

fuelUpdate = func {

    if(getprop("/sim/freeze/fuel")) { return registerTimer(); }

    if (flag and !done) {print("fuel running"); done = 1};

    AllEngines = props.globals.getNode("engines").getChildren("engine");
    
    AllEnginescontrols = props.globals.getNode("controls/engines").getChildren("engine");

    # Sum the consumed fuel
    total = 0;
    foreach(e; AllEngines) {
        fuel = e.getNode("fuel-consumed-lbs", 1);
        consumed = fuel.getValue();
        if(consumed == nil) { consumed = 0; }
        total = total + consumed;
        fuel.setDoubleValue(0);
    }

    # Unfortunately, FDM initialization hasn't happened when we start
    # running.  Wait for the FDM to start running before we set any output
    # properties.  This also prevents us from mucking with FDMs that
    # don't support this fuel scheme.
    if(total == 0 and !flag) {  # this relies on 'total'
        return registerTimer(); #  not being quite 0 at startup,
        }else{                  # and therefore keeps the function running,
        flag = 1;               # once it has run once.
    }
        
    if(!initialized) { initialize(); }

    AllTanks = props.globals.getNode("consumables/fuel").getChildren("tank");

    # Build a list of available tanks. An available tank is both selected and has 
    # fuel remaining.  Note the filtering for "zero-capacity" tanks.  The FlightGear
    # code likes to define zombie tanks that have no meaning to the FDM,
    # so we have to take measures to ignore them here. 
    availableTanks = [];
    
    foreach(t; AllTanks) {
        cap = t.getNode("capacity-gal_us", 1).getValue();
        contents = t.getNode("level-gal_us", 1).getValue();
        if(cap != nil and cap > 0.01 ) {
            if(t.getNode("selected", 1).getBoolValue() and contents > 0) {
                append(availableTanks, t);
            }
        }
    }

    # Subtract fuel from tanks, set auxilliary properties.  Set out-of-fuel
    # when all tanks are dry. 
    outOfFuel = 0;
    
	if(size(availableTanks) == 0) {
            outOfFuel = 1;
        } else {
        fuelPerTank = total / size(availableTanks);
        foreach(t; availableTanks) {
            ppg = t.getNode("density-ppg").getValue();
          # lbs = t.getNode("level-gal_us").getValue() * ppg;
		    lbs = t.getNode("level-lbs").getValue();
            lbs = lbs - fuelPerTank;
            if(lbs < 0) {
                lbs = 0; 
                # Kill the engines if we're told to, otherwise simply
                # deselect the tank.
                if(t.getNode("kill-when-empty", 1).getBoolValue()) { outOfFuel = 1; }
                else { t.getNode("selected", 1).setBoolValue(0); }
             }
             gals = lbs / ppg;
             t.getNode("level-gal_us").setDoubleValue(gals);
             t.getNode("level-lbs").setDoubleValue(lbs);
        }
    }
	
	# set all tanks 
	foreach(t; AllTanks) {
	    ppg = t.getNode("density-ppg").getValue();
        t.getNode("level-gal_us").setValue(t.getNode("level-lbs").getValue() / ppg);
    }
	
    
    # Total fuel properties
    gals = lbs = cap = 0;
    foreach(t; AllTanks) {
        cap = cap + t.getNode("capacity-gal_us").getValue();
        gals = gals + t.getNode("level-gal_us").getValue();
        lbs = lbs + t.getNode("level-lbs").getValue();
    }
    
    setprop("/consumables/fuel/total-fuel-gals", gals);
    setprop("/consumables/fuel/total-fuel-lbs", lbs);
    setprop("/consumables/fuel/total-fuel-norm", gals/cap);

    foreach(e; AllEngines) {
        e.getNode("out-of-fuel").setBoolValue(outOfFuel);
    }
    
    registerTimer();
    
}# end func

# ================================ end Fuel Update ================================

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted
# for, and that they have sane default values.
flag = 0;
done = 0;
initialized = 0;



initialize = func {

    AllEngines = props.globals.getNode("engines").getChildren("engine");
    AllTanks = props.globals.getNode("consumables/fuel").getChildren("tank");
    AllEnginescontrols = props.globals.getNode("controls/engines").getChildren("engine");

    foreach(e; AllEngines) {
        e.getNode("fuel-consumed-lbs", 1).setDoubleValue(0);
        e.getNode("out-of-fuel", 1).setBoolValue(0);
    }

    foreach(t; AllTanks) {
        initDoubleProp(t, "level-gal_us", 0);
        initDoubleProp(t, "level-lbs", 0);
        initDoubleProp(t, "capacity-gal_us", 0.01); # Not zero (div/zero issue)
        initDoubleProp(t, "density-ppg", 6.0); # gasoline

        if(t.getNode("selected") == nil) {
            t.getNode("selected", 1).setBoolValue(1);
        }
    }
    
    foreach(e; AllEnginescontrols) {
        if(e.getNode("mixture-lever") == nil) {
            e.getNode("mixture-lever", 1).setDoubleValue(0);
        }
    }
    
    
    initialized = 1;
    
}# end func

# ================================ end Initalize ================================== 

# =============================== Utility Function ================================

initDoubleProp = func {

    node = arg[0]; prop = arg[1]; val = arg[2];
    if(node.getNode(prop) != nil) {
        val = num(node.getNode(prop).getValue());
    }
    node.getNode(prop, 1).setDoubleValue(val);

}# end func

# =========================== end Utility Function ================================

# Fire it up

registerTimer();
