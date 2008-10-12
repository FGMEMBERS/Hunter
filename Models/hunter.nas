# ==================================== timer stuff ===========================================

# set the update period

UPDATE_PERIOD = 0.3;

# set the timer for the selected function

var registerTimer = func {
	
	settimer(arg[0], UPDATE_PERIOD);

} # end function 

# =============================== end timer stuff ===========================================

# =============================== Pilot G stuff======================================

var pilot_g = props.globals.getNode("accelerations/pilot-g", 1);
var timeratio = props.globals.getNode("accelerations/timeratio", 1);
var pilot_g_damped = props.globals.getNode("accelerations/pilot-g-damped", 1);

pilot_g.setDoubleValue(0);
pilot_g_damped.setDoubleValue(0); 
timeratio.setDoubleValue(0.03); 

var damp = 0;

var updatePilotG = func {
	var n = timeratio.getValue(); 
	var g = pilot_g.getValue() ;
	#if (g == nil) { g = 0; }
	damp = ( g * n) + (damp * (1 - n));
	
	pilot_g_damped.setDoubleValue(damp);

# print(sprintf("pilot_g_damped in=%0.5f, out=%0.5f", g, damp));

	settimer(updatePilotG, 0.1);

} #end updatePilotG()

updatePilotG();

# headshake - this is a modification of the original work by Josh Babcock

# Define some stuff with global scope

xConfigNode = '';
yConfigNode = '';
zConfigNode = '';

xAccelNode = '';
yAccelNode = '';
zAccelNode = '';

var xDivergence_damp = 0;
var yDivergence_damp = 0;
var zDivergence_damp = 0;

var last_xDivergence = 0;
var last_yDivergence = 0;
var last_zDivergence = 0;

var old_xDivergence_damp = 0;
var old_yDivergence_damp = 0;
var old_zDivergence_damp = 0;

# Make sure that some vital data exists and set some default values
var enabledNode = props.globals.getNode("/sim/headshake/enabled", 1);
enabledNode.setBoolValue(1);

var xMaxNode = props.globals.getNode("/sim/headshake/x-max-m",1);
xMaxNode.setDoubleValue( 0.025 );

var xMinNode = props.globals.getNode("/sim/headshake/x-min-m",1);
xMinNode.setDoubleValue( -0.05 );
	
var yMaxNode = props.globals.getNode("/sim/headshake/y-max-m",1);
yMaxNode.setDoubleValue( 0.025 );

var yMinNode = props.globals.getNode("/sim/headshake/y-min-m",1);
yMinNode.setDoubleValue( -0.025 );
	
var zMaxNode = props.globals.getNode("/sim/headshake/z-max-m",1);
zMaxNode.setDoubleValue( 0.025 );

var zMinNode = props.globals.getNode("/sim/headshake/z-min-m",1);
zMinNode.setDoubleValue( -0.05 );

var view_number_Node = props.globals.getNode("/sim/current-view/view-number",1);
view_number_Node.setDoubleValue( 0 );

var time_ratio_Node = props.globals.getNode("/sim/headshake/time-ratio",1);
time_ratio_Node.setDoubleValue( 0.003 );

var seat_vertical_adjust_Node = props.globals.getNode("/controls/seat/vertical-adjust",1);
seat_vertical_adjust_Node.setDoubleValue( 0 );

var xThresholdNode = props.globals.getNode("/sim/headshake/x-threshold-m",1);
xThresholdNode.setDoubleValue( 0.02 );

var yThresholdNode = props.globals.getNode("/sim/headshake/y-threshold-m",1);
yThresholdNode.setDoubleValue( 0.02 );

var zThresholdNode = props.globals.getNode("/sim/headshake/z-threshold-m",1);
zThresholdNode.setDoubleValue( 0.02 );

# We will use these later
var xConfigNode = props.globals.getNode("/sim/view/config/z-offset-m");
var yConfigNode = props.globals.getNode("/sim/view/config/x-offset-m");
var zConfigNode = props.globals.getNode("/sim/view/config/y-offset-m");
	
