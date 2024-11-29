(
Server.default.options.memSize = 2.pow(20);  // + de mémoire pour les comb et allpass
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// 47 harmoniques //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
s.waitForBoot({

var nbSliders = 18,
    startValues = [             // valeurs iter au début
	110.explin(20, 1000, 0, 1),   //freq             0
	(1/2).explin(0.05, 3, 0, 1),  // harmFactor      1
	0.5,   // dec                                    2
	0.87,  // freqMod                                3
	0.87,  // freqModFreq                            4
	0.7,   // trem                                   5
	0.2,   // tremFreq                               6
	0.5,   // inAmp                                  7
	0.2,   // hpCutoff                               8
	0.27,  // hpReso                                 9
	0.3,   // lpCutoff                               10
  0.6,   // lpReso                                 11
  0.2,   // lpModDepth                             12
  0.43,  // outAmp                                 13
	0.647, // combFreq                               14
	0.6,   // combDecay                              15
  0.63,  // combMod                                16
	0.18   // combModFreq                            17
	],

freqMin = 20,
freqMax = 1000,

harmFactMin = 0.05,
harmFactMax = 3,

decMin = -53,
decMax = 53,

freqModMin = 1,
freqModMax = 1.4,

freqModFreqMin = 0.1,
freqModFreqMax = 1000,

tremMin = 0.001,     // inverser le slider
tremMax = 1,

tremFreqMin = 0.05,
tremFreqMax = 19,

inAmpMin = 0.1,
inAmpMax = 5,

hpCutoffMin = 20,
hpCutoffMax = 10000,

hpResoMin = 1,        // inversé ici
hpResoMax = 0.3,

lpCutoffMin = 40,
lpCutoffMax = 12000,

lpResoMin = 1,        // inversé ici
lpResoMax = 0.1,

lpModDepthMin = 0,
lpModDepthMax = 20,

outAmpMin = 0.01,
outAmpMax = 15,

combFreqMin = 0.02,
combFreqMax = 0.3,

combDecayMin = -0.01,
combDecayMax = -10,

combModMin = 0.01,
combModMax = 4,

combModFreqMin = 0.05,
combModFreqMax = 23;
//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// bus et groupes
s.newBufferAllocators;
~masterBpfsBus = Bus.audio(s, 2);
~reverbBus = Bus.audio(s, 2);
~sourceGrp = Group.new(s, \addToHead);
~reverbGrp = Group.new(~sourceGrp, \addAfter);
//////////////////////////////////////////////////////////////////////////////////
///////////// préparation shaper
{
~transFunc01 = Env([-1, -0.5, 0, 0.5, 1], [0.1], [-2, 4, -4, 1.5]).asSignal(2049);
//~transFunc01.plot;
~transFunc01 = ~transFunc01.asWavetableNoWrap;
~transFuncBuf01 = Buffer.loadCollection(s, ~transFunc01);
}.defer;
/////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////// synth iter ////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
~inharmo = [72, 135, 173, 239, 267, 306, 355, 473, 512, 572].collect({arg i; 100/i}); /* pas les
	                                                                                       harmoniques pour
                                                                                         les combs */
SynthDef(\iterEli, {
	arg freq = 70,
	harmFactor = 1,
	dec = 0,
	freqMod = 0.1,
	freqModFreq = 0.1,
	trem = 0.1,
	tremFreq = 1,
	inAmp = 0.5,
	hpCutoff = 200,
	hpReso = 0.2,
	lpCutoff = 8000,
	lpReso = 0.2,
	outAmp = 0.4,
	gate = 1,
	combFreq = 0.1,
	combDecay = -0.5,
	combMod = 0.1,
	combModFreq = 0.1,
	out = 53,
	lpModDepth = 0.3;
	var env, gen, temp, sumSine, harmos, combModulation, lpMod;
	harmos = 47;  // 47 harmoniques
	env = Env.asr(attackTime: 2, releaseTime: 5);
	gen = EnvGen.kr(env, gate: gate, doneAction: 2);
  lpMod = LFNoise2.kr(0.1).unipolar(lpCutoff.sqrt * lpModDepth).clip(40, 12000);
	sumSine = 0;
	harmos.do({
		arg i;
		temp = SinOsc.ar(
        freq *
			(((i + 1) * harmFactor) + ({rrand(-0.04, 0.04)}!2) ) * LFNoise1.kr({Rand(0.1, 7) * freqModFreq})
			.range(freqMod.reciprocal, freqMod) + dec);

      temp = temp * ((i + 1).reciprocal); // moins fort les partials hauts
			temp = temp * LFDNoise1.kr({Rand(1.0, 4.0)} * tremFreq).exprange(trem); // modulation d'amplitude
		sumSine = sumSine + temp;
		});
	sumSine = sumSine * (inAmp.lag(0.1) * (6 / harmos));  // amp avant le waveshaper
  sumSine = BHiPass4.ar(sumSine, hpCutoff.lag(0.1), rq: hpReso);  // 24dB hipass
	sumSine = BLowPass.ar(sumSine, lpCutoff.lag(0.1) + lpMod, rq: lpReso);  // 12dB lowpass
  sumSine = Shaper.ar(~transFuncBuf01, sumSine);  // waveshaping avec l'enveloppe dans le buffer
	sumSine = sumSine * outAmp.lag(0.1) * gen;  // master amp, avant le comb filter

		sumSine = sumSine + 10.collect({
			arg i;
       CombC.ar(sumSine, 1, LFNoise1.kr(combModFreq, mul: combMod).exprange(0.1, 0.12)
				* (combFreq * ~inharmo[i]), combDecay, 0.4)}).sum;
	sumSine = Limiter.ar(sumSine, level: 0.4, dur: 0.1);
 Out.ar(out, sumSine);
}).add;
///////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////// synth noise -> bpf ////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////
SynthDef.new(\simpleBpf, {
	arg freq = 55, reso = 0.025, amp = 0.3, gate = 0, out = 3, mod = 0;
	var sig, env, modulation;
	modulation = LFDNoise1.kr(0.2).range((freq / 4) * mod).clip(20, 3000);
	env = EnvGen.kr(Env.asr(0.4, 1, 0.7), gate: gate, doneAction: 0);
	sig = BrownNoise.ar(1!2);
	sig = BPF.ar(sig, (freq.varlag(0.4) + modulation), reso.varlag(0.2));
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
///////////////////////////////////////////////////////// bus master bpfs
SynthDef(\bpfsOut, {
	arg in = 3, out = 0, amp = 1;
	var sig = In.ar(in, 2);
	sig = sig * amp;
	Out.ar(out, sig)
}).add;
//////////////////////////////////////////////////////// reverb
SynthDef(\reverb, {
	arg in = 3, out = 0, decay = 4;
	var sig, wet;
		sig = In.ar(in, 2);
		sig = HPF.ar(sig, 300);
		wet = DelayN.ar(sig, 0.4, 0.4);  // predelay

		wet = 10.collect({
			CombN.ar(
				wet, 0.1, LFNoise1.kr(0.05!2).exprange(0.01, 0.02), decay, 0.6)
		}).sum;

    10.do({
			wet = AllpassL.ar(wet, 0.3, LFNoise1.kr(0.05!2).exprange(0.1, 0.2), decay, 0.8)
		});
		wet = LeakDC.ar(wet, 0.995);
		wet = LPF.ar(wet, 3000);
		sig = sig.blend(wet, \mix.kr(0.5));   // dry/wet mix
    Out.ar(out, sig);
}).add;

s.sync;
//////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////
~font = Font("Helvetica", 14);
// liste des arguments du synth iter contrôlés par les sliders
~slidersFuncs = [
	\freq,                    // 0
	\harmFactor,              // 1
	\dec,                     // 2
	\freqMod,                 // 3
	\freqModFreq,             // 4
	\trem,                    // 5
	\tremFreq,                // 6
	\inAmp,                   // 7
	\hpCutoff,                // 8
	\hpReso,                  // 9
  \lpCutoff,                // 10
	\lpReso,                  // 11
  \lpModDepth,              // 12
  \outAmp,                  // 13
	\combFreq,                // 14
	\combDecay,               // 15
	\combMod,                 // 16
	\combModFreq              // 17
	];

~mapped = startValues.collect{                                // mapping des sliders
	arg i, index;
		var map =   [
		             i.value.linexp(0, 1, freqMin, freqMax),                // freq                 0
		             i.value.linexp(0, 1, harmFactMin, harmFactMax),        // harmFactor           1
		             i.value.linlin(0, 1, decMin, decMax),                  // dec                  2
			           i.value.linexp(0, 1, freqModMin, freqModMax),          // freqMod              3
			           i.value.linexp(0, 1, freqModFreqMin, freqModFreqMax),  // freqModFreq          4
			           i.value.linexp(0, 1, tremMax, tremMin),                // trem, inverser       5
			           i.value.linexp(0, 1, tremFreqMin, tremFreqMax),        // tremFreq             6
			           i.value.linexp(0, 1, inAmpMin, inAmpMax ),             // inAmp                7
			           i.value.linexp(0, 1, hpCutoffMin, hpCutoffMax),        // hpCutoff             8
			           i.value.linexp(0, 1, hpResoMin, hpResoMax),            // hpReso               9
			           i.value.linexp(0, 1, lpCutoffMin, lpCutoffMax),        // lpCutoff             10
                 i.value.linexp(0, 1, lpResoMin, lpResoMax),            // lpReso               11
                 i.value.linlin(0, 1, lpModDepthMin, lpModDepthMax),    // lpModDepth           12
                 i.value.linexp(0, 1, outAmpMin, outAmpMax),            // outAmp               13
			           i.value.linexp(0, 1, combFreqMin, combFreqMax),        // combFreq             14
			           i.value.linexp(0, 1, combDecayMin, combDecayMax),      // combDecay            15
			           i.value.linexp(0, 1, combModMin, combModMax),          // combModulation       16
			           i.value.linexp(0, 1, combModFreqMin, combModFreqMax),  // combModulationFreq   17
	             ];
	(map[index]).round(1/100);
};
//~mapped.postln;
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
Window.closeAll;
t = "iterEliAdditive&noiseBpf";
w = Window(bounds: Rect(
			Window.screenBounds.width * 0.12,
	    Window.screenBounds.height * 0.025,
		  750, nbSliders * 46))
.background_(Color.new(0.5, 0.51, 0.58))
.name_(t)
.front.alwaysOnTop_(true);
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////// arrêter les synthés simpleBfs à la fermeture de la fenêtre
w.onClose_{
	7.do({
		arg i;
		~simpleBpfs[i].free;
});
		~bpfsMix.free;
		~reverb.free;
		~sourceGrp.free;
		~reverbGrp.free;
};
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
~play = Button(w, Rect(285, 27, 55, 50))     /////////////////////// iter play/stop
.states_([
	["play \nsine", Color.red, Color.black],
	[ "stop \nsine", Color.green, Color.black]
])
.font_(~font)
	.action_({
		arg b;
	if(
	b.value == 1,
		{                                   // le synth démarre avec les valeurs de la GUI
	 ~iter = Synth(\iterEli, [
				                        \freq, ~sliders[0].value.linexp         (0, 1, freqMin, freqMax),
				                        \harmFactor, ~sliders[1].value.linexp   (0, 1, harmFactMin, harmFactMax),
				                        \dec, ~sliders[2].value.linlin          (0, 1, decMin, decMax),
				                        \freqMod, ~sliders[3].value.linexp      (0, 1, freqModMin, freqModMax),
				                        \freqModFreq, ~sliders[4].value.linexp  (0, 1, freqModFreqMin, freqModFreqMax),
				                        \trem, ~sliders[5].value.linexp         (0, 1, tremMax, tremMin),   // inverser
				                        \tremFreq, ~sliders[6].value.linexp     (0, 1, tremFreqMin, tremFreqMax),
				                        \inAmp, ~sliders[7].value.linexp        (0, 1, inAmpMin, inAmpMax),
				                        \hpCutoff, ~sliders[8].value.linexp     (0, 1, hpCutoffMin, hpCutoffMax),
				                        \hpReso, ~sliders[9].value.linexp       (0, 1, hpResoMin, hpResoMax),
				                        \lpCutoff, ~sliders[10].value.linexp    (0, 1, lpCutoffMin, lpCutoffMax),
                                \lpReso, ~sliders[12].value.linexp      (0, 1, lpResoMin, lpResoMax),
                                \lpModDepth, ~sliders[11].value.linlin  (0, 1, lpModDepthMin, lpModDepthMax),
                                \outAmp, ~sliders[13].value.linexp      (0, 1, outAmpMin, outAmpMax),
                                \combFreq, ~sliders[14].value.linexp    (0, 1, combFreqMin, combFreqMax),
					                      \combDecay, ~sliders[15].value.linexp   (0, 1, combDecayMin, combDecayMax),
					                      \combMod, ~sliders[16].value.linexp     (0, 1, combModMin, combModMax),
					                      \combModFreq, ~sliders[17].value.linexp (0, 1, combModFreqMin, combModFreqMax),
					                      \out, ~reverbBus
			],
				~sourceGrp,
				\addToHead
				).register
},
		{
		~iter.set(\gate, 0)
		}
	);
	});
///////////////////////////////////////////////////////////////////////////////////////////
~rdm = Button(w, Rect(350, 27, 55, 50)) // randomisation de certains sliders => paramètres
.states_([
	["rdm \nall", Color.green, Color.black]
])
.font_(~font)
.action_({
	arg obj;
		~sliders[0].valueAction_(~sliders[0].value + (rand2(0.02)).clip(0, 1));     // freq
	~sliders[1].valueAction_(~sliders[1].value + (rand2(0.045)) );    // harmFactor
	~sliders[2].valueAction_(~sliders[2].value + (rand2(0.045)) );    // dec
//	~sliders[3].valueAction_(~sliders[3].value + (rand2(0.001)) );    // freqMod
//	~sliders[4].valueAction_(~sliders[4].value + (rand2(0.045)) );    // freqModFreq
	~sliders[6].valueAction_(~sliders[6].value + (rand2(0.15)) );     // tremFreq
	~sliders[7].valueAction_(~sliders[7].value + (rand2(0.1)) );      // shaper
	~sliders[8].valueAction_(~sliders[8].value + (rand2(0.1)) );      // hp cutoff
	~sliders[9].valueAction_(~sliders[9].value + (rand2(0.1)) );      // hp reso
	~sliders[10].valueAction_(~sliders[10].value + (rand2(0.1)) );    // lp cutoff
	~sliders[11].valueAction_(~sliders[11].value + (rand2(0.1)) );    // lp reso
	~sliders[12].valueAction_(~sliders[12].value + (rand2(0.2)) );    // lp mod
	~sliders[14].valueAction_(~sliders[14].value + (rand2(0.15)) );   // combFreq
	~sliders[15].valueAction_(~sliders[15].value + (rand2(0.1)) );   // combDecay
	~sliders[16].valueAction_(~sliders[16].value + (rand2(0.025)) );   // combMod
	~sliders[17].valueAction_(~sliders[17].value + (rand2(0.15)) );   // combModFreq
	7.do({
		arg i;
		~slidersFreqBpfs[i].valueAction_(~slidersFreqBpfs[i].value + (rand2(0.03)))   // synths bpf
	});
});
/////////////////////////////// textes sliders iter
~textesSliders = nbSliders.collect{
	arg i;
	StaticText(w, Rect(20, 5 + (45 * i), 210, 20))
	.font_(~font)
	.stringColor_(Color.black)
}
.do{
	arg t, index;
	var textList = [
			"fréq",                          // 0
			"mult harmoniques",              // 1
			"décalage partiels",             // 2
			"modulation freq",               // 3
			"vitesse fréq mod",              // 4
			"partiels amp mod",              // 5
			"vitesse partiels amp mod",      // 6
			"amp -> shaper",                 // 7
			"hipass cutoff",                 // 8
			"hipass reso",                   // 9
			"lowpass cutoff",                // 10
			"lowpass reso",                  // 11
			"lowpass modulation",            // 12
			"master amp",                    // 13
			"comb time",                     // 14
			"comb feedback",                 // 15
			"comb modulation",               // 16
			"vitesse comb mod"               // 17
		];
	t.string_(textList[index]);
};
//////////////////////////////////////////////////////////////////////////////////
/////////////////// boxes correspondant aux sliders iter
~boxzClipLoValues = [
		                freqMin,                       // 0
		                harmFactMin,                   // 1
		                decMin,                        // 2
		                freqModMin,                    // 3
		                freqModFreqMin,                // 4
		                tremMin,                       // 5
		                tremFreqMin,                   // 6
		                inAmpMin,                      // 7
		                hpCutoffMin,                   // 8
		                hpResoMax,                     // 9
		                lpCutoffMin,                   // 10
		                lpResoMax,                     // 11
		                lpModDepthMin,                 // 12
		                outAmpMin,                     // 13
		                combFreqMin,                   // 14
		                combDecayMax,                  // 15
		                combModMin,                    // 16
		                combModFreqMin                 // 17
		                ];

~boxzClipHiValues = [
		                freqMax,                       // 0
		                harmFactMax,                   // 1
		                decMax,                        // 2
		                freqModMax,                    // 3
		                freqModFreqMax,                // 4
		                tremMax,                       // 5
		                tremFreqMax,                   // 6
		                inAmpMax,                      // 7
		                hpCutoffMax,                   // 8
		                hpResoMin,                     // 9
		                lpCutoffMax,                   // 10
		                lpResoMin,                     // 11
		                lpModDepthMax,                 // 12
		                outAmpMax,                     // 13
		                combFreqMax,                   // 14
		                combDecayMin,                  // 15
		                combModMax,                    // 16
		                combModFreqMax                 // 17
                    ];

~boxzScrollSteps = [
	1,      // freq            0
	0.01,   // harmFactor      1
	0.1,    // dec             2
	0.1,    // freqMod         3
	0.1,    // freqModFreq     4
	0.1,    // trem            5
	0.01,   // tremFreq        6
	0.1,    // inAmp           7
	10,     // hpCutoff        8
	0.01,   // hpReso          9
	10,     // lpCutoff        10
  0.01,   // lpReso          11
  0.1,    // lpModDepth      12
  0.01,   // outAmp          13
	0.01,   // combFreq        14
	0.01,   // combDecay       15
	0.1,    // combMod         16
	0.1     // combModFreq     17
	];
//////////////////////////////////////////////////////////////////////////
////////////////////////////////// création des boxes iter
~boxzIter = nbSliders.collect{
	arg i;
	NumberBox(w, Rect(225, 30 + (45 * i), 52, 20))
	.clipLo_(~boxzClipLoValues[i])
  .clipHi_(~boxzClipHiValues[i])
	.normalColor_(Color.green)
	.font_(~font)
	.background_(Color.grey(0.11))
};

	~boxzIter.do{
	arg i, index;
	var decimalsSlidersBoxz = [     // affichage des décimales iter
		0,  // freq                0
		2,  // harmFactor          1
		1,  // dec                 2
		2,  // freqMod             3
		1,  // freqModFreq         4
		3,  // trem                5
		2,  // tremFreq            6
		2,  // inAmp               7
		0,  // hpCutoff            8
	  2,  // hpReso              9
		0,  // lpCutoff            10
    2,  // lpReso              11
    1,  // lpModDepth          12
    2,  // outAmp              13
		3,  // combFreq            14
		2,  // combDecay           15
		2,  // combMod             16
		2   // combModFreq         17
		];
	i.scroll_step = ~boxzScrollSteps[index];
	i.decimals_(decimalsSlidersBoxz[index]);
};

// action des boxes sur les sliders iter
~boxzIter.do{
	arg i, index;
i.action_({
	arg obj;
	var mapList;
		mapList = [
			         obj.value.explin(freqMin, freqMax, 0, 1),                        // freq              0
			         obj.value.explin(harmFactMin, harmFactMax, 0, 1),                // harmFactor        1
			         obj.value.linlin(decMin, decMax, 0, 1),                          // dec               2
			         obj.value.linlin(freqModMin, freqModMax, 0, 1),                  // freqMod           3
			         obj.value.explin(freqModFreqMin, freqModFreqMax, 0, 1),          // freqModFreq       4
			         obj.value.explin(tremMin, tremMax, 0, 1),                        // trem              5
			         obj.value.explin(tremFreqMin, tremFreqMax, 0, 1),                // tremFreq          6
			         obj.value.explin(inAmpMin, inAmpMax, 0, 1),                      // inAmp             7
			         obj.value.explin(hpCutoffMin, hpCutoffMax, 0, 1),                // hpCutoff          8
			         obj.value.explin(hpResoMax, hpResoMin, 0, 1),                    // hpReso, inversé   9
			         obj.value.explin(lpCutoffMin, lpCutoffMax, 0, 1),                // lpCutoff          10
               obj.value.linlin(lpResoMax, lpResoMin, 0, 1),                    // lpReso, inversé   11
               obj.value.linlin(lpModDepthMin, lpModDepthMax, 0, 1),            // lpModDepth        12
               obj.value.explin(outAmpMin, outAmpMax, 0, 1),                    // outAmp            13
               obj.value.explin(combFreqMin, combFreqMax, 0, 1),                // combFreq          14
      	       obj.value.neg.explin(combDecayMin.neg, combDecayMax.neg, 0, 1),  // combDecay         15
               obj.value.explin(combModMin, combModMax, 0, 1),                  // combMod           16
			         obj.value.explin(combModFreqMin, combModFreqMax, 0, 1),          // combModFreq       17
		];
		~sliders[index].valueAction_(mapList[index])   // les boxes contrôlent les sliders
	});
};
//////////////////////////////////////////////////////////////////////
//////////////////////////////// sliders iter
// création
~sliders = nbSliders.collect{
	arg i, index;
	Slider.new(w, Rect(20, 30 + (45 * i), 200, 17))
	.background_(Color.gray(0.1))
	.knobColor_(Color.magenta)
	.thumbSize_(17)
	};
// actions
~sliders.do{
	arg i, index;
	i.action_({
		arg obj;
		var mapList;
		mapList = [
			         obj.value.linexp(0, 1, freqMin, freqMax),                           // 0
			         obj.value.linexp(0, 1, harmFactMin, harmFactMax),                   // 1
			         obj.value.linlin(0, 1, decMin, decMax),                             // 2
			         obj.value.linexp(0, 1, freqModMin, freqModMax),                     // 3
			         obj.value.linexp(0, 1, freqModFreqMin, freqModFreqMax),             // 4
			         obj.value.linexp(0, 1, tremMax, tremMin),                           // 5
			         obj.value.linexp(0, 1, tremFreqMin, tremFreqMax),                   // 6
			         obj.value.linexp(0, 1, inAmpMin, inAmpMax),                         // 7
			         obj.value.linexp(0, 1, hpCutoffMin, hpCutoffMax),                   // 8
			         obj.value.linexp(0, 1, hpResoMin, hpResoMax),                       // 9
			         obj.value.linexp(0, 1, lpCutoffMin, lpCutoffMax),                   // 10
               obj.value.linexp(0, 1, lpResoMin, lpResoMax),                       // 11
               obj.value.linlin(0, 1, lpModDepthMin, lpModDepthMax),               // 12
               obj.value.linexp(0, 1, outAmpMin, outAmpMax),                       // 13
               obj.value.linexp(0, 1, combFreqMin, combFreqMax),                   // 14
			         obj.value.linexp(0, 1, combDecayMin, combDecayMax),                 // 15
			         obj.value.linexp(0, 1, combModMin, combModMax),                     // 16
			         obj.value.linexp(0, 1, combModFreqMin, combModFreqMax),             // 17
		];
  ~iter.set(~slidersFuncs[index], mapList[index]);

			~boxzIter[index].value_(mapList[index]);    // link number boxes et sliders, les boxes contrôlent les sliders
	});
};
/////////////// inversions des valeurs des sliders et boxes pour certains paramètres
~sliders[5].action_({   // trem
	arg obj;
	~iter.set(~slidersFuncs[5], obj.value.linexp(0, 1, tremMax, tremMin));
	~boxzIter[5].value_(obj.value.linexp(0, 1, tremMin, tremMax))});

~sliders[9].action_({  // hp réso
	arg obj;
	~iter.set(~slidersFuncs[9], obj.value.linexp(0, 1, hpResoMin, hpResoMax));
	~boxzIter[9].value_(obj.value.linexp(0, 1, hpResoMax, hpResoMin))});

~sliders[11].action_({  // lp réso
	arg obj;
	~iter.set(~slidersFuncs[11], obj.value.linexp(0, 1, lpResoMin, lpResoMax));
	~boxzIter[11].value_(obj.value.linexp(0, 1, lpResoMax, lpResoMin))});
////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// presets switches pour harmonic factor iter
StaticText(w, Rect(290, 93, 90, 15))
.font_(~font)
.string_("harmFct");
//.stringColor_(Color.green);
~harmoFactorsPresets = [1/8, 1/4, 1/3, 1/2, 1, 3/2].round(1 / 1000);
~harmoFactorsPresetsNames = ["1/8", "1/4", "1/3", "1/2", "1", "3/2"]; /* seulement affichage pour ne pas que
                                                                         ça calcule et affiche avec la virgule */
~harmoFactorSwitches06 = 6.collect{
		arg i;
	Button(w, Rect(285, 188 + (30 * i), 55, 22))
	.states_([
		[~harmoFactorsPresetsNames[i], Color.black, Color(0, 1, 0, 0.4)]
	])
	.font_(~font)
	.action_({
		~sliders[1].valueAction_(~harmoFactorsPresets[i].explin(0.05, 3, 0, 1)); // explin et pas linexp !
	});
};

~harmoFactInc06 = Button(w, Rect(285, 115, 55, 22)) // incrémenter harmonic factor
.states_([
		["+", Color.black, Color(0, 1, 1, 0.7)]
	])
.font_(~font)
.action_({
	~sliders[1].valueAction_(~sliders[1].value + 0.005);
});
~harmoFactDec06 = Button(w, Rect(285, 145, 55, 22)) // décrémenter harmonic factor
.states_([
		["-", Color.black, Color(0, 1, 1, 0.7)]
	])
.font_(~font)
.action_({
	~sliders[1].valueAction_(~sliders[1].value - 0.005);
});
//////////////////////////////////////////// contrôle de la frequence de base
StaticText(w, Rect(365, 93, 90, 15))
.font_(~font)
.string_("freq *");
//.stringColor_(Color.green);
~freqPresets = [3/4, 2/3, 1/2, 5/4, 4/3, 3/2, 2].round(1/1000);
~freqPresetsNames = ["3/4", "2/3", "1/2", "5/4", "4/3", "3/2", "2"]; /* seulement affichage pour ne pas que
                                                                        ça calcule et affiche avec la virgule */
~freqSwitches06 = 7.collect{
		arg i;
	Button(w, Rect(355, 115 + (30 * i), 55, 22))
	.states_([
		[~freqPresetsNames[i], Color.black, Color(0, 1, 0, 0.4)]
	])
	.font_(~font)
	.action_({
		~sliders[0].valueAction_(
			(~sliders[0].value.linexp(0, 1, 20, 1000) * ~freqPresets[i])
			.explin(20, 1000, 0, 1) );
  });
};
//initialisation affichage GUI
~sliders.do{
	arg i, index;
	i.value_(startValues[index])
};
~boxzIter.do{
	arg i, index;
	i.value_(~mapped[index].value)
};
///////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// création synths ////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
~simpleBpfs = 7.collect({
	arg i, index;
	Synth(\simpleBpf, [\gate, 0, \out, ~masterBpfsBus], ~sourceGrp);
});

~bpfsMix = Synth(\bpfsOut, [                  // bus pour mast. volume des bpfs
		\in, ~masterBpfsBus,
		\out, ~reverbBus
	], target: ~simpleBpfs[0], addAction: \addAfter);

~reverb = Synth(\reverb, [\in, ~reverbBus], ~reverbGrp);
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// GUI simpleBpf ////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////// fréquences
~slidersFreqBpfs = 7.collect({
	arg i;
	Slider.new(w, Rect(430, 40 + (70 * i), 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_((55 * (i+1)).explin(20, 3000, 0, 1))
.background_(Color.gray(0.1))
.knobColor_(Color.magenta)
.action_({
	arg obj;
	var cf;
		cf = obj.value.linexp(0, 1, 20, 3000);
		~simpleBpfs[i].set(\freq, cf);
		~boxzFreqBpfs[i].value_(obj.value.linexp(0, 1, 20, 3000));  // la box est mappée pareil que le slider
});
 });

~boxzFreqBpfs = 7.collect({
	arg i, index;
	NumberBox(w, Rect(640, 40 + (70 * i), 52, 20))
.font_(~font)
.normalColor_(Color.green)
.background_(Color.grey(0.11))
.value_(55 * (i+1))
.clipLo_(20)
.clipHi_(3000)
.decimals_(0)
.scroll_step_(1)  // scroll quantizé à 10 pas
.action_({
	arg obj;
 ~slidersFreqBpfs[i].valueAction_(obj.value.explin(20, 3000, 0, 1))  // contrôle du slider (linexp --> explin)
 });
});
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////// amplitudes
~slidersAmpBpfs = 7.collect({
	arg i;
	Slider.new(w, Rect(430, 70 + (70 * i), 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_((1 / (i+1)).explin(0.01, 1, 0, 1))
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var amp;
		amp = obj.value.linexp(0, 1, 0.01, 1);
		~simpleBpfs[i].set(\amp, amp);
		~boxzAmpBpfs[i].value_(obj.value.linexp(0, 1, 0.01, 1));  // la box est mappée pareil que le slider
 });
});

~boxzAmpBpfs = 7.collect({
	arg i, index;
	NumberBox(w, Rect(640, 70 + (70 * i), 52, 20))
.font_(~font)
.normalColor_(Color.green)
.background_(Color.grey(0.11))
.value_((1 / (i+1)).explin(0.01, 1, 0, 1))
.clipLo_(0.01)
.clipHi_(1)
.decimals_(3)
.scroll_step_(1/100)
.action_({
	arg obj;
	~slidersAmpBpfs[i].valueAction_(obj.value.explin(0.01, 1, 0, 1))  // contrôle du slider (linexp --> explin)
 });
});
/////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////// textes
~textsBpfs = 7.collect({
	arg i;
	StaticText(w, Rect(430, 20 + (70 * i), 170, 20))
	.font_(~font);
})
.do({
	arg t, index;
	t.string_("bp freq" ++ (index + 1) + "& amp" ++ (index + 1));
});

~textsFreqsBpfs = 7.collect({
	arg i;
	StaticText(w, Rect(640, 20 + (70 * i), 90, 20))
	.font_(~font);
})
.do({
	arg t, index;
	t.string_("Hz");
});
//////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// play/stop
StaticText(w, Rect(430, 520, 120, 15))
.font_(~font)
.string_("play/stop bpfs");

	~play = 7.collect({
	arg i, index;
	Button(w, Rect(430 + (38 * i), 545, 35, 22))
.states_([
		[" " ++ (i+1), Color.black, Color(0.75, 0.75, 0.75)],
	  [" " ++ (i+1), Color.black, Color.new255(240, 110, 120)]
])
.action_({
	arg b;
		~simpleBpfs[i].set(\gate, b.value,     /////////// pas besoin de mettre 'if'
			\freq, ~slidersFreqBpfs[i].value.linexp(0, 1, 20, 3000)
		);
  });
 });
//////////////////////////////////////////////////////////////////////////////////////////////
StaticText(w, Rect(365, 600, 30, 15))
.font_(~font)
.string_("bpfs");
//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////// incrémenter les freqs bpfs
~bpfsFreqsInc = Button(w, Rect(350, 625, 55, 22))
.states_([
		["+", Color.black, Color(0, 1, 1)]
	])
.font_(~font)
.action_({
		7.do({
		arg i;
		~slidersFreqBpfs[i].valueAction_(~slidersFreqBpfs[i].value + (0.005))
	});
});
//////////////////////////////////////////////// décrémenter les freqs bpfs
~bpfsFreqsDec = Button(w, Rect(350, 655, 55, 22))
.states_([
		["-", Color.black, Color(0, 1, 1)]
	])
.font_(~font)
.action_({
		7.do({
		arg i;
		~slidersFreqBpfs[i].valueAction_(~slidersFreqBpfs[i].value - (0.005))
	});
});
//////////////////////////////////////////////////////////////////////////////////////////////
/////// mult. harmoniques
~harmoFixBpfs = Button(w, Rect(350, 725, 55, 22)) // tous les synths aux harmoniques du numéro 1
.states_([
		["h", Color.black, Color(0, 1, 0, 0.4)]
	])
.font_(~font)
.action_({
		7.do({
		arg i;
			~boxzFreqBpfs[i].valueAction_(~boxzFreqBpfs[0].value * (i+1));
	});
});
/////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////// big random sur les freqs bpf
~rdmRangesMin = [
27,     // 1
120,    // 2
200,    // 3
300,    // 4
340,    // 5
400,    // 6
400,    // 7
];
~rdmRangesMax = [
110,    // 1
260,    // 2
400,    // 3
600,    // 4
470,    // 5
500,    // 6
700,    // 7
];
~harmoBpfsRdm = Button(w, Rect(350, 695, 55, 22))
.states_([
		["rdm", Color.black, Color(0, 1, 0, 0.4)]
	])
.font_(~font)
.action_({
			7.do({
		arg i;
		~slidersFreqBpfs[i].valueAction_(exprand(~rdmRangesMin[i], ~rdmRangesMax[i]).explin(20, 3000, 0, 1));
 });
});
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// slider de modulation pour tous les bpfs
StaticText(w, Rect(430, 580, 120, 15))
.font_(~font)
.string_("mod freq bpfs");

~sliderModFreqBpfs = Slider.new(w, Rect(430, 600, 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_(0)
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var mod = obj.value.linexp(0, 1, 0.01, 2);
		~simpleBpfs.do({
	arg i;
	i.set(\mod, mod)
 });
});
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// slider pour résonance pour tous les bpfs
StaticText(w, Rect(430, 620, 120, 15))
.font_(~font)
.string_("master réso bpfs");

~sliderResoBpfs = Slider.new(w, Rect(430, 640, 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_(0.902375)
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var reso = obj.value.linlin(0, 1, 0.21, 0.005);
		~simpleBpfs.do({
	arg i;
	i.set(\reso, reso)
 });
});
/////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// slider pour volume général des bpfs
StaticText(w, Rect(430, 660, 120, 15))
.font_(~font)
.string_("master vol bpfs");

~sliderMastVolBpfs = Slider.new(w, Rect(430, 680, 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_(0.8)
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var amp = obj.value.linexp(0, 1, 0.01, 4);
		~bpfsMix.set(\amp, amp);
});
/////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////// slider pour decay de la reverb
StaticText(w, Rect(430, 700, 120, 15))
.font_(~font)
.string_("reverb decay");

~sliderReverbDecay = Slider.new(w, Rect(430, 720, 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_(0.5)
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var decay = obj.value.linexp(0, 1, 0.3, 10);
		~reverb.set(\decay, decay);
 });
///////////////////////////////////////////////////// slider pour dry/wet de la reverb
StaticText(w, Rect(430, 740, 120, 15))
.font_(~font)
.string_("reverb dry/wet");

~sliderReverbDryWet = Slider.new(w, Rect(430, 760, 200, 17))
.background_(Color(0.75, 0.75, 0.75))
.value_(0.5)
.background_(Color.gray(0.1))
.knobColor_(Color.red)
.action_({
	arg obj;
	var mix = obj.value.linexp(0, 1, 0.01, 1);
		~reverb.set(\mix, mix);
 });
////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// enregistrement paramètres ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
~slidersIterValues = 18.collect({Array.newClear});  // liste pour sauver des valeurs des sliders iter

~slidersFreqBpfsValues = 7.collect({Array.newClear});   // fréquences filtre bpf
~slidersAmpBpfsValues = 7.collect({Array.newClear});    // amps bpf

~sliderModFreqValue = Array.newClear;               // modulation filtre
~sliderResoBpfsValue = Array.newClear;              // reso tous les bpfs
~sliderMastVolBpfsValue = Array.newClear;           // master volume bpfs
~sliderReverbDecayValue = Array.newClear;           // reverb decay
~sliderReverbDryWetValue = Array.newClear;          // reverb dry/wet


~saveBs = 7.collect({
	arg a;
	Button(w, Rect(285, 385 + (30 * a), 55, 22))
	.states_([ ["mémo " ++ (a + 1), Color.black, Color(0.75, 0.75, 0.75, 0.75)]
	])
.font_(~font)
});
///////////////////////////////////////////////////////////////////////////////////////////
7.do({   // action save pour les sliders iter & bpf, les 7 mémoires
	arg i;
	~saveBs[i].action_({

 7.do({                     // changer l'apparence GUI si clic
			arg a;
		if (i == a, {
					~saveBs[a].states_([["saved " ++ (i+1), Color.black, Color.new255(240, 110, 120)]]);
					~recallBs[a].states_([["play " ++ (i+1), Color.black, Color.new255(240, 110, 120)]]);
		 },
				{
					~saveBs[a].states_([["mémo " ++ (a+1), Color.black, Color(0.75, 0.75, 0.75, 0.75)]]);
					~recallBs[a].states_([["recall " ++ (a+1), Color.black, Color(0.75, 0.75, 0.75, 0.75)]]);
    });
  });
////////////////////////////////////////////////////////////////////////////////////////////////
if(~slidersIterValues[i].isEmpty,      // premier état: les slots de l'array sont vides d'abord
		{
				18.do({           // les 18 sliders iterEli
					arg a;
			~slidersIterValues[i] = ~slidersIterValues[i].add(~sliders[a].value)});
				7.do({            // fréqs des filtres simpleBpf
					arg a;
			~slidersFreqBpfsValues[i] = ~slidersFreqBpfsValues[i].add(~slidersFreqBpfs[a].value)});
			  7.do({            // amplitudes simpleBpf
					arg a;
			~slidersAmpBpfsValues[i] = ~slidersAmpBpfsValues[i].add(~slidersAmpBpfs[a].value)});

		  ~sliderModFreqValue = ~sliderModFreqValue.add(~sliderModFreqBpfs.value);               // modulation filtres
      ~sliderResoBpfsValue = ~sliderResoBpfsValue.add(~sliderResoBpfs.value);                // mast réso bpfs
			~sliderMastVolBpfsValue = ~sliderMastVolBpfsValue.add(~sliderMastVolBpfs.value);       // mast vol bpfs
			~sliderReverbDecayValue = ~sliderReverbDecayValue.add(~sliderReverbDecay.value);       // reverb decay
			~sliderReverbDryWetValue = ~sliderReverbDryWetValue.add(~sliderReverbDryWet.value);    // reverb decay

    },
		{                              // on a déjà sauvé une fois -> remplacement des data
			18.do({
					arg a;
			~slidersIterValues[i] = ~slidersIterValues[i].put(a, ~sliders[a].value)});
			7.do({
					arg a;
			~slidersFreqBpfsValues[i] = ~slidersFreqBpfsValues[i].put(a, ~slidersFreqBpfs[a].value)});
			7.do({
					arg a;
			~slidersAmpBpfsValues[i] = ~slidersAmpBpfsValues[i].put(a, ~slidersAmpBpfs[a].value)});

		~sliderModFreqValue = ~sliderModFreqValue.put(i, ~sliderModFreqBpfs.value);               // modulation filtres
    ~sliderResoBpfsValue = ~sliderResoBpfsValue.put(i, ~sliderResoBpfs.value);                // mast réso bpfs
		~sliderMastVolBpfsValue = ~sliderMastVolBpfsValue.put(i, ~sliderMastVolBpfs.value);       // mast vol bpfs
		~sliderReverbDecayValue = ~sliderReverbDecayValue.put(i, ~sliderReverbDecay.value);       // reverb decay
		~sliderReverbDryWetValue = ~sliderReverbDryWetValue.put(i, ~sliderReverbDryWet.value);    // reverb dry/wet
   }
	)
 });
});
//////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// rappel paramètres ////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
~recallBs = 7.collect({
	arg a;
	Button(w, Rect(350, 385 + (30 * a), 60, 22))
	.states_([["recall " ++ (a + 1), Color.black, Color(0.75, 0.75, 0.75, 0.75)]])
.font_(~font)
});

7.do({      // action recall
	arg i;
	~recallBs[i].action_({

		 7.do({                   // changer l'apparence si clic
			arg a;
		if (i == a, {
					~recallBs[a].states_([["play " ++ (i+1), Color.black, Color.new255(240, 110, 120)]])
		 },
				{
					~recallBs[a].states_([["recall " ++ (a+1), Color.black, Color(0.75, 0.75, 0.75, 0.75)]])
		});
  });
//////////////////////////////////////////////////////////////////////////////////////////////////
	18.do({arg b;                // sliders iterEli
			~sliders[b].valueAction_(~slidersIterValues[i][b]);
		});
				7.do({arg b;          // sliders fréqs des filtres simpleBpf
			~slidersFreqBpfs[b].valueAction_(~slidersFreqBpfsValues[i][b]);
		});
				7.do({arg b;          // sliders amplitudes simpleBpf
			~slidersAmpBpfs[b].valueAction_(~slidersAmpBpfsValues[i][b]);
		});
			~sliderModFreqBpfs.valueAction_(~sliderModFreqValue[i]);            // modulation filtres
		  ~sliderResoBpfs.valueAction_(~sliderResoBpfsValue[i]);              // mast réso bpfs
			~sliderMastVolBpfs.valueAction_(~sliderMastVolBpfsValue[i]);        // mast vol bpfs
			~sliderReverbDecay.valueAction_(~sliderReverbDecayValue[i]);        // reverb decay
			~sliderReverbDryWet.valueAction_(~sliderReverbDryWetValue[i]);      // reverb dry/wet
 })
});
////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////// record to disk
~recordB = Button(w, Rect(355, 338, 55, 22))
.states_([ ["rec", Color.black, Color.new255(240, 110, 120)],
	["stop", Color.green, Color.grey(0.11)]
])
.font_(~font)
.action_({
	arg b;
	if(b.value == 1,
	{s.record},
	{s.stopRecording});
 });
});
)

s.quit


