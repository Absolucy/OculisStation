// knobs for the dmeow JIT panel and its A/B runs.

/// interpreter calls before dmeow bothers compiling a proc. tuned so the hot set
/// is all compiled by the end of warmup, without cold procs sneaking in.
#define DMEOW_PERF_DEFAULT_THRESHOLD 200
/// profiler times 1 in N calls, per proc. both hooks take their lock every call
/// anyway, so coarser only saves two clock reads. nothing past ~25.
/// denser than it used to be (was 10) to pay for the shorter window below - a
/// third of the seconds needs three times the sampling to keep each window's
/// per-arm count where it was.
#define DMEOW_PERF_DEFAULT_SAMPLE_RATE 3
/// Keep early timings even when a proc compiles before its regular sample.
#define DMEOW_PERF_EARLY_SAMPLES 32
/// compile-and-settle before the interleave. all binned, so it only has to
/// outlast the hot set promoting.
#define DMEOW_PERF_DEFAULT_WARMUP 180
/// seconds each arm gets per flip.
///
/// was 15, which is long enough that one interruption - a browser tab waking up
/// for three seconds - lands entirely inside a single arm's window and skews
/// that arm alone. at 5s the same interruption straddles windows of both arms,
/// and the paired sign test that ranks on won-cycles-out-of-total absorbs it.
/// still a whole number of DMEOW_BURN_RESEED_PERIOD, so the burn room is happy.
#define DMEOW_PERF_DEFAULT_WINDOW 5
/// on/off pairs the interleave runs. 16 pairs at 5s = 160s, and 16 cycles for
/// the sign test to work with instead of 8.
#define DMEOW_PERF_DEFAULT_CYCLES 16

/// most A/B windows the DLL keeps per-proc arm totals for. mirrors MAX_WINDOWS
/// in dmeow's `runtime/profiling.rs`; past it the DLL merges every further
/// window into the last one and drops the per-proc arm totals, which reads as a
/// normal report rather than as an error. one flip per arm per cycle, so the
/// real ceiling is `cycles * 2`.
#define DMEOW_PERF_MAX_WINDOWS 32

/// an arm with fewer samples than this is noise, not a measurement.
#define DMEOW_PERF_MIN_SAMPLES 100
/// arms overlapping less than this in time weren't watching the same workload,
/// however many samples they piled up.
#define DMEOW_PERF_MIN_OVERLAP_PCT 50
/// how many procs the panel ranks each way. the raw JSON keeps the lot.
#define DMEOW_PERF_SUMMARY_ROWS 8
/// procs pulled out of the DLL per summary. 0 means unlimited - report_json
/// always keeps every compiled row regardless of this cap, so once compiled
/// coverage passes it (834 procs vs. the old 400) every interpreted row was
/// getting silently dropped, which is exactly the coverage the panel needs to
/// see.
#define DMEOW_PERF_REPORT_LIMIT 0
/// per-fire SSair rows kept per round. 8 x 15s windows at 2 fires/s is ~480, and
/// a saturated room adds a fire per pause on top of that. Rows past the cap are
/// counted, not silently dropped - the count is what says the row sum is short.
#define DMEOW_TURF_ROW_LIMIT 4000

/// burn room interior, in turfs. 10x10, copied off
/// _maps/templates/holodeck_burntest.dmm.
#define DMEOW_BURN_ROOM_SIZE 10
/// seconds between burn room re-seeds. has to divide the A/B window exactly or
/// each arm gets a different amount of work.
#define DMEOW_BURN_RESEED_PERIOD 5
/// turfs between ignition points on each axis. one fire per ~25 interior turfs,
/// which keeps 4 points at 10x10 and gives 64 at 40x40.
#define DMEOW_IGNITION_SPACING 5

/// hot dense half of the gradient room. nitrogen because no reaction in
/// reactions.dm can fire without a second gas, so the room moves gas and heat
/// hard and never catches - which is what makes both arms provably do the same
/// work per turf.
#define DMEOW_GRADIENT_HOT GAS_N2 + "=500;TEMP=1000"
/// cold thin half. ~1000x the pressure ratio against the hot half, so the front
/// keeps moving gas for the whole re-seed period rather than settling in a tick.
#define DMEOW_GRADIENT_COLD GAS_N2 + "=5;TEMP=100"
