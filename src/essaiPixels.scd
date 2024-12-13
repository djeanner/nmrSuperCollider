(
Window.closeAll;
w = Window.new("", Rect(1200, 500, 400, 400))
.alwaysOnTop_(true)
.background_(Color.gray(0.1))
.front;
)

(
~make = {
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		20.rand, 20.rand)
	).background_(Color.rand);
	0.02; // waiting time
};
)

~make.value;

AppClock.sched(2, ~make);
/////////////////////////////////////////////////////////////
(
Window.closeAll;
w = Window.new("", Rect(500, 780, 1000, 1000)) // big
.alwaysOnTop_(true)
.background_(Color.gray(0.1))
.front;
)

(
// points verts et bleus
~make01 = {
	View.new(w, Rect(
		rrand(0, w.view.bounds.width - 5), // x position
		rrand(0, w.view.bounds.height - 5), // y position
		5.rand, 5.rand)
	).background_(Color.new255(0, 255.rand, 255.rand));
	0.001; // waiting time
};
)
AppClock.sched(1, ~make01);

(
// points verts, rouges et jaunes
~make02 = {
	View.new(w, Rect(
		rrand(0, w.view.bounds.width - 5), // x position
		rrand(0, w.view.bounds.height - 5), // y position
		5.rand, 5.rand)
).background_(Color.new255(200.rand, 255.rand, 64.rand));
	0.002; // waiting time
};
)
AppClock.sched(1, ~make02);

(
// points verts, rouges et jaunes
~make03 = {
	View.new(w, Rect(
		rrand(0, w.view.bounds.width - 5), // x position
		rrand(0, w.view.bounds.height - 5), // y position
		5.rand, 5.rand)
	).background_(Color.new255([0, 32, 64, 128, 255].choose,
		[0, 32, 64, 128, 255].choose, 64.rand));
	0.002; // waiting time
};
)
AppClock.sched(1, ~make03);

(
// points rgb
~make04 = {
	var arr = [0, 32, 64, 128, 255, 16, 16, 16];
	View.new(w, Rect(
		rrand(0, w.view.bounds.width - 5), // x position
		rrand(0, w.view.bounds.height - 5), // y position
		5.rand, 5.rand)
	).background_(Color.new255(arr.choose,
		arr.choose, 128.rand));
	0.002; // waiting time
};
)
AppClock.sched(1, ~make04);

(
// lignes rgb avec masque alpha
~make05 = {
	var arr = [0, 32, 32, 64, 128, 255, 16, 16, 16];
	var longueurX = Array.geom(7, 1, 4);
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		longueurX.choose, [1, 1, 1, 1, 1, 1, 1, 1, 2].choose)
	).background_(Color.new255(arr.choose,
		arr.choose, 128.rand, alpha: 63 + (64.rand)));
	0.025; // waiting time
};
)
AppClock.sched(1, ~make05);

(
// grands carrés rgb avec masque alpha
~make06 = {
	var arr = [0, 32, 32, 64, 128, 255, 16, 16, 16];
	var val = Array.series(280, 1, 1);
	val = val.choose;
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		val, val)
	).background_(Color.new255(arr.choose,
		arr.choose, 32 + (64.rand), alpha: 63 + (64.rand)));
	0.5; // waiting time
};
)
AppClock.sched(1, ~make06);

(
// petits carrés rgb rapides avec masque alpha
~make07 = {
	var arr = [0, 32, 64, 128, 255, 16, 16, 16, 8, 8];
	var val = Array.series(40, 1, 1);
	val = val.choose;
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		val, val)
	).background_(Color.new255(arr.choose,
		arr.choose, arr.choose, alpha: 32 + (32.rand)));
	0.01; // waiting time
};
)
AppClock.sched(1, ~make07);
/////////////////////////////////////////////////////////////////////
(
// lignes et carrés rgb avec masque alpha
~make08 = {
	var arr01 = [0, 32, 32, 64, 128, 255, 16, 16, 16]; // lignes
	var arr02 = [0, 32, 32, 64, 128, 255, 16, 16, 16]; // carrés
	var val = Array.series(280, 1, 1); // carrés
	var longueurX = Array.geom(7, 1, 4);
// lignes
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		longueurX.choose, [1, 1, 1, 1, 1, 1, 1, 1, 2].choose)
	).background_(Color.new255(arr01.choose,
		arr01.choose, 255.rand, alpha: 128 + (64.rand)));
// carrés
		val = val.choose;
	View.new(w, Rect(
		rrand(0, w.view.bounds.width), // x position
		rrand(0, w.view.bounds.height), // y position
		val, val)
	).background_(Color.new255(arr02.choose,
		arr02.choose, 32 + (64.rand), alpha: 32 + (64.rand)));
	0.25; // waiting time
};
)
AppClock.sched(1, ~make08);

s.quit;

MIDISyncClock
/////////////////////////////////////////////////////////////////////
(
Window.closeAll;
w = Window.new("", Rect(1200, 500, 400, 400))
.alwaysOnTop_(true)
.background_(Color.gray(0.1))
.front;
)

(
// lignes rgb avec masque alpha
~make08 = {
	var arr01 = [0, 32, 32, 64, 128, 255, 16, 16, 16]; // lignes
	var val = Array.series(280, 1, 1); // carrés
	var longueurX = Array.geom(7, 1, 4);
// lignes
	View.new(w, Rect(
		100, // x position
		rrand(200, w.view.bounds.height - 20), // y position
		100, 1)
	).background_(Color.new255(arr01.choose,
		arr01.choose, 255.rand, alpha: 128 + (64.rand)));

	0.01; // waiting time
};
)
AppClock.sched(1, ~make08);

w.bounds.width
/////////////////////////////////////////////////////////////////////////////
(
	// lignes rgb avec masque alpha
~make08 = {
	var arr01 = [32, 32, 64, 128, 255, 16]; // lignes

		~grisVal = {10 + 246.rand}.value;

//	var longueurX = Array.geom(7, 1, 4);
// lignes
	View.new(w, Rect(
		285, // x position
		rrand(590, w.view.bounds.height - 15), // y position
		55, 1 + 2.rand)
	).background_(Color.new255(
		200-	~grisVal,
		     ~grisVal,
		200-	~grisVal,
			alpha: 9 + (64.rand)));

	0.005; // waiting time
};
)


AppClock.sched(1, ~make08);



















