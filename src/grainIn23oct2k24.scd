///////////////////////////////////////////////////////////////////////////////////////////
//////////////////// 2 ////////////////////////////////////////////////////////////////////
//////////////// pas de fft ///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
s.boot
(
Routine.new({
	/*
MIDIClient.init;
MIDIIn.connectAll;
MIDIClient.sources;
MIDIFunc.trace(true);
//MIDIFunc.trace(false);
	*/
///////////////////////////////////////////////
Buffer.freeAll;
~b = Buffer.alloc(s, s.sampleRate * 1);
//~b.zero;
//~b.plot
s.sync;
//////////////////////////////////////////////////////
//~env = Env([0, 1, 1, 0], [0.01, 0.01, 0.01], \sine);  // sine shape
//e =	Env([0, 1, 0], [0.01, 1], [0, -4]);  // perc
//~grainEnv = Buffer.sendCollection(s, e.discretize(2048));
//~env.plot;
//s.sync;
///////////////////////////////////////////////////////////////////////////////
///////////////////////// séparer run et freeze
SynthDef(\liveG, {
		arg buf = 0,
		ptrDelay = 0.4,
		pitch = 1;
	var sigIn, ptr, grain, trig, max, chain,
	lectPhase, sig, densJitter, maxGrainDur,
		env;

	sigIn = HPF.ar(SoundIn.ar(0), 30, 1);

	densJitter = LFDNoise1.kr(53).bipolar(\densJitter.kr(0.01));

	trig = Trig1.ar(\start.tr(0), ControlDur.ir);
	max = Sweep.ar(trig, SampleRate.ir * \run.kr(1));
	ptr = Phasor.ar(trig, \lect.kr(1) * \freeze.kr(1), 0, max, 0);


		maxGrainDur = ptrDelay / pitch;

		// env = SinOsc.ar(ptr, 3pi/2);
	// env = SinOsc.ar(\freq.kr(500));

RecordBuf.ar(sigIn, ~b, 0, \rec.kr(1).lag(0.2), \keep.kr(0.8).lag(0.2), 1,
 \loop.kr(1), doneAction:0);

 grain =	GrainBuf.ar(1,

			Impulse.ar(
				{ExpRand(8.0, 8.4)}!2
				* \densité.kr(2) + densJitter, 0, 0.5),

			min(0.04, maxGrainDur) * \dur.kr(1/3) * (1 / \densité.kr(2)),   // la durée est couplée aux nb de grains

  	 ~b,

		pitch,

    	ptr - (ptrDelay * SampleRate.ir)
	+ LFNoise1.ar(\noizFreq.kr(131)!2).bipolar(SampleRate.ir * \lectJitter.kr(0.005) * \denstié.kr(2))
      / BufFrames.ir(~b),

			2,
			0,
     -1,
			512
		);


grain = BHiPass.ar(grain, \hp.kr(100).varlag(0.1), 1, 1);
grain = LPF.ar(grain, \lp.kr(12000).varlag(0.1), 1);
grain = Splay.ar(grain);
		Out.ar(0, grain * \amp.kr(1));
}).add;
s.sync;
});

~grainLive = Synth(\liveG, [\start, 1, \run, 1]);
/*
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//////////// midi ctrls
~midiDefsA = [
	\ctrlRec,          // fader 1          korg nanoKontrol
	\ctrlPre,          // fader 2
	\ctrlAmp,          // fader 3
	\ctrlLectPhase,    // pot 1
	\ctrlEvents,       // pot 2
	\ctrlDur,          // pot 3
	\ctrlPitch,        // pot 4
	\ctrlJitter,       // pot 5
	\ctrlWipe,         // pot 6
	\ctrlScramble,     // fader 6
	\ctrlHp,           // pot 7
	\ctrlLp            // pot 8
];

~argsA = [
	\rec,
	\pre,
	\amp,
	\lectPhase,
	\events,
	\dur,
	\pitch,
	\jitter,
	\wipe,
	\scramble,
	\hp,
	\lp
];
////////////////////////////////////////////////////////// mapping midi
~ctrlA = [[ControlSpec(0.01, 1, \exp, 0)],       // rec
          [ControlSpec(0.01, 1, \exp, 0)],       // pre
          [ControlSpec(0.01, 10, \exp, 0)],      // amp
          [ControlSpec(0.01, 1.5, \exp, 0)],     // lect
          [ControlSpec(0.3, 14, \exp, 0)],       // events
          [ControlSpec(0.005, 1.9, \exp, 0)],    // dur
          [ControlSpec(0.125, 2, \exp, 0)],      // pitch
          [ControlSpec(0.01, 3, \exp, 0)],       // jitter
          [ControlSpec(0.1, 0.9, \exp, 0)],      // wipe
          [ControlSpec(0.1, 10, \exp, 0)],       // scramble
          [ControlSpec(20, 7000, \exp, 0)],      // hp
          [ControlSpec(40, 14000, \exp, 0)]      // lp
 ].flat;
//////////////////////////////////////////////// numéros de cc midi
~ccNbsA = [
	2,        // rec             taux d'enregistrement
	3,        // pre             taux de la loop déjà enregistrée (127 = la loop reste à l'infini)
	4,        // amp             volume
	12,       // lect            vitesse de lecture
	13,       // events          densité des grains
	14,       // dur             durée des grains
	15,       // pitch           hauteur
	16,       // jitter          vitesse de lecture random
	19,       // wipe            fft dry/wet
	8,        // scramble        vitesse modulation bins fft
	20,       // hp              filtre passe-haut
	21,       // lp              filtre passe-bas
];
//////////////////////////////////////////////////////////////////// MIDIdefs
12.collect({
	arg i;
	MIDIdef.cc(~midiDefsA[i], {
		arg val;
		x.set(~argsA[i], ~ctrlA[i].map(val / 127));
	}, ~ccNbsA[i]
	);
});
////////////////////////////////////////////////////////////////////////////////////////////////////////
// à assigner à un switch: tant qu'on est appuyé, ça redémarre et enregistre la durée de la loop
MIDIdef.cc(\ctrlLooper, {
	arg val;
	x.set(\start, val / 127, \run, val / 127);
	x.set(\start, val / 127);
}, 45);   // ici cc 45
// korg nanoKontrol bouton 'rec'
///////////////////////////////////////////////////////////////////////////////////////////////////////
// à assigner à un switch: tant qu'on est appuyé, ça freeze la lecture
MIDIdef.cc(\ctrlFreeze, {
	arg val;
	x.set(\freeze, 1 - (val / 127) );
}, 42);     // ici cc 42
// korg nanoKontrol bouton 'stop'
///////////////////////////////////////////////////////////////////////////////// presets
~midiDefsB = [
	\lectPhaseBackToNorm,   // solo 1                  korg nanoKontrol
	\lectHalfSpeed,         // mute 1
	\lectSlowSpeed,         // record 1
	\pitchBackToNorm,       // solo 4
	\pitchReverse,          // mute 4
	\pitchOneOctDown        // record 4
];

~argsB = [
	\lectPhase,
	\lectPhase,
	\lectPhase,
	\pitch,
	\pitch,
	\pitch
];

~ctrlB = [
	1,       // lecture normale
	0.5,     // 1/2
	0.01,    // très lent
	1,       // hauteur normale
	-1,      // à l'envers
	0.5      // octave en dessous
];
///////////////////////////////////////////// numéros midi cc à assigner à des switches
~ccNbsB = [
	22,                       // lecture normale
	30,                       // lecture vitesse 1/2
	38,                       // lecture très lente
	25,                       // hauteur normale
	33,                       // lecture à l'envers
	41                        // octave en dessous
];
///////////////////////////////////////////////////////////////
6.collect({
	arg i;
	MIDIdef.cc(~midiDefsB[i],
		{
			arg val;
			x.set(~argsB[i], ~ctrlB[i])
		}, ~ccNbsB[i]
	);
});
*/
///////////////////////////////////////////////////////////////////////
//////////////////////////////// preset valeurs standard d'un coup
MIDIdef.cc(\setValeursNom, {
	10.do({
		arg i;
		~grainLive.set(~argsSliders[i], ~valeursNom[i]);
	});
}, 60);                              // cc 60 reset les paramètres (normal), à assigner à un switch one shot
                                     // korg nanoKontrol bouton 'set'
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// GUI
Window.closeAll;
w = Window(" ", Rect(
		 Window.screenBounds.width * 0.28,            // left
	   Window.screenBounds.height * 0.4,            // top
                                  340,            // width
	                                380             // height
))
.front
.alwaysOnTop_(true)
.background_(Color.new255(120, 117, 120));

v = Color.new255(130, 220, 130); // vert clair

~font = Font("Courier", 11);
/////////////////////////////////////////////////////////////////////////////////////////
~argsSliders = [
		    \rec,
		    \keep,
		    \lect,
		    \lectJitter,
        \pitch,
		    \densité,
		    \densJitter,
        \dur,
	      \hp,
	      \lp,
		    \amp
               ];
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////// textes sliders
~textes = 11.do({
	arg i;
	var textList = [
				         "rec",
				         "keep",
				         "lect",
				         "lectJitter",
                 "pitch",
				         "densité",
				         "densJitter",
		             "durée",
		             "hipass",
		             "lowpass",
				         "amp"
	                ];

StaticText(w, Rect(5, 5 + (19 * i), 70, 20))
	.font_(~font)
	.string_(textList[i]);
 });
///////////////////////////////////////////////////////////////////////////////
//////////////////////////////// mapping sliders
~ctrlSliders = [
		     ControlSpec(0, 1, \lin, 0),                 // 0 rec
         ControlSpec(0, 1, \lin, 0),                 // 1 keep
         ControlSpec(0.005, 1.5, \exp, 0),           // 2 lect
         ControlSpec(0.0001, 1, \exp, 0),            // 3 lect jitter
         ControlSpec(-2, 2, \lin, 0),                // 4 pitch
	       ControlSpec(0.7, 10, \exp, 0),                // 5 densité
	       ControlSpec(0, 100, \lin, 0),               // 6 densité jitter
	       ControlSpec(0.02, 4, \exp, 0),            // 7 durée
	       ControlSpec(10, 10000, \exp, 0),            // 8 hipass
	       ControlSpec(30, 16000, \exp, 0),            // 9 lowpass
         ControlSpec(0.001, 4, \exp, 0)              // 10 amp
               ];
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// sliders principaux
~valeursNom = [           // départ
	1,       // rec
	0.8,     // keep
	1,       // lect
	0.005,   // lect jitter
	1,       // pitch
	2,       // dens
	1,       // densité jitter
	1/3,     // dur
  100,      // hipass
	12000,   // lowpass
  1        // amp
              ];
/////////////////////////////////////////////////////////////
~slidersBase = 11.collect({
	arg i;
		Slider(w, Rect(75, 5 + (19 * i), 240, 16))
			.background_(Color.black)
	    .knobColor_(Color.magenta)
			.thumbSize_(18)
	.action_({
      arg obj;
		~grainLive.set(~argsSliders[i], ~ctrlSliders[i].map(obj.value));
 });
});
~slidersBase.do({
	arg i, index;
		i.value_(~ctrlSliders[index].unmap(~valeursNom[index]));
});
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////// freeze
~freezeSwitch =	Button(w, Rect(75, 225, 72, 20))
.states_([
	["freeze", Color.black, v],
	["go", Color. magenta, Color.black],
])
.font_(~font)
.action_({
	arg b;
	if (
		b.value == 1,
	{~grainLive.set(\freeze, 0)},
	{~grainLive.set(\freeze, 1)});
 });
///////////////////////////////////////////////////////////////////////////////
//////////////////// stop rec,  keep = hold
~lectNormSwitch =	Button(w, Rect(75, 269, 72, 20))
.states_([
	["lockBuf", Color.black, v]
])
.font_(~font)
.action_({
~slidersBase[0].valueAction_(~ctrlSliders[0].unmap(0));
~slidersBase[1].valueAction_(~ctrlSliders[1].unmap(1));
});
///////////////////////////////////////////////////////////////////////////////
//////////////////// set loop
~setLoopSwitch =	Button(w, Rect(75, 247, 72, 20))
.states_([
	["setLoop", Color.black, v],
	[".->", Color.magenta, Color.black]
])
.font_(~font)
.action_({
	arg b;
   if(
		b.value == 1,
{~grainLive.set(\start, 1, \run, 1)},
{~grainLive.set(\run, 0)});
});
///////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// pitch controls
~pitchPresets = [
	1,
	-1,
	-5.midiratio,
	5.midiratio,
	-12.midiratio
];

~pitchPresetsTexts = [
	"pitch = 1",
	"reverse",
	"quinte -",
	"quinte +",
	"octave -"
];

5.collect({
	arg i, index;
	Button(w, Rect(150, 225 + (22 * i), 72, 20))
.states_([
		[~pitchPresetsTexts[i], Color.black, v]
	])
.font_(~font)
.action_({
		~slidersBase[4].valueAction_(~ctrlSliders[4].unmap(~pitchPresets[i]));
 });
});
///////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// lect controls
~lectPresets = [
	1,
	1/2,
	1/10,
	1/100
];

~lectPresetsTexts = [
	"lectNorm",
	"lect 1/2",
	"lect 1/10",
	"lect 1/100"
];

4.collect({
	arg i, index;
	Button(w, Rect(225, 225 + (22 * i), 72, 20))
.states_([
		[~lectPresetsTexts[i], Color.black, v]
	])
.font_(~font)
.action_({
		~slidersBase[2].valueAction_(~ctrlSliders[2].unmap(~lectPresets[i]));
 });
});

)


