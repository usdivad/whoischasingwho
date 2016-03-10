/*
 * Maraichers/Aubervilliers
 * by David Su
*/


// SCORE
// section controllers
0 => int curSection;
0 => int curNote;
0 => int feedbackCount;


// modal bar
ModalBar bar => NRev nrev => Chorus chorus => dac;
1 => bar.preset;

// music notes (by section)
// generated by the agc algorithmic process
[
    [57, 62, 60, 67],   // 0
    [55, 60, 57, 66],  // 1
    [64, 55, 60, 57], // 2
    [53, 64, 56, 60] // 3
] @=> int notes[][];



// INPUT
// midi mapping for SPD-SX input
// using kit 023 "Bat Dub"
int drumMap[5];
36 => drumMap["kick"];
40 => drumMap["snare"];
44 => drumMap["cym"];
60 => drumMap["tomHi"];
62 => drumMap["tomLo"];

// input sequences (by section)
["cym", "snare", "kick"] @=> string section1_inputSequence[];


// keyboard input
KBHit kb;

fun void kbListen() {
    while (true) {
        kb => now;
        while (kb.more()) {
            kb.getchar() => int k;
            <<<k>>>;

            if (k >= 49 && k <= (49 + notes.cap())) {
                k - 49 => curSection;
            }
        }
    }
}

spork ~ kbListen();


// simple beat detection and "metronome"
// adapted from keiichi takahashi's http://d.hatena.ne.jp/ke_takahashi/20090228
time pre;
0.75::second => dur d;

fun void noteon(float f, dur len, float vel)
{
    f => bar.freq;
    
    vel * 0.5 => bar.noteOn;
    len * 0.1 => now;
    0.0 => bar.noteOn;
    len * 0.9 => now;
    
    // 0.5 => bar.noteOn;
    
    // <<< len >>>;
}

fun void playSequence()
{
    while (true) {
        /*
        (1000,d/4) => noteon;
        (1000,d/4) => noteon;
        (1500,d/4) => noteon;
        (1000,d/4) => noteon;
        */
        1.0 => float divisions;
        (curFreq(), d/divisions, 0.75) => noteon;
        (curFreq(), d/divisions, 0.75) => noteon;
        (curFreq(), d/divisions, 0.75) => noteon;
        (curFreq(), d/divisions, 0.75) => noteon;
        (1000, d/divisions, 0.0) => noteon;
    }
}

fun float curFreq() {
    curSection % notes.cap() => curSection;
    curNote % notes[curSection].cap() => curNote;
    notes[curSection][curNote] => int midinote;
    curNote + 1 => curNote;
    return Std.mtof(midinote + 5); // just to transpose it
}

spork ~ playSequence();




//--
// pitch tracking analysis + synthesis
// based on pitch-track.ck by Rebecca Fiebrink + Ge Wang (2007)
//--
// analysis
adc => PoleZero dcblock => FFT fft => blackhole;
// synthesis
PulseOsc s => JCRev r => dac;
// SinOsc s => JCRev r => dac;

// set reverb mix
.05 => r.mix;
// set to block DC
.99 => dcblock.blockZero;
// set FFT params
1024 => fft.size;
// window
Windowing.hamming( fft.size() ) => fft.window;

// to hold result
UAnaBlob blob;
// find sample rate
second / samp => float srate;

// interpolate
float target_freq, curr_freq, target_gain, curr_gain;
spork ~ ramp_stuff();

fun void pitch_track() {
    // go for it
    while (true) {
        // take fft
        fft.upchuck() @=> blob;
        
        // find peak
        0 => float max; int where;
        for( int i; i < blob.fvals().cap(); i++ )
        {
            // compare
            if( blob.fvals()[i] > max )
            {
                // save
                blob.fvals()[i] => max;
                i => where;
            }
        }
        
        // set freq
        (where $ float) / fft.size() * srate => target_freq;
        // set gain
        (max / .8) => target_gain;
        
        // hop
        (fft.size()/2)::samp => now;
    }
}

spork ~ pitch_track();


// interpolation
fun void ramp_stuff()
{
    // mysterious 'slew'
    0.025 => float slew;
    
    // infinite time loop
    while( true )
    {
        (target_freq - curr_freq) * 5 * slew + curr_freq => curr_freq => s.freq;
        (target_gain - curr_gain) * slew + curr_gain => curr_gain => s.gain;
        // <<< curr_freq >>>;
        0.0025::second => now;
    }
}



// midi input
// adapted from chuck example http://chuck.cs.princeton.edu/doc/examples/midi/gomidi2.ck

//--------------------------------------------------------------------------

// opens MIDI input devices one by one, starting from 0,
// until it reaches one it can't open.  then waits for
// midi events on all open devices and prints out the
// device, and contents of the MIDI message

// devices to open (try: chuck --probe)
MidiIn min[16];

// number of devices
int devices;

// loop
for( int i; i < min.cap(); i++ )
{
    // no print err
    min[i].printerr( 0 );

    // open the device
    if( min[i].open( i ) )
    {
        <<< "device", i, "->", min[i].name(), "->", "open: SUCCESS" >>>;
        spork ~ go( min[i], i );
        devices++;
    }
    else break;
}

// check
if( devices == 0 )
{
    <<< "um, couldn't open a single MIDI device, bailing out..." >>>;
    me.exit();
}

// infinite time loop
while( true ) 1::second => now;


// handler for one midi event
fun void go( MidiIn min, int id )
{
    // the message
    MidiMsg msg;

    // infinite event loop
    while( true )
    {
        // wait on event
        min => now;

        // print message
        while( min.recv( msg ) )
        {
            // print out midi message with id
            msg.data1 => int channel;
            msg.data2 => int note;
            msg.data3 => int velocity;
            <<< "device", id, ":", channel, note, velocity >>>;

            // beat detection
            now - pre => dur dd;
            now => pre;
            if (dd > 10::ms && dd < 2::second) {
               if (dd > 65::ms) {
                   dd => d;
               }
               else { // put a cap on it
                   65::ms => d;
               }
               <<< d >>>;
               <<< "BPM:",(1::minute / (d/2)) $ int >>>;
            }

            // make some sound
            if (velocity > 0) { // if it's not a note off
                // playBar(msg);
                handleMidiInput(msg);
            }
        }
    }
}

//--------------------------------------------------------------------------





fun void handleMidiInput(MidiMsg msg) {
    // get input params
    msg.data2 => float inputMidi;
    // Std.mtof(inputMidi) => float inputFreq;
    msg.data3 / 128.0 => float inputVelocity;





}

fun void playBar(float freq, float velocity) {
    // Std.mtof(msg.data2) => float freq;
    // msg.data3 / 128.0 => float velocity;
    <<< "playing bar -> freq: ", freq, ", velocity: ", velocity >>>;

    freq => bar.freq;
    Math.random2f(0.0, 0.25) => bar.strikePosition;
    Math.random2f(0.45, 0.5) => bar.stickHardness;
    Math.random2f(0.0, 0.1) => bar.damp;
    velocity => bar.noteOn;
}