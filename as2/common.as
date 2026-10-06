// ActionScript 2. Runs inside the original AVM1 Flash engine.
_root.gm3Token = _root.gm3Token == undefined ? "default" : _root.gm3Token;
_root.gm3Out = new LocalConnection();
_root.gm3Out.onStatus = function(info) {};
function gm3Send(method, value) {
    _root.gm3Out.send("_gm3_air_" + _root.gm3Token, method, value);
}
function gm3Round(n) { return Math.round(n * 100) / 100; }
