##
# Pop up a "tip" dialog for a moment, then remove it.  The delay in
# seconds can be specified as the second argument.  The default is 1
# second.  Note that the tip dialog is a shared resource.  If
# someone else comes along and wants to pop a tip up before your delay
# is finished, you lose. :)
#
popupTip = func {
    delay = if(size(arg) > 1) {arg[1]} else {DELAY};
    tmpl = { name : "PopTip", modal : 0, layout : "hbox",
             y: screenHProp.getValue() - 140,
             text : { label : arg[0], padding : 6 } };

    popdown();
    fgcommand("dialog-new", props.Node.new(tmpl));
    fgcommand("dialog-show", tipArg);

    currTimer = currTimer + 1;
    thisTimer = currTimer;
    settimer(func { if(currTimer == thisTimer) { popdown() } }, DELAY);
}

showDialog = func {
    fgcommand("dialog-show",
              props.Node.new({ "dialog-name" : arg[0]}));
}

########################################################################
# Private Stuff:
########################################################################

##
# Initialize property nodes via a timer, to insure the props module is
# loaded.  See notes in view.nas.  Simply cache the screen height
# property and the argument for the "dialog-show" command.  This
# probably isn't really needed...
#
screenHProp = tipArg = nil;
INIT = func {
    screenHProp = props.globals.getNode("/sim/startup/ysize");
    tipArg = props.Node.new({ "dialog-name" : "PopTip" });
}
settimer(INIT, 0);

##
# How many seconds do we show the tip?
#
DELAY = 1.0;

##
# Pop down the tip dialog, if it is visible.
#
popdown = func { fgcommand("dialog-close", tipArg); }

# Marker for the "current" timer.  This value gets stored in the
# closure of the timer function, and is used to check that there
# hasn't been a more recent timer set that should override.
currTimer = 0;

########################################################################
# Widgets & Layout Management
########################################################################

## 
# A "widget" class that wraps a property node.  It provides useful
# helper methods that are difficult or tedious with the raw property
# API.  Note especially the slightly tricky addChild() method.
#
Widget = {
    set : func { me.node.getNode(arg[0], 1).setValue(arg[1]); },
    prop : func { return me.node; },
    new : func { return { parents : [Widget], node : props.Node.new() } },
    addChild : func {
        type = arg[0];
        idx = size(me.node.getChildren(type));
        name = type ~ "[" ~ idx ~ "]";
        newnode = me.node.getNode(name, 1);
        return { parents : [Widget], node : newnode };
    }
};

########################################################################
# Dialog Boxes
########################################################################

##
# Dynamically generates a weight & fuel configuration dialog specific to
# the aircraft.
#
showWeightDialog = func {
    name = "WeightAndFuel";
    title = "Weight and Fuel Settings";

    #
    # General Dialog Structure
    #
    dialog = Widget.new();
    dialog.set("name", name);
    dialog.set("layout", "vbox");

    header = dialog.addChild("text");
    header.set("label", title);

    contentArea = dialog.addChild("group");
    contentArea.set("layout", "hbox");

    grossWgt = props.globals.getNode("/yasim/gross-weight-lbs");
    if(grossWgt != nil) {
        gwg = dialog.addChild("group");
        gwg.set("layout", "hbox");
        gwg.addChild("empty").set("stretch", 1);
        gwg.addChild("text").set("label", "Gross Weight (lb):");
        txt = gwg.addChild("text");
        txt.set("label", "0123456789");
        txt.set("property", "/yasim/gross-weight-lbs");
        txt.set("live", 1);
        gwg.addChild("empty").set("stretch", 1);
    }

    buttonBar = dialog.addChild("group");
    buttonBar.set("layout", "hbox");
    buttonBar.set("default-padding", 10);
    
    ok = buttonBar.addChild("button");
    ok.set("legend", "OK");
    ok.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
    ok.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

    # Temporary helper function
    tcell = func {
        cell = arg[0].addChild(arg[1]);
        cell.set("row", arg[2]);
        cell.set("col", arg[3]);
        return cell;
    }

    #
    # Fill in the content area
    #
    fuelArea = contentArea.addChild("group");
    fuelArea.set("layout", "vbox");
    fuelArea.addChild("text").set("label", "Fuel Tanks");

    fuelTable = fuelArea.addChild("group");
    fuelTable.set("layout", "table");

    fuelArea.addChild("empty").set("stretch", 1);

    tcell(fuelTable, "text", 0, 0).set("label", "Tank");
    tcell(fuelTable, "text", 0, 3).set("label", "Pounds");
    tcell(fuelTable, "text", 0, 4).set("label", "Gallons");

    tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
    for(i=0; i<size(tanks); i=i+1) {
        t = tanks[i];

        tname = i ~ "";
        tnode = t.getNode("name");
        if(tnode != nil) { tname = tnode.getValue(); }

        tankprop = "/consumables/fuel/tank["~i~"]";

        cap = t.getNode("capacity-gal_us", 1).getValue();
        ppg = t.getNode("density-ppg", 1).getValue();

        # Hack, to ignore the "ghost" tanks created by the C++ code.
        if(cap < 1) { continue; }

        title = tcell(fuelTable, "text", i+1, 0);
        title.set("label", tname);
        title.set("halign", "right");

        sel = tcell(fuelTable, "checkbox", i+1, 1);
        sel.set("property", tankprop ~ "/selected");
        sel.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

        slider = tcell(fuelTable, "slider", i+1, 2);
        slider.set("property", tankprop ~ "/level-lbs");
        slider.set("min", 0);
        slider.set("max", cap * ppg);
        slider.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

        lbs = tcell(fuelTable, "text", i+1, 3);
        lbs.set("property", tankprop ~ "/level-lbs");
        lbs.set("label", "0123456789");
        lbs.set("live", 1);
        
        gals = tcell(fuelTable, "text", i+1, 4);
        gals.set("property", tankprop ~ "/level-gal_us");
        gals.set("label", "0123456789");
        gals.set("live", 1);
    }

    weightArea = contentArea.addChild("group");
    weightArea.set("layout", "vbox");
    weightArea.addChild("text").set("label", "Payload");

    weightTable = weightArea.addChild("group");
    weightTable.set("layout", "table");

    weightArea.addChild("empty").set("stretch", 1);

    tcell(weightTable, "text", 0, 0).set("label", "Location");
    tcell(weightTable, "text", 0, 2).set("label", "Pounds");

    wgts = props.globals.getNode("/sim").getChildren("weight");
    for(i=0; i<size(wgts); i=i+1) {
        w = wgts[i];
        wname = w.getNode("name", 1).getValue();
        max = w.getNode("max-lb", 1).getValue();
        wprop = "/sim/weight[" ~ i ~ "]/weight-lb";

        title = tcell(weightTable, "text", i+1, 0);
        title.set("label", wname);
        title.set("halign", "right");

        slider = tcell(weightTable, "slider", i+1, 1);
        slider.set("property", wprop);
        slider.set("min", 0);
        slider.set("max", max);
        slider.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

        lbs = tcell(weightTable, "text", i+1, 2);
        lbs.set("property", wprop);
        lbs.set("label", "0123456789");
        lbs.set("live", 1);
    }

    # All done: pop it up
    fgcommand("dialog-new", dialog.prop());
    showDialog(name);
}