var xAccelNode = props.globals.getNode("/accelerations/pilot/x-accel-fps_sec",1);
xAccelNode.setDoubleValue( 0 );
var yAccelNode = props.globals.getNode("/accelerations/pilot/y-accel-fps_sec",1);
yAccelNode.setDoubleValue( 0 );
var zAccelNode = props.globals.getNode("/accelerations/pilot/z-accel-fps_sec",1);
zAccelNode.setDoubleValue(-32 );

xViewAxisNode = props.globals.getNode("/sim/current-view/z-offset-m");
yViewAxisNode = props.globals.getNode("/sim/current-view/x-offset-m");
zViewAxisNode = props.globals.getNode("/sim/current-view/y-offset-m");

var headShake = func {

	# First, we don't shake outside the vehicle. Inside, we boogie down.
	# There are two coordinate systems here, one used for accelerations, and one used for the viewpoint.
	# We will be using the one for accelerations.
	var enabled = enabledNode.getValue();
	var view_number= view_number_Node.getValue();
	var n = timeratio.getValue(); 
	var seat_vertical_adjust = seat_vertical_adjust_Node.getValue();
	

	if ( (enabled) and ( view_number == 0)) {
	
#	var xConfig = xConfigNode.getValue();
#	var yConfig = yConfigNode.getValue();
#	var zConfig = zConfigNode.getValue();

	var xMax = xMaxNode.getValue();
	var xMin = xMinNode.getValue();
	var yMax = yMaxNode.getValue();
	var yMin = yMinNode.getValue();
	var zMax = zMaxNode.getValue();
	var zMin = zMinNode.getValue();

	#work in G, not fps/s
	var xAccel = xAccelNode.getValue()/32;
	var yAccel = yAccelNode.getValue()/32;
	var zAccel = (zAccelNode.getValue() + 32)/32; # We aren't counting gravity
 
	var xThreshold =  xThresholdNode.getValue();
	var yThreshold =  yThresholdNode.getValue();
	var zThreshold =  zThresholdNode.getValue();
		
	# Set viewpoint divergence and clamp
	# Note that each dimension has it's own special ratio and +X is clamped at 1cm
	# to simulate a headrest.

	#y = -0.0005x3 - 0.005x2 - 0.0089x - 0.0045
	# -0.0004x3 + 0.0042x2 - 0.0084x + 0.0048
	# -0.0004x3 - 0.0042x2 - 0.0084x - 0.0048
	if (xAccel < -5 ) {
		xDivergence = -0.03;
	} elsif ((xAccel < -0.5) and (xAccel >= -5)) {
		xDivergence = ((( -0.0005 * xAccel ) - ( 0.0036 )) * xAccel - ( 0.001 )) * xAccel - 0.0004;
	} elsif ((xAccel > 1) and (xAccel <= 6)) {
		xDivergence = ((( -0.0004 * xAccel ) + ( 0.0031 )) * xAccel - ( 0.0016 )) * xAccel + 0.0002;
	} elsif (xAccel > 5) {
		xDivergence = 0.02;
	} else {
		xDivergence = 0;
		}

#       These equations shape the output and convet from G number to divergence left/right in meters
#	y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
#	y = -0.013x3 + 0.125x2 - 0.1202x + 0.0272
		
	if (yAccel < -5 ) {
		yDivergence = -0.03;
	} elsif ((yAccel < -0.5) and (yAccel >= -5)) {
		yDivergence = ((( -0.005 * yAccel ) - ( 0.0036 )) * yAccel - (  0.0001 )) * yAccel - 0.0004;
	} elsif ((yAccel > 0.5) and (yAccel <= 5)) {
		yDivergence = ((( -0.013 * yAccel ) + ( 0.125 )) * yAccel - (  0.1202 )) * yAccel + 0.0272;
	} elsif (yAccel > 5) {
		yDivergence = 0.03;
	}else {
		yDivergence = 0;
	}

#        setprop("/sim/current-view/x-offset-m", (yConfig + yDivergence));	
# y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
# y = -0.0004x3 + 0.0031x2 - 0.0016x + 0.0002

	if (zAccel < -5 ) {
		zDivergence = -0.03;
	} elsif ((zAccel < -0.5) and (zAccel >= -5)) {
			zDivergence = ((( -0.0005 * zAccel ) - ( 0.0036 )) * zAccel - ( 0.001 )) * zAccel - 0.0004;
		} elsif ((zAccel > 0.5) and (zAccel <= 5)) {
				zDivergence = ((( -0.0004 * zAccel ) + ( 0.0031 )) * zAccel - ( 0.0016 )) * zAccel + 0.0002;
	} elsif (zAccel > 5) {
		zDivergence = 0.02;
	} else {
		zDivergence = 0;
	}


	xDivergence_total = (xDivergence * 0.75) + (zDivergence * 0.25);

	if (xDivergence_total > xMax){xDivergence_total = xMax;}
	if (xDivergence_total < xMin){xDivergence_total = xMin;}
	
	if (abs(last_xDivergence - xDivergence_total) <= xThreshold){
		xDivergence_damp = ( xDivergence_total * n) + ( xDivergence_damp * (1 - n));
	#	print ("x low pass");
	} else {
		xDivergence_damp = xDivergence_total;
	#	print ("x high pass");
	}
		
	last_xDivergence = xDivergence_damp;

# print (sprintf("x-G=%0.5fx, total=%0.5f, x div damped=%0.5f",xAccel, xDivergence_total, xDivergence_damp));	

	yDivergence_total = yDivergence;
	if (yDivergence_total >= yMax){yDivergence_total = yMax;}
	if (yDivergence_total <= yMin){yDivergence_total = yMin;}

	if (abs(last_yDivergence - yDivergence_total) <= yThreshold){
		yDivergence_damp = ( yDivergence_total * n) + ( yDivergence_damp * (1 - n));
		# 	print ("y low pass");
	} else {
		yDivergence_damp = yDivergence_total;
	#	print ("y high pass");
	}

	last_yDivergence = yDivergence_damp;

#print (sprintf("y=%0.5f, y total=%0.5f, y min=%0.5f, y div damped=%0.5f",yDivergence, yDivergence_total, yMin , yDivergence_damp));
	
	zDivergence_total =  (xDivergence * 0.25 ) + (zDivergence * 0.75);

	if (zDivergence_total >= zMax){zDivergence_total = zMax;}
	if (zDivergence_total <= zMin){zDivergence_total = zMin;}
	
	if (abs(last_zDivergence - zDivergence_total) <= zThreshold){ 
		zDivergence_damp = ( zDivergence_total * n) + ( zDivergence_damp * (1 - n));
	#print ("z low pass");
	} else {
		zDivergence_damp = zDivergence_total;
	#print ("z high pass");
	}
	

#	last_zDivergence = zDivergence_damp;

#print (sprintf("z-G=%0.5f, z total=%0.5f, z div damped=%0.5f",zAccel, zDivergence_total,zDivergence_damp));

# Now apply the divergence to the curent viewpoint
		
		var origin_z = xViewAxisNode.getValue() - old_xDivergence_damp;
		var origin_x = yViewAxisNode.getValue() - old_yDivergence_damp;
		var origin_y = zViewAxisNode.getValue() - old_zDivergence_damp;

		xViewAxisNode.setDoubleValue(origin_z + xDivergence_damp );
		yViewAxisNode.setDoubleValue(origin_x + yDivergence_damp );
		zViewAxisNode.setDoubleValue(origin_y + zDivergence_damp + seat_vertical_adjust );

		old_xDivergence_damp = xDivergence_damp;
		old_yDivergence_damp = yDivergence_damp;
		old_zDivergence_damp = zDivergence_damp + seat_vertical_adjust;
	}
	
    settimer(headShake,0 );

}

