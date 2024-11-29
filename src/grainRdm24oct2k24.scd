(
Server.default.options.memSize = 2.pow(20);
s.waitForBoot({
	Buffer.freeAll;
~folder = PathName.new("/Users/vinz/Desktop/sp/sndzB/");
~sndz = ~folder.entries.collect({
	arg i;
	Buffer.readChannel(s, i.fullPath, channels: [0]);
});
///////////////////////////////////////////////////////////////////////////
//////////////////////////////////// enveloppe maison
~env = Env([0, 1, 1, 0], [0.01, 0.01, 0.01], \sine);  // sine shape
//~env.plot;
~grainEnv = Buffer.sendCollection(s, ~env.discretize(1024));  // pour buffer
////////////////////////////////////////////////////////////////////////////
////////////////////////////// synthDef ////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
~inharmo = [72, 135, 173, 239, 267, 306, 355, 473].collect({arg i; 100/i});

SynthDef(\grain, {
	arg trig = 50,
	rateLect = 0.1,
	pitch = 1,
	dur = 0.05,
	vitesseNoizTrig = 1,
	trigJitter = 0,
	vitesseNoizPitch = 1,
	pitchJitter = 0,
	vitesseNoizDur = 1,
	durJitter = 0,
	vitesseNoizRate = 1,
	rampJitter = 0,
	fold = 0.7,    // amplitude entrée wavefolder
	trigOsc = 0,   // Impulse = 0, Dust = 1
	lectMode = 0,  // Phasor = 0, SinOsc = 1, LFDNoise1 = 2, LFDNoise0 = 3
	hp = 200,
	lp = 7000,
	pan = 0,
	buf = 0,
	wipe = 0.1,
	scramble = 0.1,
	amp = 1,
	vitesseNoizHiPass = 1,
	hiPassJitter = 0,
	vitesseNoizLowPass = 100,
	lowPassJitter = 500,
	filt = 12000,
	gate = 1,
  combFreq = 0.01,
	combDecay = -1,
  vitesseNoizComb = 0.1,
  combJitter = 0,
  vitesseNoizDecay = 0.1,
  decayJitter = 0,
	t_start = 1;

	var sig,
	chain,
	inverse,
	trigToStart1 = (1 - (Trig1.kr(t_start, 0.01))),  // retour au début du buffer
	trigToStart2 = (1 - (Trig1.kr(t_start, 0.3))),  // retour au début du buffer
	// mettre BufSamples.kr et pas .ir -> on change les buffers, tailles différentes
  lectRamp = Phasor.ar(0, rateLect, 0, BufSamples.kr(buf) * trigToStart1),
	lectSinus = SinOsc.ar(rateLect / 16 * BufRateScale.kr(buf),
	phase: 0, mul: BufSamples.kr(buf) * trigToStart2),
		lectNoiz = LFDNoise1.ar(rateLect, BufSamples.kr(buf) / 4 * trigToStart2 ),
  lectShNoiz = LFDNoise0.ar(rateLect * 16, BufSamples.kr(buf) * trigToStart2),
	// les modulations sont couplées aux valeurs des arguments/sliders (* trig et * dur/2)
	trigJitterNoise = LFNoise0.kr(vitesseNoizTrig).bipolar(trigJitter * trig),             // modulation trigger
	pitchJitterNoise = LFNoise0.kr(vitesseNoizPitch).bipolar(pitchJitter),                 // modulation pitch
	durJitterNoise = LFDNoise1.kr(vitesseNoizDur).unipolar(durJitter * ((dur/3).exp)),     // modulation durée
	rateJitterNoise = LFDNoise1.ar(vitesseNoizRate).bipolar(rampJitter * SampleRate.ir),   // modulation lecture
  hiPassJitterNoise = LFDNoise1.kr(vitesseNoizHiPass).unipolar(hiPassJitter),            // modulation hipass
	lowPassJitterNoise = LFDNoise1.kr(vitesseNoizLowPass).unipolar(lowPassJitter),         // modulation lowpass
  combJitterNoise = LFDNoise0.ar(vitesseNoizComb).unipolar(combJitter),                  // modulation freq comb
  decayJitterNoise = LFDNoise1.kr(vitesseNoizDecay).bipolar(decayJitter),                // modulation decay

	impulseTrig = Impulse.ar([trig + trigJitterNoise, trig * 1.01 + trigJitterNoise]),  // 2 fois aussi
	dustTrig = Dust.ar([trig + trigJitterNoise, trig * 1.01 + trigJitterNoise]),

	// panMod = TIRand.ar(-1, 1, impulseTrig), // random panoramique à chaque trigger
  // panMod = LFNoise1.kr(40).range(-1, 1);  // pan noise

	env = EnvGen.kr(Env.asr(0.2, 1, 0.2), gate: gate, doneAction: 0);



	sig = GrainBuf.ar(2,                              // nb de canaux
		Select.ar(trigOsc, [impulseTrig, dustTrig]),    // trigger
		dur + durJitterNoise,                           // durée
		buf,                                            // buffer
		pitch + pitchJitterNoise,                       // hauteur
     (                                              // lecture/position
			Select.ar(lectMode, [
			lectRamp + rateJitterNoise,
			lectSinus + rateJitterNoise,
			lectNoiz + rateJitterNoise,
			lectShNoiz + rateJitterNoise
				])
      ) / BufSamples.kr(buf),    // on divise par le nb de samples du buffer -> phasor va de 0 à 1


			2,                         // interpolation, 2: linéaire
	//	panMod,
			0,                         // la stéréo vient du comb filter et des triggers de vitesses différentes
	// ~grainEnv,
			-1,
			512, // max grains
		fold
		);
	  sig = BHiPass.ar(sig, (hp.varlag(0.12) + hiPassJitterNoise).clip(7, 16000));        // 12dB/oct
	  sig = BLowPass4.ar(sig, (lp.varlag(0.12) + lowPassJitterNoise).clip (30, 16000));   // 24dB/oct
	  sig = Fold.ar(sig, -2.7, 3) * amp * env;     // asymétrique
	 chain = FFT({LocalBuf(1024)}!2, sig);
	 chain = PV_RandComb(chain, wipe, Dust.kr(scramble));
	 inverse = IFFT(chain);

		inverse =  inverse  // dry
		+ 8.collect({
			arg i;
       CombC.ar(inverse, 1,
				    combFreq.varlag(0.2) * ~inharmo[i] + combJitterNoise, combDecay + decayJitterNoise, mul: 0.2)
     }).sum;
 inverse = Limiter.ar(inverse, level: 0.5, dur: 0.1);
Out.ar(0, LPF.ar(inverse, filt));   // lowpass pour quand il y a le wavefolder
}).add;
s.sync;
////////////////////////////////////////////////////////////
/////////////////////////////// GUI ////////////////////////
////////////////////////////////////////////////////////////
Window.closeAll;
w = Window(" ", Rect(
		 Window.screenBounds.width * 0.18,
	   Window.screenBounds.height * 0.01,
                                  725, 850))
.front
.alwaysOnTop_(true)
.background_(Color.new255(120, 117, 120));
///////////////////////////////////////////////////////////
v = Color.new255(130, 220, 130); // vert clair
///////////////////////////////////////////////////////////
// ~font = Font("Krungthep", 11);
~font = Font("Courier", 11);
~fontNames = Font("Courier", 23);
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
~normValues = [
	64,       // trig
	1,        // lect
	1,        // hauteur
	0.05,     // durée
	200,      // hipass
	7000,     // lowpass
  0.01,     // comb freq
	-0.5,     // comb decay
  0.2,      // wipe
	0.1,      // scramble
	0.7,      // amp wavefolder
	12000,    // filtre lp
	0.5       // amplitude
  ];

	~args = [
		    \trig,
		    \rateLect,
		    \pitch,
		    \dur,
		    \hp,
		    \lp,
        \combFreq,
		    \combDecay,
        \wipe,
		    \scramble,
		    \fold,
		    \filt,
		    \amp
  ];
///////////////////////////////////////////////////////////////////////////////
////////////////////////// mapping ////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
~ctrl = [
		     ControlSpec(3, 160, \exp, 0),                   // 0 trig
         ControlSpec(0.001, 2, \exp, 0),                 // 1 vitesse lecture
         ControlSpec(-3, 3, \lin, 0),                    // 2 hauteur
         ControlSpec(0.001, 1.5, \exp, 0),               // 3 durée
	       ControlSpec(7, 11000, \exp, 0),                 // 4 hihpass
	       ControlSpec(35, 15000, \exp, 0),                // 5 lowpass
         ControlSpec(0.001, 0.3, \exp, 0),               // 6 comb freq
		     ControlSpec(-0.01, -2, \exp, 0),                // 7 comb decay
         ControlSpec(0.1, 0.8, \exp, 0),                 // 8 wipe
	       ControlSpec(0.05, 13, \exp, 0),                 // 9 scramble
	       ControlSpec(0.2, 11, \exp, 0),                  // 10 amplitude wavefolder
	       ControlSpec(100, 16000, \exp, 0),               // 11 filtre lp
	       ControlSpec(0.009, 10, \exp, 0)                 // 12 amplitude
 ];


// modulations
~argsJitter = [
		           \trigJitter,
		           \rampJitter,
		           \pitchJitter,
		           \durJitter,
		           \hiPassJitter,
		           \lowPassJitter,
		           \combJitter,
		           \decayJitter
 ];

~ctrlJitter = [
		           ControlSpec(0, 1, \lin, 0),                 // trig jitter
               ControlSpec(0, 0.75, \lin, 0),              // lecture jitter
               ControlSpec(0, 2.5, \lin, 0),               // hauteur jitter
               ControlSpec(0, 0.4, \lin, 0),               // durée jitter
               ControlSpec(0.1, 10000, \exp, 0),           // hipass jitter
               ControlSpec(0.1, 10000, \exp, 0),           // lowpass jitter
               ControlSpec(0, 0.03, \lin, 0),              // combFreq jitter
               ControlSpec(0, -3.4, \lin, 0)               // combDecay jitter
];

~argsNoizSpeed = [
		             \vitesseNoizTrig,
		             \vitesseNoizRate,
		             \vitesseNoizPitch,
		             \vitesseNoizDur,
	               \vitesseNoizHiPass,
		             \vitesseNoizLowPass,
		             \vitesseNoizComb,
		             \vitesseNoizDecay
 ];

~ctrlNoizSpeed = [
		              ControlSpec(0.1, 23, \exp, 0),            // trig noise freq
                  ControlSpec(0.1, 11, \exp, 0),            // lecture noise freq
                  ControlSpec(0.1, 29, \exp, 0),            // hauteur noise freq
                  ControlSpec(0.2, 11, \exp, 0),            // durée noise freq
                  ControlSpec(0.1, 37, \exp, 0),            // hipass noise freq
                  ControlSpec(0.1, 37, \exp, 0),            // lowpass noise freq
                  ControlSpec(0.07, 11, \exp, 0),           // combFreq noise freq
                  ControlSpec(0.1, 3, \exp, 0)              // combDecay noise freq
 ];

// mapping de la box numérique pour le pointeur de lecture
~ctrlLectBox = [
		            ControlSpec(0.001, 2, \exp, 0),
	              ControlSpec(0.000125, 0.25, \exp, 0),
	              ControlSpec(0.001, 2, \exp, 0),
	              ControlSpec(0.016, 32, \exp, 0)
 ];
////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////// création des synthés //////
////////////////////////////////////////////////////////////////////////////////////
~synths = [Synth(\grain, [\gate, 0]), Synth(\grain, [\gate, 0])];
////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// noms des synthés
~synthNames = ["a", "b"];
 ~synthName = 2.do({
		arg synthNb;
		StaticText(w, Rect(397, 179 + (synthNb * 425), 52, 52))
.font_(~fontNames)
		.string_(~synthNames[synthNb])     // texte
		.align_(\center)
		.background_(Color.grey(0.2))
		.stringColor_(v);
	});
////////////////////////////////////////////////////////////////////////////////////
~play = 2.collect({
	arg synthNb;
	Button(w, Rect(290, 255 + (synthNb * 425), 52, 20))     /////////////////////// play/stop
.states_([
	["play", Color.black, Color.cyan],
	[ "stop", Color.black, Color.new255(255, 90, 128)]
])
.font_(~font)
	.action_({
		arg b;
	if(
			b.value == 1,
{

     ~synths[synthNb].set(
					// les synthés démarrent avec les valeurs de la GUI
					             \gate, 1,
					             \trig, ~allSliders[synthNb][0].value.linexp(0, 1, 3, 160),
					             \rateLect, ~allSliders[synthNb][1].value.linexp(0, 1, 0.001, 2),
					             \pitch, ~allSliders[synthNb][2].value.linlin(0, 1, -3, 3),
				               \dur, ~allSliders[synthNb][3].value.linexp(0, 1, 0.001, 1.5),
				               \hp, ~allSliders[synthNb][4].value.linexp(0, 1, 7, 11000),
				               \lp, ~allSliders[synthNb][5].value.linexp(0, 1, 35, 15000),
                       \combFreq, ~allSliders[synthNb][6].value.linexp(0, 1, 0.001, 0.2),
						           \combDecay, ~allSliders[synthNb][7].value.linexp(0, 1, -0.001, -2),
                       \wipe, ~allSliders[synthNb][8].value.linexp(0, 1, 0.1, 0.8),
				               \scramble, ~allSliders[synthNb][9].value.linexp(0, 1, 0.05, 13),
				               \fold, ~allSliders[synthNb][10].value.linexp(0, 1, 0.2, 11),
				               \filt, ~allSliders[synthNb][11].value.linexp(0, 1, 100, 16000),
				               \amp, ~allSliders[synthNb][12].value.linexp(0, 1, 0.009, 10),
                    // \buf, ~memsBuf[synthNb][0],

                       \trigJitter, ~allSlidersJitter[synthNb][0].value.linlin(0, 1, 0, 1),
				               \rampJitter, ~allSlidersJitter[synthNb][1].value.linlin(0, 1, 0, 0.75),
				               \pitchJitter, ~allSlidersJitter[synthNb][2].value.linlin(0, 1, 0, 2.5),
				               \durJitter, ~allSlidersJitter[synthNb][3].value.linlin(0, 1, 0, 0.4),
				               \hiPassJitter, ~allSlidersJitter[synthNb][4].value.linexp(0, 1, 0.1, 10000),
				               \lowPassJitter, ~allSlidersJitter[synthNb][5].value.linexp(0, 1, 0.1, 10000),
                       \combJitter, ~allSlidersJitter[synthNb][6].value.linlin(0, 1, 0, 0.02),
				               \combDecayJitter, ~allSlidersJitter[synthNb][7].value.linlin(0, 1, 0, -3.4),

                       \vitesseNoizTrig, ~allSlidersNoizFreq[synthNb][0].value.linexp(0, 1, 0.1, 23),
				               \vitesseNoizRate, ~allSlidersNoizFreq[synthNb][1].value.linexp(0, 1, 0.2, 11),
				               \vitesseNoizPitch, ~allSlidersNoizFreq[synthNb][2].value.linexp(0, 1, 0.1, 29),
				               \vitesseNoizDur, ~allSlidersNoizFreq[synthNb][3].value.linexp(0, 1, 0.1, 11),
				               \vitesseNoizHiPass, ~allSlidersNoizFreq[synthNb][4].value.linexp(0, 1, 0.1, 37),
				               \vitesseNoizLowPass, ~allSlidersNoizFreq[synthNb][5].value.linexp(0, 1, 0.1, 37),
                       \vitesseNoizComb, ~allSlidersNoizFreq[synthNb][6].value.linexp(0, 1, 0.07, 7),
				               \vitesseNoizDecay, ~allSlidersNoizFreq[synthNb][7].value.linexp(0, 1, 0.1, 3)
				).register;

},

		{
				~synths[synthNb].set(\gate, 0);
		}
	);
	});
});
/////////////////////////////////////////// choix trigger
~allTrigChoose = 2.collect({
	arg synthNb;
	~trigChoose = Button(w, Rect(370, 255 + (synthNb * 425), 52, 20))    ////////////////// trigger: impulse ou dust
.states_([
	["imp", Color.black, Color.grey(0.7)],
	[ "dust", Color.black, Color.grey(0.7)]
])
.font_(~font)
 .action_({
	arg b;
 if(
		b.value == 1,
			{~synths[synthNb].set(\trigOsc, 1)},
			{~synths[synthNb].set(\trigOsc, 0)}
	);
  });
});

2.do({
	arg synthNb;
StaticText(w, Rect(383, 232 + (synthNb* 425), 45, 20))
.font_(~font)
.string_("trig")  // texte
//.stringColor_(v)
});
/////////////////////// choix lecture
~allLectChoose = 2.collect({
	arg synthNb;
	~lectChoose = Button(w, Rect(425, 255 + (synthNb * 425), 52, 20))  //////// lecture avec rampe/sinus/noiz/noizS&h
.states_([
	["ramp", Color.black, Color.grey(0.7)],
	["sinus", Color.black, Color.grey(0.7)],
	[ "noiz", Color.black, Color.grey(0.7)],
	[ "shNoiz", Color.black, Color.grey(0.7)]
])
.font_(~font)

.action_({
	arg b;
switch(
		b.value,
		0,{~synths[synthNb].set(\lectMode, 0)},   // ramp
		1,{~synths[synthNb].set(\lectMode, 1)},   // sinus
		2,{~synths[synthNb].set(\lectMode, 2)},   // LFDNoise1
		3,{~synths[synthNb].set(\lectMode, 3)}    // LFDNoise0
	);
});
});

2.do({
	arg synthNb;
StaticText(w, Rect(433, 232 + (synthNb * 425), 45, 20))
.font_(~font)
.string_("lect")  // texte
//.stringColor_(v)
});
//////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////// sliders de base ///////////
//////////////////////////////////////////////////////////////////////////////
~allSliders = 2.collect({
	arg synthNb;
	~slidersBase = 13.collect({
	arg i;
		Slider(w, Rect(65, 5 + (19 * i) + (synthNb * 425), 220, 16))
			.background_(Color.black)
	    .knobColor_(Color.magenta)
			.thumbSize_(18)
	.action_({
			arg obj;
		~synths[synthNb].set(~args[i], ~ctrl[i].map(obj.value));            // snd
			~allSlidersBoxz[synthNb][i].value_(~ctrl[i].map(obj.value));      // number boxes

});
	})
.do({
	arg i, index;
  i.value_(~ctrl[index].unmap(~normValues[index])); // valeurs de départ
 });
});
//////////////////////////////////////////////////////////////////////////////////
2.do({
	arg synthNb;
	~allSliders[synthNb][1].action_({
	arg obj;
	~synths[synthNb].set(~args[1],~ctrl[1].map(obj.value)); /* on overwrite l'itération d'avant (~slidersBase =
	                                                          11.collect{... ) à cause des différents oscillateurs
	                                                          de lecture à dispo */

		switch(                // mapping des valeurs du pointeur de lecture dans la box numérique
		~lectChoose.value,
		0,{~allSlidersBoxz[synthNb][1].value_(~ctrlLectBox[0].map(obj.value))},    // ramp
		1,{~allSlidersBoxz[synthNb][1].value_(~ctrlLectBox[1].map(obj.value))},    // sinus
		2,{~allSlidersBoxz[synthNb][1].value_(~ctrlLectBox[2].map(obj.value))},    // LFDNoise1
		3,{~allSlidersBoxz[synthNb][1].value_(~ctrlLectBox[3].map(obj.value))}     // LFDNoise0
	);
});
});
////////////////////////////////////////////////////// textes
2.do({
	arg synthNb;
~textes = 13.do({
	arg i;
	var textList = [
				         "trig",
				         "lect",
				         "pitch",
				         "dur",
				         "hp",
				         "lp",
                 "combFreq",
				         "combDecay",
                 "fft",
				         "lfo fft",
				         "fold",
				         "filt",
				         "amp"
                 ];

	StaticText(w, Rect(5, 5 + (19 * i) + (synthNb * 425), 60, 20))
	.font_(~font)
  //.stringColor_(v)
	.string_(textList[i]);
 });
});
/////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////// boxes //////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////// combien de décimales pour les boxes
~slidersBoxzDecimals = [
	0,     // trig
	4,     // lect
	2,     // hauteur
	3,     // durée
	0,     // hipass
	0,     // lowpass
  3,     // comb freq
	3,     // comb decay
  2,     // wipe
	2,     // scramble
	2,     // amp wavefold
	0,     // filtre
	2      // amplitude
 ];

///////////////////////////////////////////// boxes d'affichage des sliders de base
~slidersBoxzClipLo = [
		3,        // trig
		0.001,    // lect
		-3,       // hauteur
		0.001,    // durée
		7,        // hipass
		35,       // lowpass
    0.001,    // comb freq
		-2,       // comb decay  (inversé)
    0.1,      // wipe
		0.05,     // scramble
		0.2,      // amp wavefold
		100,      // filtre
		0.009     // amplitude
 ];

~slidersBoxzClipHi = [
		160,       // trig
		2,         // lect
		3,         // hauteur
		1.5,       // durée
		11000,     // hipass
		15000,     // lowpass
    0.2,       // comb freq
		-0.001,    // comb decay  (inversé)
    0.8,       // wipe
		13,        // scramble
		11,        // amp wavefold
		16000,     // filtre
		10         // amplitude
 ];

~slidersBoxzScrollSteps = [
		1,       // trig
		0.0001,  // lect
		0.1,     // hauteur
		0.01,    // durée
		10,      // hipass
		10,      // lowpass
    0.1,     // comb freq
		0.01,    // comb decay
    0.01,    // wipe
		0.1,     // scramble
		0.1,     // amp wavefold
		100,     // filtre
		0.1      // amplitude
 ];

~allSlidersBoxz = 2.collect({
	arg synthNb;
~slidersBoxz = 13.collect({
	arg i;
		NumberBox(w, Rect(290, 5 + (19 * i) + (synthNb * 425), 50, 18))
	.background_(Color.black)
	.font_(~font)
	.normalColor_(v)
	.decimals_(~slidersBoxzDecimals[i])
	.clipLo_(~slidersBoxzClipLo[i])
	.clipHi_(~slidersBoxzClipHi[i])
	.scroll_step_(~slidersBoxzScrollSteps[i])
.action_({
				arg obj;
				 ~allSliders[synthNb][i].valueAction_(~ctrl[i].unmap(obj.value));
	});
})
.do({
	arg i, index;
		i.value_(~normValues[index]);   // afficher les valeurs de départ
 });
});
/////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// pitch ctrls //////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////
~pitchCtrlText = ["octDown", "octUp", "reverse", "+7"];
~pitchCtrls = [0.5, 2, -1, 3/2];
2.collect({
	arg synthNb;
	4.collect({
		arg i;
		Button(w, Rect(65 + (i * 55), 255 + (synthNb * 425), 52, 20))
		.states_([ [~pitchCtrlText[i], Color.black, Color.grey(0.7)]
])
.font_(~font)
.action_({
			~allSliders[synthNb][2].valueAction_(~ctrl[2].unmap(~pitchCtrls[i]));
  });
 });
});
////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// modulations des paramètres ///////////////
////////////////////////////////////////////////////////////////////////////////
~allSlidersJitter = 2.collect({
	arg synthNb;
~slidersJitter = 8.collect({                 // modulation amp ctrl
	arg i;
		Slider(w, Rect(370, 5 + (19 * i) + (synthNb * 425), 143, 16))
		.background_(Color.black)
	  .knobColor_(Color.magenta)
		.thumbSize_(18)

			.action_({
			arg obj;
		~synths[synthNb].set(~argsJitter[i], ~ctrlJitter[i].map(obj.value))
	});
});
});

2.do({
	arg synthNb;
	StaticText(w, Rect(410, 155 + (synthNb * 425), 75, 20))
.font_(~font)
.string_("modDepths")   // texte
//.stringColor_(v)
});
//////////////////////////////////////////////////////////////////
~allSlidersNoizFreq = 2.collect({
	arg synthNb;
~slidersNoizFreq = 8.collect({              // fréquences du noise pour modulations
	arg i;
		Slider(w, Rect(515, 5 + (19 * i) + (synthNb * 425), 130, 16))
		.background_(Color.black)
	  .knobColor_(Color.magenta)
		.thumbSize_(18)

			.action_({
			arg obj;
		~synths[synthNb].set(~argsNoizSpeed[i], ~ctrlNoizSpeed[i].map(obj.value));
	  ~allNoizSpeedBoxz[synthNb][i].value_(~ctrlNoizSpeed[i].map(obj.value));
	});
});
});

2.do({
	arg synthNb;
	StaticText(w, Rect(557, 155 + (synthNb * 425), 75, 20))
.font_(~font)
.string_("noizFreqs")     // texte
//.stringColor_(v)
});
//////////////////////////////////////////////////////////////
~noizSpeedBoxzDecimals = [
	  2,        // trig
		2,        // lect
		1,        // hauteur
		2,        // durée
		2,        // hipass
		2,        // lowpass
		2,        // combFreq
		2         // combDecay
	];

~noizSpeedBoxzClipLo = [
		0.1,     // trig
		0.2,     // lecture
		0.1,     // hauteur
		0.1,     // durée
		0.1,     // hipass
		0.1,     // lowpass
		0.07,    // combFreq
		0.1      // combDecay
 ];

~noizSpeedBoxzClipHi = [
		23,      // trig
		11,      // lecture
		29,      // hauteur
		11,      // durée
		37,      // hipass
		37,      // lowpass
		11,      // combFreq
		3        // combDecay
 ];

~noizSpeedBoxzScrollSteps = [
		0.1,       // trig
		0.1,       // lecture
		0.1,       // hauteur
		0.1,       // durée
		0.1,       // hipass
		0.1,       // lowpass
		0.1,       // combFreq
		0.1        // combDecay
	];

~allNoizSpeedBoxz = 2.collect({
	arg synthNb;
~noizSpeedBoxz = 8.collect({              // affichage des freqs des noises
	arg i;
		NumberBox(w, Rect(650, 5 + (19 * i) + (synthNb * 425), 50, 18))
	.font_(~font)
	.background_(Color.black)
	.normalColor_(v)
	.decimals_(~noizSpeedBoxzDecimals[i])
	.clipLo_(~noizSpeedBoxzClipLo[i])
	.clipHi_(~noizSpeedBoxzClipHi[i])
	.scroll_step_(~noizSpeedBoxzScrollSteps[i])

			.action_({
				arg obj;
				 ~allSlidersNoizFreq[synthNb][i].valueAction_(~ctrlNoizSpeed[i].unmap(obj.value));
	});
 });
});

2.do({
	arg synthNb;
	StaticText(w, Rect(652, 155 + (synthNb * 425), 70, 20))
.font_(~font)
.string_("Hz")             // texte
//.stringColor_(v)
});
///////////////////////////////////////////////////////////////
~allBackToNormal = 2.collect({
	arg synthNb;
~backToNormal = 13.collect({              // retour aux valeurs nominales des paramètres
		arg i, index;
		Button(w, Rect(345, 5 + (19 * i) + (synthNb * 425), 21, 18))
			.states_([ [" ", Color.black, Color.grey(0.2)]
	])
	.action_({
		arg obj;
		 ~allSliders[synthNb][i].valueAction_(~ctrl[i].unmap(~normValues[i]));
	});
});
});
////////////////////////////////////////////////////////////////////
///////////////////////// random modulations ///////////////////////
////////////////////////////////////////////////////////////////////
~allRdm = 2.collect({
	arg synthNb;
~rdm1Text = StaticText(w, Rect(563, 243 + (synthNb * 425), 70, 40))
.font_(~font)
.string_("all");       // texte
//.stringColor_(v);
~rdm1 = Button(w, Rect(515, 255 + (synthNb * 425), 40, 20))
.states_([ ["rdm1", Color.black, v]
])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(1.0.rand);
			~allSlidersNoizFreq[synthNb][i].valueAction_(1.0.rand);
	});
});
///////////////////////////////////////////////////////////////////
~rdm2Text = StaticText(w, Rect(563, 265 + (synthNb * 425), 55, 40))
.font_(~font)
.string_("noPitch");   // texte
//.stringColor_(v);
~rdm2 = Button(w, Rect(515, 277 + (synthNb * 425), 40, 20))     // randomiser les modulations mais pas la hauteur
.states_([ ["rdm2", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(1.0.rand);
			~allSlidersNoizFreq[synthNb][i].valueAction_(1.0.rand);
	});
		~allSlidersJitter[synthNb][2].valueAction_(0);   // pitch mod
});
///////////////////////////////////////////////////////////////////
~rdm3Text = StaticText(w, Rect(563, 287 + (synthNb * 425), 97, 40))
.font_(~font)
.string_("noPitchNoFilts");    // texte
//.stringColor_(v);
~rdm3 = Button(w, Rect(515, 299 + (synthNb * 425), 40, 20))    /* randomiser les modulations mais pas la hauteur
	                                                                ni les filtres */
