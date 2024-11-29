(
var filepath, freqAmpPairs, activeSynths, readFile, startRoutine, duration, deccayR, window, freqShift, maxFreq, minFreq, freqShiftBox, minFreqBox, maxFreqBox, shortDuration;
s.waitForBoot({
	Buffer.freeAll;



// point to the list of frequency file
filepath = "/Users/djeanner/git/nmrSuperCollider/data/list1.txt";

freqAmpPairs = [];
activeSynths = [];
duration = 20; // duration of the sound
shortDuration = 2;
deccayR = -10.0; // coef of the deccay - Relaxation time
freqShift = 0.0;
// Function to read the file
readFile = {
    var file, line;
    freqAmpPairs = [];
    file = File.new(filepath, "r");
    if (file.isOpen) {
        while {
            line = file.getLine;
            line.notNil  // Continue until EOF (line is nil)
        } {
            var values = line.split($ );  // Split line into components
            freqAmpPairs = freqAmpPairs.add([values[0].asFloat, values[1].asFloat]);  // Add pair to list
        };
        file.close;  // Close the file after reading
    } {
        "Error: Could not open file.".postln;
    };
};

// Initialize playDamped
SynthDef(\playDamped, { |freq = 440, amp = 0.5|
    Out.ar(0, SinOsc.ar(freq) * EnvGen.kr(Env([amp, 0], [duration], [deccayR]), doneAction: 2)!2);
}).add;
	s.sync;

// s.sync; // wait for buffer running in Routine({}) or s.waitForBoot(
startRoutine = {
    var routine, group, groupLifetime;

    groupLifetime = duration * 10; // Define the lifetime of each group

    routine = Routine({
        loop {
            readFile.value;

            // Create a new group for managing Synths
            group = Group.new(s);

            // Schedule the group to free after its lifetime
            SystemClock.sched(groupLifetime, {
                group.free;
                "Group freed after ".post; groupLifetime.postln;
            });

            // Create new Synths for the current frequencies
            freqAmpPairs.do { |pair|
                var shiftedFreq = pair[0] + freqShift;
                if ((shiftedFreq >= minFreq) and: (shiftedFreq <= maxFreq)) {
                    Synth(\playDamped, [\freq, shiftedFreq, \amp, pair[1], \duration, duration, \deccayR, deccayR], group);
                }
            };

            shortDuration.wait; // Wait for a small duration before the next loop iteration
        }
    }).play;

    "New routine started.".postln;
};



startRoutine.value;
 // GUI for controlling frequency range and shift
window = Window("Frequency Selector", Rect(100, 100, 400, 200));
window.view.decorator = FlowLayout(window.bounds);

StaticText(window, Rect(0, 0, 400, 20)).string_("Set Frequency Range and Shift");

// Min Frequency Slider
 minFreqBox = StaticText(window, Rect(0, 20, 200, 20)); // To show min frequency
minFreq = 0; // Default minimum frequency
Slider(window, Rect(0, 40, 200, 20))
    .action_({ |slider|
        minFreq = slider.value.linlin(0, 1, 0, 2000);
        minFreqBox.string = "Min Frequency: " ++ minFreq.round(0.1).asString;
    })
    .value_(minFreq.linlin(0, 20000, 0, 1))
    .toolTip_("Minimum Frequency");

// Max Frequency Slider
 maxFreqBox = StaticText(window, Rect(0, 80, 200, 20)); // To show max frequency
maxFreq = 20000; // Default maximum frequency
Slider(window, Rect(0, 100, 200, 20))
    .action_({ |slider|
        maxFreq = slider.value.linlin(0, 1, 0, 2000);
        maxFreqBox.string = "Max Frequency: " ++ maxFreq.round(0.1).asString;
    })
    .value_(maxFreq.linlin(0, 20000, 0, 1))
    .toolTip_("Maximum Frequency");

// Frequency Shift Slider
 freqShiftBox = StaticText(window, Rect(0, 140, 200, 20)); // To show frequency shift
freqShift = 0.0; // Default frequency shift
Slider(window, Rect(0, 160, 200, 20))
    .action_({ |slider|
        freqShift = slider.value.linlin(0, 1, -1000, 1000);
        freqShiftBox.string = "Frequency Shift: " ++ freqShift.round(0.1).asString;
    })
    .value_(0.5)
    .toolTip_("Frequency Shift");

window.front;

});

)