setlistener("/sim/signals/fdm-initialized", func {
	headShake();
	}
);

# ============================== end Pilot G stuff ============================

# ============================ Gear stuff======================================

var caster_angle = props.globals.getNode("gear/gear/caster-angle-deg", 1);
var roll_speed = props.globals.getNode("gear/gear/rollspeed-ms", 1);
var wow = props.globals.getNode("gear/gear/wow", 1);
var timeratio = props.globals.getNode("gear/gear/timeratio", 1);
var caster_angle_damped = props.globals.getNode("gear/gear/caster-angle-deg-damped", 1);

caster_angle.setDoubleValue(0); 
roll_speed.setDoubleValue(0); 
timeratio.setDoubleValue(0.05); 
caster_angle_damped.setDoubleValue(0);
wow.setBoolValue(1); 

var angle_damp = 0;

var updateCasterAngle = func {
	var n = timeratio.getValue(); 
	var angle = caster_angle.getValue() ;
	var speed = roll_speed.getValue();
	var _wow = wow.getValue();
	
	if ( _wow ) {
		n = (0.02 * speed) + 0.001;
	} else {
		n = 0.5;
	}
	
	angle_damp = ( angle * n) + (angle_damp * (1 - n));
	
	caster_angle_damped.setDoubleValue(angle_damp);
	timeratio.setDoubleValue(n); 

# print(sprintf("caster_angle_damped in=%0.5f, out=%0.5f", angle, angle_damp));

	settimer(updateCasterAngle, 0.1);

} #end func updateCasterAngle()