.states_([ ["rdm3", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(1.0.rand);
			~allSlidersNoizFreq[synthNb][i].valueAction_(1.0.rand);
	});
		~allSlidersJitter[synthNb][2].valueAction_(0);   // pitch mod
		~allSlidersJitter[synthNb][4].valueAction_(0);   // hipass mod
		~allSlidersJitter[synthNb][5].valueAction_(0);   // lowpass mod
});
});
//////////////////////////////////////////////////////////////////
~allZeroMod = 2.do({
	arg synthNb;
~zeroMod = Button(w, Rect(605, 255 + (synthNb * 425), 40, 20))           // pas de modulations
.states_([ ["0mod", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(0);
	});
 });
});
///////////////////////////////////////////////////////////////////
//////////////////////////////////// big random ///////////////////
///////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// sliders de base seulement
~allRdmSlidersA = 2.do({
		arg synthNb;
		~rdmBaseSliders =	Button(w, Rect(65, 277 + (synthNb * 425), 52, 20))
.states_([ ["rdm++", Color.black, v]])
.font_(~font)
.action_({
  ~allSliders[synthNb][0].valueAction_(0.55.rand + 0.45);                                 // trig
	~allSliders[synthNb][1].valueAction_(0.45.rand);                                        // lect
	~allSliders[synthNb][2].valueAction_(1.0.rand);                                         // pitch
  ~allSliders[synthNb][3].valueAction_(0.7 - ~allSlidersJitter[synthNb][3].value - 0.2);  // durée, inverse mod
  ~allSliders[synthNb][4].valueAction_(0.7.linrand);                                      // hipass
  ~allSliders[synthNb][5].valueAction_(1 - (0.35.linrand));                               // lowpass
	~allSliders[synthNb][6].valueAction_(1.0.rand);                                         // comb freq
	~allSliders[synthNb][7].valueAction_(0.7 - ~allSlidersJitter[synthNb][7].value);        // comb decay, inverse mod
	~allSliders[synthNb][8].valueAction_(0.64.rand + 0.25);                                 // wipe
	~allSliders[synthNb][9].valueAction_(1.0.linrand);                                      // scramble
 });
});
/////////////////////////////////////////////////////////////////////////////////
~allRdmSlidersB = 2.do({
		arg synthNb;
		~rdmBaseSliders =	Button(w, Rect(120, 277 + (synthNb * 425), 52, 20))
.states_([ ["rdm", Color.black, v]])
.font_(~font)
.action_({
~allSliders[synthNb][0].valueAction_(~allSliders[synthNb][0].value + 0.05.rand2);      // trig
~allSliders[synthNb][1].valueAction_(~allSliders[synthNb][1].value + 0.05.rand2);      // lect
~allSliders[synthNb][3].valueAction_(~allSliders[synthNb][3].value + 0.05.rand2);      // durée
~allSliders[synthNb][6].valueAction_(~allSliders[synthNb][6].value + 0.05.rand2);      // comb freq
 });
});
/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// tout
~allRdmB = Button(w, Rect(515, 326, 52, 32))
.states_([ ["toutRdm", Color.black, v]])
.font_(~font)
.action_({
		2.do({
			arg synthNb;
	8.do({
			arg sliders;
				~allSlidersJitter[synthNb][sliders].valueAction_(1.0.rand);
			~allSlidersNoizFreq[synthNb][sliders].valueAction_(1.0.rand);
		});

	~allSliders[synthNb][0].valueAction_(0.55.rand + 0.45);                                 // trig
	~allSliders[synthNb][1].valueAction_(0.45.rand);                                        // lect
	~allSliders[synthNb][2].valueAction_(1.0.rand);                                         // pitch
  ~allSliders[synthNb][3].valueAction_(0.7 - ~allSlidersJitter[synthNb][3].value - 0.2);  // durée, inverse mod
  ~allSliders[synthNb][4].valueAction_(0.7.linrand);                                      // hipass
  ~allSliders[synthNb][5].valueAction_(1 - (0.35.linrand));                               // lowpass
	~allSliders[synthNb][6].valueAction_(1.0.rand);                                         // comb freq
	~allSliders[synthNb][7].valueAction_(0.7 - ~allSlidersJitter[synthNb][7].value);        // comb decay, inverse mod
	~allSliders[synthNb][8].valueAction_(0.64.rand + 0.25);                                 // wipe
	~allSliders[synthNb][9].valueAction_(1.0.linrand);                                      // scramble

      ~allTrigChoose[synthNb].value_([0, 1].choose);
      ~allLectChoose[synthNb].value_([0, 1, 2, 3].choose);
 });
});
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// pointeur au début du buffer
~allRestart = 2.do({
		arg synthNb;
		~restart =	Button(w, Rect(425, 277 + (synthNb * 425), 52, 20))
.states_([ ["|<-", Color.black, v]])
.font_(~font)
.action_({
			~synths[synthNb].set(\t_start, 1)
 });
});
////////////////////////////////////////////////////////////////////////////////
//////////////////////// plus ou moins de toutes les modulations ///////////////
////////////////////////////////////////////////////////////////////////////////
~allModIncrement = 2.do({
	arg synthNb;
~modInc = Button(w, Rect(605, 189 + (synthNb * 425), 40, 20))           // incrémenter
.states_([ ["mod+", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(~allSlidersJitter[synthNb][i].value + 0.01);
	});
 });
});

