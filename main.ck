
// section controllers
0 => int curSection;
0 => int curNote;

// modal bar
ModalBar bar => NRev r => Chorus chorus => dac;
1 => bar.preset;

// music notes (by section)
[
    [57, 62, 60, 67], // 0
    [60]              // 1
] @=> int notes[][];


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



// simple beat detection and "metronome"
// adapted from keiichi takahashi's http://d.hatena.ne.jp/ke_takahashi/20090228
time pre;
0.75::second => dur d;

fun void noteon(float f, dur len, float vel)
{
    f => bar.freq;
    
    vel => bar.noteOn;
    len * 0.1 => now;
    0.0 => bar.noteOn;
    len * 0.9 => now;
    
    // 0.5 => bar.noteOn;
    <<< len >>>;
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

        (curFreq(), d/5, 0.75) => noteon;
        (curFreq(), d/5, 0.75) => noteon;
        (curFreq(), d/5, 0.75) => noteon;
        (curFreq(), d/5, 0.75) => noteon;
        (1000, d/5, 0.0) => noteon;
    }
}

fun float curFreq() {
    notes[curSection][curNote % 4] => int midinote;
    curNote + 1 => curNote;
    return Std.mtof(midinote);
}

spork ~ playSequence();


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
               dd => d;
               <<< "BPM:",(1::minute / (d/2)) $ int >>>;
            }

            // make some sound
            if (velocity > 0) { // if it's not a note off
                // playBar(msg);
                handleInput(msg);
            }
        }
    }
}

//--------------------------------------------------------------------------

fun void handleInput(MidiMsg msg) {
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