updateCasterAngle();

# ======================================= end Gear stuff ============================

# ======================================= auto-switch off shadows ========================

var current_view_internal = props.globals.getNode("/sim/current-view/internal", 1);
var shadow_state_ac = props.globals.getNode("/sim/rendering/shadows-ac", 1);
var shadow_state_ac_transp = props.globals.getNode("/sim/rendering/shadows-ac-transp", 1);
var shadow_auto = props.globals.getNode("/sim/rendering/shadows-auto", 1);

var set_state_ac = shadow_state_ac.getValue() ;
var set_state_ac_transp = shadow_state_ac_transp.getValue() ;
#shadow_auto.setBoolValue(0) ;

print("set_state_ac " , set_state_ac, " set_state_ac_transp " , set_state_ac_transp);

var updateShadowState = func {
	var internal = current_view_internal.getValue(); 
	var state_ac = shadow_state_ac.getValue() ;
	var state_ac_transp = shadow_state_ac_transp.getValue() ;
	var auto = shadow_auto.getValue() ;
	
	if ( state_ac == nil or state_ac_transp == nil or !auto ) {return;}
	if ( internal == 1 ) {   
		state = 0;
	} else {
		state = 1;
	}
	
	state_ac = shadow_state_ac.setValue(state) ;
	var state_ac_transp = shadow_state_ac_transp.setValue(state) ;
	
	
print("shadow " , internal, " state " , state);
		
} #end func updateShadowState()

setlistener( current_view_internal , updateShadowState );

# end 

# ======================================= jet exhaust ========================

var speed_node = props.globals.getNode("velocities/uBody-fps", 1);
var exhaust_node = props.globals.getNode("sim/ai/aircraft/exhaust", 1);

exhaust_node.setBoolValue(1) ;

var updateExhaustState = func {
	var speed = speed_node.getValue(); 
	var exhaust = exhaust_node.getValue() ;
	
	if (speed == nil) {return;}
	if (speed >= 90) {   
	  exhaust = 0;
	} else {
	  exhaust = 1;
	}
	
	exhaust_node.setBoolValue(exhaust) ;
	
#        print("exhaust " , exhaust);
		
#        settimer(updateExhaustState, 0);
		
} #end func updateExhaustState()

#settimer(updateExhaustState,0);

# ================================== Steering =================================================

aircraft.steering.init();

