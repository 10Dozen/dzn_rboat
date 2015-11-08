// ***********************************************
// 		 DZN ROWING BOAT 
// ***********************************************
// ***********************************************
// 		 SETTINGS 
// ***********************************************

dzn_rboat_fatigueCost		= 0.05; 	// how many fatigue is spent on each row action
dzn_rboat_fatigueLimit		= 0.95;	// fatigue limit to row
dzn_rboat_classlist 		= ["B_Boat_Transport_01_F"];	// List of units classnames can be applied

// Class characterstics in format - [ @Classname, [@Time, @AccelerationPerRow, @MaxRowSpeed (KPH)] ]
dzn_rboat_classSettings = [
	["B_Boat_Transport_01_F", [1, 1, 12]]
];



// ***********************************************
// 		 FUNCTIONS 
// ***********************************************

dznKK_fnc_setRelativeVelocityModelSpaceVisual = {
	params["_o","_speed","_maxVel"];
	private "_rVel";	
	_rVel = velocityModelSpace _o;
	_speed = (_rVel select 1) + _speed;
	
	if (_speed > 0) then {
		if (_speed > _maxVel) then { _speed = _maxVel };	
	} else {
		if (_speed < _maxVel*(-1)) then { _speed = _maxVel * (-1) };
	};
	
	_o setVelocity (
		_o modelToWorldVisual [_rVel select 0, _speed, _rVel select 1] vectorDiff (
			_o modelToWorldVisual [0,0,0]
		)
	);
};

dzn_fnc_rboat_init = {		
	if (isServer || isDedicated) then {
		dzn_rboat_list = [];
		
		{
			if ((typeOf _x) in dzn_rboat_classlist) then {
				sleep 1;
				_x spawn dzn_fnc_rboat_initUnit;
				dzn_rboat_list pushBack _x;	
			};	
		} forEach (entities "All");
		publicVariable "dzn_rboat_list";
	};	
	
	waitUntil {!isNil "dzn_rboat_list"};
	if (hasInterface) then {
		private "_listOfNames";
		_listOfNames = "";
		{
			_listOfNames = format [
				"%1  - %2<br />"
				, _listOfNames
				, getText(configFile >> "CfgVehicles" >> _x >> "displayname")
			];
		} forEach dzn_rboat_classlist;
		
		player createDiarySubject ["dzn_rboat_page","Rowing Boats"];
		player createDiaryRecord [
			"dzn_rboat_page"
			, [
				"Note",
				format [
					"There are some boats you can move without engine turned on.
					<br />%1
					<br />Controls are:
					<br /><font color='#12C4FF'>Left SHIFT</font> - row forward.
					<br /><font color='#12C4FF'>Right SHIFT</font> or <font color='#12C4FF'>J</font> - row backward."
					, _listOfNames
				]
			]
		];
		
		[] spawn {
			dzn_rboat_isKeyPressed = false;
			waitUntil { !(isNull (findDisplay 46)) }; 
			(findDisplay 46) displayAddEventHandler ["KeyDown", "_handled = _this call dzn_fnc_rboat_onKeyPressed"];
		};		
	};
	
	["dzn_rboat", "onEachFrame", {
		{
			if (_x getVariable "dzn_rboat_timeout" < time && { !(isEngineOn _x) } ) then {
				private  "_velOpt";
				_velOpt = _x getVariable "dzn_rboat_receivedVelocity";
				if ( _velOpt select 0 ) then {
					[
						_x
						, (_x getVariable "dzn_rboat_speed") * (_velOpt select 1)
						, _x getVariable "dzn_rboat_maxSpeed"
					] call dznKK_fnc_setRelativeVelocityModelSpaceVisual;					
					_x setVariable ["dzn_rboat_receivedVelocity", [false], true];
				};
			
				_x setVariable ["dzn_rboat_timer", time + (_veh getVariable "dzn_rboat_timeout"), true];
			};		
		} forEach dzn_rboat_list;	
	}] call BIS_fnc_addStackedEventHandler;
};

dzn_fnc_rboat_initUnit = {
	// @Vehicle call dzn_fnc_rboat_initUnit	
	params["_veh"];
	private "_settings";	
	_settings = ([dzn_rboat_classSettings, { (_x select 0) isEqualTo (typeOf _veh) }] call BIS_fnc_conditionalSelect) select 0 select 1;	
	
	/*
		dzn_rboat_timeout 	- how often velocity change may be applied
		dzn_rboat_speed 		- model Y-vector speed
	*/
	_veh setVariable ["dzn_rboat_timeout", (_settings select 0), true];	
	_veh setVariable ["dzn_rboat_speed", (_settings select 1), true];
	_veh setVariable ["dzn_rboat_maxSpeed", (_settings select 2)*1000/3600, true];
	
	_veh setVariable ["dzn_rboat_timer", time + (_veh getVariable "dzn_rboat_timeout"), true];
	_veh setVariable ["dzn_rboat_receivedVelocity", [false], true];	
};

dzn_fnc_rboat_rowClient = {	
	if (vehicle player == player || { !(typeOf (vehicle player) in dzn_rboat_list) }) exitWith {};	
	if (isEngineOn (vehicle player)) exitWith {
		501 cutText ["You need to turn engine off to row","PLAIN DOWN", 1];
	};	
	if (getFatigue player > 0.8) exitWith {
		501 cutText ["You are too tired to row. Get a break!","PLAIN DOWN", 1];		
	};
	
	private["_dirMultiplier","_msg","_updatedFatigue"];
	_updatedFatigue = getFatigue player + dzn_rboat_fatigueCost;
	_dirMultiplier = 0;
	_msg = "";
	if (_this == "forward") then {
		_dirMultiplier = 1;
		_msg = "Rowing forward";
	} else {
		_dirMultiplier = -1;
		_msg = "Rowing backward";
	};	
	
	(vehicle player) setVariable ["dzn_rboat_receivedVelocity", [true, _dirMultiplier], true];
	501 cutText [_msg,"PLAIN DOWN", 1];
	player setFatigue (if (_updatedFatigue > 1) then { 1 } else { _updatedFatigue });
};

dzn_fnc_rboat_onKeyPressed = {
	if (!alive player || dzn_rboat_isKeyPressed) exitWith {};	
	private["_key","_shift","_crtl","_alt","_handled"];	
	_key = _this select 1;
	_handled = false;

	switch _key do {
		// LShift button
		case 42: {
			dzn_rboat_isKeyPressed = true;
			"forward" call dzn_fnc_rboat_rowClient;
			_handled = true;
		};
		// 'J' and RShift
		case 36;
		case 54: {
			dzn_rboat_isKeyPressed = true;
			"backward" call dzn_fnc_rboat_rowClient;
			_handled = true;
		};
	};
	
	[] spawn { sleep 1; dzn_rboat_isKeyPressed = false; };
	
	_handled
};

// ***********************************************
// 		 INIT 
// ***********************************************
[] spawn dzn_fnc_rboat_init;