~allModDecrement = 2.do({
	arg synthNb;
~modDec = Button(w, Rect(605, 211 + (synthNb * 425), 40, 20))           // décrémenter
.states_([ ["mod-", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersJitter[synthNb][i].valueAction_(~allSlidersJitter[synthNb][i].value - 0.01);
	});
 });
});
////////////////////////////////////////////////////////////////////////////////
//////////////////// plus ou moins de vitesse de tous les noises lfo ///////////
////////////////////////////////////////////////////////////////////////////////
~allSpeedIncrement = 2.do({
	arg synthNb;
~modInc = Button(w, Rect(647, 189 + (synthNb * 425), 40, 20))           // incrémenter
.states_([ ["lfos+", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersNoizFreq[synthNb][i].valueAction_(~allSlidersNoizFreq[synthNb][i].value + 0.01);
	});
 });
});

~allSpeedDecrement = 2.do({
	arg synthNb;
~modDec = Button(w, Rect(647, 211 + (synthNb * 425), 40, 20))           // décrémenter
.states_([ ["lfos-", Color.black, v]])
.font_(~font)
.action_({
	8.do({
		arg i;
			~allSlidersNoizFreq[synthNb][i].valueAction_(~allSlidersNoizFreq[synthNb][i].value - 0.01);
	});
 });
});
/////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// save et recall paramètres /////////////////
/////////////////////////////////////////////////////////////////////////////////
~slidersValues = {7.collect({Array.newClear})}!2; // liste pour sauver des valeurs des sliders
~trigChooseValues = {Array.fill(7)}!2;
~lectChooseValues = {Array.fill(7)}!2;
~slidersJitterValues = {7.collect({Array.newClear})}!2;
~slidersNoizFreqValues = {7.collect({Array.newClear})}!2;
~bufferNbs = {Array.fill(7, 0)}!2;
/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// save
~save = 2.collect({
		arg synthNb;

~saveBts = 7.collect({                   // les 7 mémoires
	arg memo;
		Button(w, Rect(65 + (55 * memo), 342 + (425 * synthNb) , 52, 20))    // création
	.states_([["mémo" ++ (memo + 1), Color.black, v]])
  .font_(~font)
	});
});