#================================== Droptanks ================================
print("droptanks starting");
var droptank_node = props.globals.getNode("sim/ai/aircraft/impact/droptank", 1);

var droptanks = func(n) {
	var droptank = droptank_node.getValue();
	var node = props.globals.getNode(n.getValue(), 1);
# print (" droptank ", droptank, " lon " , node.getNode("impact/longitude-deg").getValue(),);
	geo.put_model("Aircraft/Hunter/Models/droptank.xml",
		node.getNode("impact/latitude-deg").getValue(),
		node.getNode("impact/longitude-deg").getValue(),
		node.getNode("impact/elevation-m").getValue()+ 0.25,
		node.getNode("impact/heading-deg").getValue(),
		0,
		0
		);
	}

setlistener( "sim/ai/aircraft/impact/droptank", droptanks);

print("droptanks running");

#================================== Transfer Fuel =====================================

# tranfer fuel

var fuelTrans = func {
	
	 var amount = 0;
	 var maxFlowRate = 1;

	setprop("consumables/fuel/tank[2]/selected",0);
	setprop("consumables/fuel/tank[3]/selected",0);

	if(getprop("/sim/freeze/fuel")) { return registerTimer(fuelTrans); }
	
	var capacityPort = getprop("consumables/fuel/tank[0]/capacity-gal_us");
	if(capacityPort == nil) { capacityPort = 0; }

	var levelPort = getprop("consumables/fuel/tank[0]/level-gal_us");
	if(levelPort == nil) { levelPort = 0; }
	
	var capacityStbd = getprop("consumables/fuel/tank[1]/capacity-gal_us");
	if(capacityStbd == nil) { capacityStbd = 0; }

	var levelStbd = getprop("consumables/fuel/tank[1]/level-gal_us");
	if(levelStbd == nil) { levelStbd = 0; }
	
	var levelDropPort = getprop("consumables/fuel/tank[2]/level-gal_us");
	if(levelDropPort == nil) { levelDropPort = 0; }
	
	var densityPort = getprop("consumables/fuel/tank[2]/density-ppg");
	if(densityPort == nil) { densityPort = 0; }

	var levelDropStbd = getprop("consumables/fuel/tank[3]/level-gal_us");
	if(levelDropStbd == nil) { levelDropStbd = 0; }	
	
	var densityStbd = getprop("consumables/fuel/tank[3]/density-ppg");
	if(densityStbd == nil) { densityStbd = 0; }
	
	if ( capacityPort > levelPort and levelDropPort > 0){
		amount = capacityPort - levelPort;
		if (amount > levelDropPort) {
			amount = levelDropPort;
		}
		if (amount > maxFlowRate) {
			amount = maxFlowRate;
		}
		levelDropPort = levelDropPort - amount;
		levelPort = levelPort + amount;
		setprop( "consumables/fuel/tank[2]/level-gal_us",levelDropPort);
		setprop( "consumables/fuel/tank[0]/level-gal_us",levelPort);
	}
	
	if ( capacityStbd > levelStbd and levelDropStbd > 0){
		amount = capacityStbd - levelStbd;
		if (amount > levelDropStbd) {
			amount = levelDropStbd;
		}
		if (amount > maxFlowRate) {
			amount = maxFlowRate;
		}
		levelDropStbd = levelDropStbd - amount;
		levelStbd = levelStbd + amount;
		setprop( "consumables/fuel/tank[3]/level-gal_us",levelDropStbd);
		setprop( "consumables/fuel/tank[1]/level-gal_us",levelStbd);
	}
	
	setprop( "consumables/fuel/tank[2]/level-lbs",levelDropPort * densityPort);
	setprop( "consumables/fuel/tank[3]/level-lbs",levelDropStbd * densityStbd);

	#print("Port: ",levelPort, " Stbd: ",levelStbd);
	#print( " Amount: ",amount);

	registerTimer(fuelTrans);

} # end funtion fuelTrans

# fire it up

registerTimer(fuelTrans);

# ========================== end fuel stuff ======================================

# end 