~grainLive.set(\pitchJitter, 0.0)

(
~grainLive.free;
Window.closeAll;
)

(
MIDIIn.connectAll;
w = Window("MIDI ctrl").front
.layout_(VLayout(
	StaticText( ).align_(\center)
	.string_("press a key on your MIDI klavier"),
	~mumBox = NumberBox( ).align_(\center)
	.enabled_(false)
	.font_(~font);
));
MIDIdef.noteOn(\recieve,
	{
		arg vel, num;
		{~numBox.value_(num)}.defer;
	}
);
)
////////////////////////////////////////////////////////////////////////////
(
var env = Env.new([0, 1, 0], [0.01, 1], [0, -4]);
~grainEnv = Buffer.loadCollection(s, env.discretize(8192));
//~grainEnv.plot
)

(
{
	GrainBuf.ar(
		2,
		Dust.kr([40, 41]),
		0.05,
		~buf,
		1,
		Line.kr(0, 1, BufDur.ir(~buf) * 1/2),
		2,
		0,
		-1
	)
}.play;
)

~b.plot

e = Env([0, 1, 0], [0.01, 1], [0, -4])
e.plot

(
b = Buffer.readChannel(s,"/Users/vinz/Desktop/sp/sndzA/SunRaTalkCut.C.wav",
	channels: [0]);
)
s.boot
b.plot
b.sampleRate

~grainLive.set(\pitch, 1)
~grainLive.set(\freq, 300)

s.quit