
///Used to translate internal action names to human-readable names.
var/list/action_names = list(

	"attackself" = "Use in-hand",
	"togglethrow" = "Throw (Toggle)",
	"swaphand" = "Swap Hand",
	"equip" = "Equip",
	"resist" = "Resist",

	"fart" = "Fart",
	"flip" = "Flip",
	"eyebrow" = "Raise Eyebrow",
	"gasp" = "Gasp",
	"raisehand" = "Raise Hand",
	"dance" = "Dance",
	"laugh" = "Laugh",
	"nod" = "Nod",
	"wave" = "Wave",
	"wink" = "Wink",
	"flex" = "Flex",
	"yawn" = "Yawn",
	"snap" = "Snap",
	"scream" = "Scream",
	"salute" = "Salute",
	"burp" = "Burp",

	"help" = "Help Intent",
	"disarm" = "Disarm Intent",
	"grab" = "Grab Intent",
	"harm" = "Harm Intent",

	"look_n" = "Look North",
	"look_s" = "Look South",
	"look_w" = "Look West",
	"look_e" = "Look East",

	"say" = "Say",
	"say_radio" = "Say Radio",
	"dsay" = "Dead Say",
	"asay" = "Admin Say",
	"whisper" = "Whisper",
	"ooc" = "OOC",
	"looc" = "LOOC",

	"screenshot" = "Screenshot",
	"autoscreenshot" = "Auto Screenshot",

	"head" = "Target Head",
	"chest" = "Target Chest",
	"l_arm" = "Target Left Arm",
	"r_arm" = "Target Right Arm",
	"l_leg" = "Target Left Leg",
	"r_leg" = "Target Right Leg",

	"walk" = "Walk (Toggle)",
	"rest" = "Rest (Toggle)",

	"module1" = "Module 1",
	"module2" = "Module 2",
	"module3" = "Module 3",
	"module4" = "Module 4",

	"unequip" = "Unequip (Silicon)",
	"pickup" = "Pick Up",
	"drop" = "Drop",

	"fire" = "Fire",
	"fire_secondary" = "Fire Secondary",
	"stop" = "Stop",
	"alt_fire" = "Alternate Fire",
	"cycle" = "Cycle Shell",
	"exit" = "Exit",

	"mentorhelp" = "Mentor Help",
	"adminhelp" = "Admin Help",

	"togglepoint" = "Toggle Pointing",
	"refocus"   = "Refocus Window",
	"mainfocus" = "Focus Main Window",

	"admin_interact" = "Admin Interact",

	"module1" = "Module 1",
	"module2" = "Module 2",
	"module3" = "Module 3",
	"module4" = "Module 4"
)

///Used for literal input of actions
var/list/action_verbs = list(
	"say" = "say",
	"say_radio" = "say_radio",
	"emote" = "say *customv",
	"salute" = "say *salute",
	"burp" = "say *burp",
	"dab" = "say *dab",
	"dance" = "say *dance",
	"eyebrow" = "say *eyebrow",
	"fart" = "say *fart",
	"flip" = "say *flip",
	"gasp" = "say *gasp",
	"raisehand" = "say *raisehand",
	"laugh" = "say *laugh",
	"nod" = "say *nod",
	"wave" = "say *wave",
	"flip" = "say *flip",
	"scream" = "say *scream",
	"whisper" = "whisper",
	"wink" = "say *wink",
	"flex" = "say *flex",
	"yawn" = "say *yawn",
	"snap" = "say *snap",
	"pickup" = "pick-up",
	"ooc" = "ooc",
	"looc" = "looc",
	"dsay" = "dsay",
	"asay" = "asay",
	"adminhelp" = "adminhelp",
	"mentorhelp" = "mentorhelp",
	"autoscreenshot" = ".autoscreenshot",
	"screenshot" = ".screenshot",
	"togglepoint" = "togglepoint",
	"refocus"   = ".winset \\\"mainwindow.input.focus=true;mainwindow.input.text=\\\"\\\"\\\"",
	"mainfocus" = ".winset \"mainwindow.input.focus=false;mapwindow.map.focus=true;mainwindow.input.text=\"\"\"",
	//"lazyfocus" = ".winset \\\"mainwindow.input.focus=true\\\"",
	"Admin Interact" = "admin_interact"
)

///Used to translate bitflags of hotkeys into human-readable names
var/list/key_names = list(
	"[KEY_FORWARD]" = "Up",
	"[KEY_BACKWARD]" = "Down",
	"[KEY_LEFT]" = "Left",
	"[KEY_RIGHT]" = "Right",
	"[KEY_RUN]" = "Run",
	"[KEY_THROW]" = "Throw",
	"[KEY_POINT]" = "Point",
	"[KEY_EXAMINE]" = "Examine",
	"[KEY_PULL]" = "Pull",
	"[KEY_OPEN]" = "Open",
	"[KEY_BOLT]" = "Bolt",
	"[KEY_SHOCK]" = "Electrify"
)
