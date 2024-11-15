(
var filepath, freqAmpPairs, activeSynths, readFile, startRoutine, duration, deccayR;

// point to the list of frequency file
filepath = "/Users/djeanner/kDrive/superCollider/list1.txt";

freqAmpPairs = [];
activeSynths = [];
duration = 5; // duration of the sound
deccayR = 3.5; // coef of the deccay - Relaxation time

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

startRoutine = {
    var routine, group;

    // Create a group for managing Synths
    group = Group.new(s);

    routine = Routine({
        loop {
            readFile.value;

            // Free all Synths in the group
            group.freeAll;

            // Create new Synths for the current frequencies
            freqAmpPairs.do { |pair|
                Synth(\playDamped, [\freq, pair[0], \decdayCoef , deccayR ,\amp, pair[1],  duration], group);
            };

            duration.wait;  // Wait for duration second
        }
    }).play;

    "New routine started.".postln;
};

// Start the routine
startRoutine.value;
)