2.do({
		arg synthNb;
7.do({
		arg memo;
			~save[synthNb][memo].action_({            // actions
			if(~slidersValues[synthNb][memo].isEmpty,
		{
	13.do({               // les 13 sliders de base
		arg sliderNb;
			~slidersValues[synthNb][memo] = ~slidersValues[synthNb][memo].add(~allSliders[synthNb][sliderNb].value)});
					//~slidersValues.postln;
		},
		{
			13.do({
				arg sliderNb;
	~slidersValues[synthNb][memo] = ~slidersValues[synthNb][memo].put(sliderNb, ~allSliders[synthNb][sliderNb].value);
				});
					//~slidersValues.postln;
	};
	 );

			if(~slidersJitterValues[synthNb][memo].isEmpty,
					{
						8.do({                // les sliders de modulation noise
							arg sliderNb;
	~slidersJitterValues[synthNb][memo] = ~slidersJitterValues[synthNb][memo]
							                          .add(~allSlidersJitter[synthNb][sliderNb].value)});
					},
		{
			8.do({
				arg sliderNb;
	~slidersJitterValues[synthNb][memo] = ~slidersJitterValues[synthNb][memo]
							                          .put(sliderNb, ~allSlidersJitter[synthNb][sliderNb].value);
				});

	};
	 );

   if(~slidersNoizFreqValues[synthNb][memo].isEmpty,
					{
						8.do({                // les sliders de freq noise
							arg sliderNb;
	~slidersNoizFreqValues[synthNb][memo] = ~slidersNoizFreqValues[synthNb][memo]
							                           .add(~allSlidersNoizFreq[synthNb][sliderNb].value)});
					},
		{
			8.do({
				arg sliderNb;
	~slidersNoizFreqValues[synthNb][memo] = ~slidersNoizFreqValues[synthNb][memo]
							                            .put(sliderNb, ~allSlidersNoizFreq[synthNb][sliderNb].value);
				});

	};
		);

      ~trigChooseValues[synthNb] = ~trigChooseValues[synthNb].put(memo, ~allTrigChoose[synthNb].value);
			//~trigChooseValues.postln;
			~lectChooseValues[synthNb] = ~lectChooseValues[synthNb].put(memo, ~allLectChoose[synthNb].value);
			//~lectChooseValues.postln;
///////////////////////////////////////////////////////////////////////////////////////////////////////////
~bufferNbs[synthNb] = ~bufferNbs[synthNb].put(memo, ~memsBuf.flatten[synthNb]);  // numéro de buffer
                                                          // ~memsBuf: cf. choix buffers plus bas
///////////////////////////////////////////////////////////////////////////////////////////////////////////
 7.do({                     // changer l'apparence si clic
			arg a;
		   if (memo == a, {
					~save[synthNb][a].states_([["saved" ++ (memo+1), Color.black, Color.new255(255, 159, 90)]]);
						~recall[synthNb][a].states_([["play" ++ (memo+1), Color.black, Color.cyan]]);
		 },
				{
					~save[synthNb][a].states_([["mémo" ++ (a+1), Color.black, v]]);
						~recall[synthNb][a].states_([["recall" ++ (a+1), Color.black, Color.new255(200, 200, 90)]]);
		});
   });
  });
 });
});
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////// recall
~recall =	2.collect({
		arg synthNb;

7.collect({
	arg recall;
	~recallB = Button(w, Rect(65 + (55 * recall), 364 + (425 * synthNb), 52, 20))
.states_([ ["recall" ++ (recall + 1), Color.black, Color.new255(200, 200, 90)] ])
.font_(~font)
	 });
	});

 2.do({
		arg synthNb;
   7.do({
			arg recall;
 ~recall[synthNb][recall].action_({

   13.do({    // les 13 sliders
			arg sliderNb;
      ~allSliders[synthNb][sliderNb]
		   .valueAction_(~slidersValues[synthNb][recall][sliderNb]);  // recall sliders de base
		});

	8.do({    // les 6 sliders de modulation noise
			arg sliderNb;
        ~allSlidersJitter[synthNb][sliderNb]
				.valueAction_(~slidersJitterValues[synthNb][recall][sliderNb]);  // recall sliders de modulation
		});

	8.do({    // les 6 sliders de freq noise
			arg sliderNb;
        ~allSlidersNoizFreq[synthNb][sliderNb]
				.valueAction_(~slidersNoizFreqValues[synthNb][recall][sliderNb]);  // recall sliders freq noise
		});

				~allTrigChoose[synthNb].valueAction_(~trigChooseValues[synthNb][recall]);   // recall type de trigger
		  	~allLectChoose[synthNb].valueAction_(~lectChooseValues[synthNb][recall]);   // recall type de lecture
//////////////////////////////////////////////////////////////////////////////////
~synths[synthNb].set(\buf, ~bufferNbs[synthNb][recall]);  // numéro de buffer

				7.do({                                          // affichage
					arg all;
					~allBufBts[synthNb][all].states_([["snd" ++ (all+1), Color.black, Color.grey(0.7)]]);
				});

~allBufBts[synthNb][~bufferNbs[synthNb][recall]]        // affichage
				  .states_([["snd" ++ (~bufferNbs[synthNb][recall]+1), Color.black, Color.cyan]]);
//////////////////////////////////////////////////////////////////////////////////
			7.do({                     // changer l'apparence si clic
			arg a;
		   if (recall == a, {
					~recall[synthNb][a].states_([["play" ++ (recall+1), Color.black, Color.cyan]])
		 },
				{
					~recall[synthNb][a].states_([["recall" ++ (a+1), Color.black, Color.new255(200, 200, 90)]])
		});
   });
  });
 });
});
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// copies paramètres a->b, b->a //////////////////
////////////////////////////////////////////////////////////////////////////////
~copyTexts = ["a -> b", "b -> a"];
	~allCopyAtoB = 2.collect({
		arg synthNb;
		~copyAtoB = Button(w, Rect(515, 189 + (425 * synthNb), 52, 32))
		.states_([ [~copyTexts[synthNb], Color.black, v]])
.font_(~font)
.action_({
    13.do({    // les 13 sliders
			arg sliderNb;
			~allSliders[1 - synthNb][sliderNb].valueAction_(~allSliders[synthNb][sliderNb].value);
		});

   8.do({    // les modulations
			arg sliderNb;
			~allSlidersJitter[1 - synthNb][sliderNb].valueAction_(~allSlidersJitter[synthNb][sliderNb].value);
			~allSlidersNoizFreq[1 -synthNb][sliderNb].valueAction_(~allSlidersNoizFreq[synthNb][sliderNb].value);
		});

		~allTrigChoose[1 - synthNb].valueAction_(~allTrigChoose[synthNb].value);
		~allLectChoose[1 - synthNb].valueAction_(~allLectChoose[synthNb].value);
 });
});
///////////////////////////////////////////////////////////////////
//////////////////////////////////// record ///////////////////////
///////////////////////////////////////////////////////////////////
~recordB = Button(w, Rect(605, 326, 52, 32))
.states_([ ["rec", Color.black, Color.new255(255, 90, 128)],
	["stop", Color.new255(255, 90, 128), Color.grey(0.3)]
])
.font_(~font)
.action_({
	arg b;
	if(
		b.value == 1,
	{s.record},
	{s.stopRecording}
	);
});
////////////////////////////////////////////////////////////////////
///////////////////////////////////////// choix buffers ////////////
////////////////////////////////////////////////////////////////////
~memsBuf = [0]!2;                // mémoire pour quand on redémarre avec play, première fois à 0, buffer 1
~allBufBts = 2.collect({         // création
	arg synthNb;
	~bufBts = 7.collect({
	arg i;
		Button(w, Rect(65 + (55 * i), 320 + (425 * synthNb), 52, 20))
			.states_([["snd" ++ (i+1), Color.black, Color.grey(0.7)]])
	.font_(~font);
	});
});

2.do({
	arg synthNb;
	~allBufBts[synthNb][0].states_([                     // affichage couleur de départ
	["snd1", Color.black, Color.cyan]
]);

7.do({
	arg i;
~allBufBts[synthNb][i].action_({                      // action choix buffers
	~synths[synthNb].set(\buf, i);
		~memsBuf[synthNb].put(0, i);                      // rejouer le dernier buffer au redémarrage des synths
				7.do({
			arg a;
		if (i == a, {
					~allBufBts[synthNb][a].states_([["snd" ++ (a+1), Color.black, Color.cyan]])},
					{~allBufBts[synthNb][a].states_([["snd" ++ (a+1), Color.black, Color.grey(0.7)]])
			});
		});
   });
 });
});
///////////////////////////////////////////////////////////////////////////////////////
////////////////////////// arrêter les synthés à la fermeture de la fenêtre ///////////
///////////////////////////////////////////////////////////////////////////////////////
w.onClose_{
	2.do({
		arg i;
		~synths[i].free;
 })};
});
)

s.quit

